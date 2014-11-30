# UTF16
u8 = "\U1d565\U1d7f6\U00066\U2008a"
u16 = UTF16String(u8)
@test sizeof(u16) == 14
@test length(u16.data) == 8 && u16.data[end] == 0
@test length(u16) == 4
@test UTF8String(u16) == u8
@test collect(u8) == collect(u16)
@test u8 == UTF16String(u16.data[1:end-1]) == UTF16String(copy!(Array(UInt8, 14), 1,
                                                                reinterpret(UInt8, u16.data), 1, 14))
@test u8 == UTF16String(pointer(u16)) == UTF16String(convert(Ptr{Int16}, pointer(u16)))

# UTF32
u32 = UTF32String(u8)
@test sizeof(u32) == 16
@test length(u32.data) == 5 && u32.data[end] == char(0)
@test length(u32) == 4
@test UTF8String(u32) == u8
@test collect(u8) == collect(u32)
@test u8 == UTF32String(u32.data[1:end-1]) == UTF32String(copy!(Array(UInt8, 16), 1,
                                                                reinterpret(UInt8, u32.data), 1, 16))
@test u8 == UTF32String(pointer(u32)) == UTF32String(convert(Ptr{Int32}, pointer(u32)))

# Wstring
w = wstring(u8)
@test length(w) == 4 && UTF8String(w) == u8 && collect(u8) == collect(w)
@test u8 == WString(w.data)

if !success(`iconv --version`)
    warn("iconv not found, skipping unicode tests!")
    @windows_only warn("Use WinRPM.install(\"win_iconv\") to run these tests")
else
    # Create unicode test data directory
    unicodedir = mktempdir()

    # Use perl to generate the primary data
    primary_encoding = "UTF-32BE"
    primary_path = replace(joinpath(unicodedir, primary_encoding*".unicode"),"\\","\\\\\\\\")
    run(`perl -e "
        $$fname = \"$primary_path\";
        open(UNICODEF, \">\", \"$$fname\")         or die \"can\'t open $$fname: $$!\";
        binmode(UNICODEF);
        print UNICODEF pack \"N*\", 0xfeff, 0..0xd7ff, 0xe000..0x10ffff;
        close(UNICODEF);"` )

    # Use iconv to generate the other data
    for encoding in ["UTF-32LE", "UTF-16BE", "UTF-16LE", "UTF-8"]
        output_path = joinpath(unicodedir, encoding*".unicode")
        f = Base.FS.open(output_path,Base.JL_O_WRONLY|Base.JL_O_CREAT,Base.S_IRUSR | Base.S_IWUSR | Base.S_IRGRP | Base.S_IROTH)
        run(`iconv -f $primary_encoding -t $encoding $primary_path` |> f)
        Base.FS.close(f)
    end

    f=open(joinpath(unicodedir,"UTF-32LE.unicode"))
    str1 = UTF32String(read(f, UInt32, 1112065)[2:end])
    close(f)

    f=open(joinpath(unicodedir,"UTF-8.unicode"))
    str2 = UTF8String(read(f, UInt8, 4382595)[4:end])
    close(f)
    @test str1 == str2

    @test str1 == open(joinpath(unicodedir,"UTF-16LE.unicode")) do f
        UTF16String(read(f, UInt16, 2160641)[2:end])
    end

    @test str1 == open(joinpath(unicodedir,"UTF-16LE.unicode")) do f
        UTF16String(read(f, UInt8, 2160641*2))
    end
    @test str1 == open(joinpath(unicodedir,"UTF-16BE.unicode")) do f
        UTF16String(read(f, UInt8, 2160641*2))
    end

    @test str1 == open(joinpath(unicodedir,"UTF-32LE.unicode")) do f
        UTF32String(read(f, UInt8, 1112065*4))
    end
    @test str1 == open(joinpath(unicodedir,"UTF-32BE.unicode")) do f
        UTF32String(read(f, UInt8, 1112065*4))
    end

    str1 = "∀ ε > 0, ∃ δ > 0: |x-y| < δ ⇒ |f(x)-f(y)| < ε"
    str2 = UTF32String(
                 8704, 32, 949, 32, 62, 32, 48, 44, 32, 8707, 32,
                 948, 32, 62, 32, 48, 58, 32, 124, 120, 45, 121, 124,
                 32, 60, 32, 948, 32, 8658, 32, 124, 102, 40, 120,
                 41, 45, 102, 40, 121, 41, 124, 32, 60, 32, 949
                 )
    @test str1 == str2

    # Cleanup unicode data
    for encoding in ["UTF-32BE", "UTF-32LE", "UTF-16BE", "UTF-16LE", "UTF-8"]
        rm(joinpath(unicodedir,encoding*".unicode"))
    end
    rm(unicodedir)
end

# check utf8proc handling of CN category constants

let c_ll = 'β', c_cn = '\u038B'
    @test Base.UTF8proc.category_code(c_ll) == Base.UTF8proc.UTF8PROC_CATEGORY_LL
    # check codepoint with category code CN
    @test Base.UTF8proc.category_code(c_cn) == Base.UTF8proc.UTF8PROC_CATEGORY_CN
end
