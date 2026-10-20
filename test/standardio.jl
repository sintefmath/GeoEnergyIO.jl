using Dates

@testset "StandardIO binary records" begin
    # Independent, hand-encoded big-endian INTE record: A = [1, -2].
    reference = hex2bytes("00000010412020202020202000000002494e5445000000100000000800000001fffffffe00000008")
    raw = read_binary(IOBuffer(reference))
    @test raw["A"] == Int32[1, -2]
    @test raw[1].type == "INTE"
    io = IOBuffer()
    write_binary(io, [BinaryKeyword("A", [1, -2])])
    @test take!(io) == reference
    @test isempty(read_binary(IOBuffer(UInt8[])))
    for endian in (:big, :little)
        kws = BinaryKeyword[
            BinaryKeyword("INTS", Int32[-1, typemin(Int32), typemax(Int32)]),
            BinaryKeyword("FLOATS", Float32.(1:2001)),
            BinaryKeyword("DOUBLES", [pi, -Inf, NaN]),
            BinaryKeyword("BOOLS", [true, false, true]),
            BinaryKeyword("STRINGS", repeat(["A", "B C", ""], 100)),
            BinaryKeyword("LONGNAME", ["a long well name", ""]),
            BinaryKeyword("EMPTY", Int32[]),
            BinaryKeyword("STARTSOL", UInt8[]; type = "MESS"),
            BinaryKeyword("INTS", Int32[3])
        ]
        io = IOBuffer()
        write_binary(io, kws; endian)
        seekstart(io)
        readback = read_binary(io)
        @test readback.endian == endian
        @test length(readback) == length(kws)
        for (a, b) in zip(kws, readback)
            @test a.name == b.name
            @test a.type == b.type
            @test isequal(a.data, b.data)
        end
        @test keyword_values(readback, "INTS") == [kws[1].data, [3]]
        @test_throws KeyError readback["MISSING"]
    end
    # Both common LOGI true encodings must be read.
    logi = hex2bytes("000000104c4f474943414c20000000034c4f4749000000100000000cffffffff00000001000000000000000c")
    @test read_binary(IOBuffer(logi))["LOGICAL"] == [true, true, false]
    broken = copy(reference)
    broken[end] = 7
    @test_throws ArgumentError read_binary(IOBuffer(broken))
    @test_throws EOFError read_binary(IOBuffer(reference[1:end-1]))
    @test_throws EOFError read_binary(IOBuffer(reference[1:9]))
    @test_throws ArgumentError read_binary(IOBuffer(zeros(UInt8, 24)))
    @test_throws ArgumentError BinaryKeyword("TOO_LONG_NAME", [1])
    @test_throws ArgumentError BinaryKeyword("BAD", [1]; type = "XXXX")
    @test_throws ArgumentError BinaryKeyword("BAD", ["nine chars"]; type = "CHAR")
    @test_throws ArgumentError BinaryKeyword("BAD", [1]; type = "MESS")
    @test_throws ArgumentError write_binary(IOBuffer(), raw; endian = :invalid)
end

@testset "StandardIO file interfaces" begin
    mktempdir() do dir
        base = joinpath(dir, "CASE.with.dots")
        data = GeoEnergyIO.StandardIO.output.rectangular_grid([2.0, 3.0], [4.0], [5.0, 6.0])
        data["ACTNUM"][2] = false
        data["MAPAXES"] = [0.0, 1.0, 0.0, 0.0, 1.0, 0.0]
        for unit in (:metric, :field, :lab)
            path = write_egrid(data, base; units = unit)
            grid, raw = read_egrid(path; extra_out = true)
            @test grid["cartDims"] == [2, 1, 2]
            @test grid["ACTNUM"] == data["ACTNUM"]
            @test grid["COORD"] ≈ data["COORD"] rtol=1e-6
            @test grid["ZCORN"] ≈ data["ZCORN"] rtol=1e-6
            @test grid["MAPAXES"] ≈ data["MAPAXES"] rtol=1e-6
            @test raw["GRIDHEAD"][2:4] == [2, 1, 2]
        end
        init = Dict("INTEHEAD" => collect(1:4), "PORV" => [1.0, 2.0, 3.0, 4.0], "PORO" => fill(0.2, 3))
        write_init(init, base)
        parsed, raw = read_init(base*".INIT"; actnum = [1, 0, 1, 1], extra_out = true)
        @test parsed["PORV"] == [1, 3, 4]
        @test parsed["PORO"] == fill(0.2, 3)
        @test parsed["INTEHEAD"] == 1:4
        @test raw isa KeywordFile
        steps = Dict{String, Any}[]
        for (i, report) in enumerate((1, 3))
            header = GeoEnergyIO.StandardIO.output.standard_headers((2, 1, 2), 3;
                units = :field, elapsed = 86400.0*i, start_date = DateTime(2000, 1, 1, 2, 3, 4))
            step = Dict{String, Any}(k.name => k.data for k in header)
            step["PRESSURE"] = Float32[100, 200, 300]
            step["report_step"] = report
            push!(steps, step)
        end
        for unified in (true, false)
            # Use distinct bases so unified files cannot shadow separate files.
            path = base*"_$unified"
            write_restart(steps, path; unified)
            back, blocks = read_restart(path; extra_out = true)
            @test length(back) == 2
            @test [s["report_step"] for s in back] == [1, 3]
            @test back[2]["days"] == 2.0
            @test back[1]["date"] == "2000-01-02T02:03:04"
            @test back[1]["PRESSURE"] == [100, 200, 300]
            @test read_restart(path; steps = [2])[1]["report_step"] == 3
            @test read_restart(path; units = :si)[1]["PRESSURE"] ≈ [100, 200, 300].*GeoEnergyIO.InputParser.DeckUnitSystem(:field).pressure
            @test length(blocks) == 2
        end
        summary = Dict{String, Any}(
            "DIMENS" => (2, 1, 2), "UNIT_SYSTEM" => "FIELD",
            "TIME" => (start_date = DateTime(2020, 2, 28, 1, 2, 3), seconds = [86400.0, 172800.0]),
            "VALUES" => Dict("FIELD" => Dict("FOPT" => [3.0, 7.0]),
                "WELLS" => Dict("A_LONG_WELL_NAME" => Dict("WBHP" => [100.0, 200.0])),
                "GROUP" => Dict("G1" => Dict("GOPR" => [2.0, 4.0]))))
        original = deepcopy(summary)
        for unified in (true, false)
            path = base*"_summary_$unified"
            written = write_summary(summary, path; unified)
            back, raw = read_summary(path; format = :structured, extra_out = true)
            @test back["DIMENS"] == (2, 1, 2)
            @test back["TIME"] == summary["TIME"]
            @test back["VALUES"]["FIELD"] == summary["VALUES"]["FIELD"]
            @test back["VALUES"]["WELLS"] == summary["VALUES"]["WELLS"]
            @test back["VALUES"]["GROUP"] == summary["VALUES"]["GROUP"]
            @test back["UNITS"]["WBHP"]["A_LONG_WELL_NAME"] == "PSIA"
            @test raw.spec[findfirst(k -> k.name == "WGNAMES", raw.spec)].type == "C016"
            @test length(written.data) == (unified ? 1 : 2)
            flat = read_summary(path*".SMSPEC")
            @test flat["WBHP"]["A_LONG_WELL_NAME"] == [100, 200]
            @test flat["START_DATE"] == summary["TIME"].start_date
            back["VALUES"]["FIELD"]["FOPT"] = [4.0, 9.0]
            write_summary(back, path*"_copy")
            @test read_summary(path*"_copy")["FOPT"] == [4, 9]
        end
        @test isequal(summary, original)
        lower = joinpath(dir, "lower_case")
        written = write_summary(summary, lower; unified = false)
        @test endswith(written.spec, ".smspec")
        @test endswith(first(written.data), ".s0001")
        @test read_summary(lower)["FOPT"] == [3, 7]
        si_summary = Dict("DIMENS" => (1, 1, 1), "UNIT_SYSTEM" => "si",
            "TIME" => (start_date = nothing, seconds = [86400.0]),
            "VALUES" => Dict("FIELD" => Dict("FPRH" => [1e7], "FOIP" => [10.0], "FOPR" => [0.001])))
        write_summary(si_summary, base*"_si")
        si_back = read_summary(base*"_si"; format = :structured)
        @test si_back["VALUES"]["FIELD"]["FPRH"] ≈ [100.0]
        @test si_back["VALUES"]["FIELD"]["FOPR"] ≈ [86.4] rtol=1e-6
        @test si_back["UNITS"]["FOIP"] == "SM3"
        @test si_summary["VALUES"]["FIELD"]["FPRH"] == [1e7]
        @test_throws ArgumentError read_summary(base; format = :bad)
        summary["TIME"] = (start_date = missing, seconds = [1.0])
        @test_throws ArgumentError write_summary(summary, base)
    end
end
