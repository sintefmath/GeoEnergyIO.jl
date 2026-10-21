using Test, GeoEnergyIO
import GeoEnergyIO.InputParser as IP

@testset "Deck records and unsupported keywords" begin
    @test IP.read_record(IOBuffer(" 'H--' / -- comment\n")) == ["'H--' "]
    @test IP.read_record(IOBuffer(" 'hé--/llo' / comment\n")) == ["'hé--/llo' "]
    @test IP.read_record(IOBuffer(" -- comment\n\n 'H--'\n /\n")) == ["'H--'"]
    for gap in ("", "\n", "-- comment\n"), suffix in (" /", " / note", "\n /")
        mktempdir() do dir
            mkpath(joinpath(dir,"sub"))
            write(joinpath(dir,"sub","X--Y.INC"),"GAS\n")
            path = joinpath(dir,"CASE.DATA")
            write(path,"RUNSPEC\nINCLUDE\n"*gap*" 'sub/X--Y.INC'"*suffix*"\nWATER\n")
            d = parse_data_file(path;silent=true)
            @test haskey(d["RUNSPEC"],"GAS")
            @test haskey(d["RUNSPEC"],"WATER")
        end
    end
    @test IP.read_record(IOBuffer("sub/X.INC / note\n");include_path=true) == ["sub/X.INC "]
    @test IP.read_record(IOBuffer("'sub/X.INC'/\nNEXT\n");include_path=true) == ["'sub/X.INC'"]
    @test IP.read_record(IOBuffer("sub/X.INC/\nNEXT\n");include_path=true) == ["sub/X.INC"]
    # Consecutive INCLUDE records without a space before the terminator
    for record in ("'X.INC'/", "X.INC/")
        mktempdir() do dir
            for kw in ("GAS","OIL","WATER")
                write(joinpath(dir,"$kw.INC"),"$kw\n")
            end
            path = joinpath(dir,"CASE.DATA")
            includes = join("INCLUDE\n"*replace(record,"X"=>kw)*"\n" for kw in ("GAS","OIL","WATER"))
            write(path,"RUNSPEC\n"*includes)
            d = parse_data_file(path;silent=true)
            @test all(kw -> haskey(d["RUNSPEC"],kw), ("GAS","OIL","WATER"))
        end
    end
    for (keyword,record) in ((:LIFTOPT," 1000 0 1* /\n"),(:WLIFTOPT," 'W' YES 1 1 1 /\n/\n"))
        cfg = IP.ParserVerbosityConfig()
        io = IOBuffer(record*"TSTEP\n1 /\n")
        IP.parse_keyword!(Dict(),Dict("CURRENT_SECTION"=>:SCHEDULE),nothing,cfg,io,Val(keyword))
        @test cfg.warn_count[String(keyword)] == 1
        @test IP.next_keyword!(io) == :TSTEP
    end
    mktempdir() do dir
        path = joinpath(dir,"FLUX.DATA")
        write(path,"RUNSPEC\nDIMENS\n1 1 1 /\nMETRIC\nGRID\nFLUXNUM\n1 /\n")
        data = Dict{String,Any}()
        # Check the specialized method's warning without discarding the array.
        cfg = IP.ParserVerbosityConfig()
        outer = parse_data_file(path;silent=true)
        IP.parse_keyword!(data,outer,nothing,cfg,IOBuffer("1 /\n"),Val(:FLUXNUM))
        @test data["FLUXNUM"] == ones(Int,1,1,1)
        @test cfg.warn_count["FLUXNUM"] == 1
    end
    @test !any(x -> x[1] in (:FLUXNUM,:FILLEPS,:MULTSAVE), IP.KEYWORD_SKIP_LIST)
end
