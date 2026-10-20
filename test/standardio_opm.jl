# Run explicitly in an environment containing GeoEnergyIO and the supplied data:
# julia --project test/standardio_opm.jl /path/to/opm-tests
using GeoEnergyIO, Test, Dates

root = isempty(ARGS) ? get(ENV, "OPM_TESTS_PATH", joinpath(@__DIR__, "..", "..", "opm-tests")) : first(ARGS)
isdir(root) || error("OPM sample directory not found: $root")
limit = parse(Int, get(ENV, "STANDARDIO_SAMPLE_MAX_BYTES", string(4*1024^2)))

@testset "OPM reference unit conversions" begin
    base = joinpath(root, "gridunit", "opm-simulation-reference", "flow")
    metric = read_egrid(joinpath(base, "M_METRIC_GRID_METRES"))
    for name in ("M_FIELD_GRID_FEET", "M_FIELD_GRID_CM", "M_FIELD_GRID_METRES", "M_METRIC_GRID_CM", "M_METRIC_GRID_FEET")
        grid = read_egrid(joinpath(base, name))
        @test grid["cartDims"] == [5, 7, 5]
        @test grid["COORD"] ≈ metric["COORD"] rtol=2e-6
        @test grid["ZCORN"] ≈ metric["ZCORN"] rtol=2e-6
    end
    file = joinpath(base, "M_FIELD_GRID_FEET")
    init = read_init(file; units = :si)
    metric_init = read_init(joinpath(base, "M_METRIC_GRID_METRES"); units = :si)
    # The reference geometries are rounded independently in each length unit.
    @test init["PORV"] ≈ metric_init["PORV"] rtol=5e-5
    @test init["PORV"] ≈ read_init(file)["PORV"].*0.158987294928 rtol=1e-10
    @test length(init["PORO"]) == 175
    @test all(>(0), init["PERMX"])
    @test maximum(init["PERMX"]) < 1e-9
    smry = read_summary(file; format = :structured)
    @test smry["UNIT_SYSTEM"] == "FIELD"
    @test smry["TIME"].start_date == DateTime(2022, 11, 16)
    @test issorted(smry["TIME"].seconds)
    @test !isempty(read_restart(file))
    lab = joinpath(root, "bc_lab", "opm-simulation-reference", "flow", "BC_LAB")
    @test read_restart(lab; steps = [2])[1]["days"] ≈ 1/24
end

@testset "OPM binary corpus" begin
    counts = Dict{String, Int}()
    failures = Pair{String, String}[]
    skipped = 0
    for (dir, _, files) in walkdir(root), name in files
        ext = uppercase(splitext(name)[2])
        ext in (".EGRID", ".INIT", ".SMSPEC", ".UNSMRY", ".UNRST", ".RFT") || continue
        file = joinpath(dir, name)
        filesize(file) <= limit || (skipped += 1; continue)
        # Some data checkouts represent symlinks as tiny text files.
        filesize(file) >= 4 || (skipped += 1; continue)
        marker = open(io -> read(io, UInt32), file, "r")
        (ntoh(marker) == 16 || ltoh(marker) == 16) || (skipped += 1; continue)
        try
            raw = read_binary(file)
            io = IOBuffer()
            write_binary(io, raw)
            seekstart(io)
            back = read_binary(io)
            @test length(raw) == length(back)
            @test all(a.name == b.name && a.type == b.type && isequal(a.data, b.data) for (a,b) in zip(raw, back))
            if ext == ".EGRID"
                read_egrid(file)
            elseif ext == ".INIT"
                read_init(file)
            elseif ext == ".UNRST"
                read_restart(file; steps = [1])
            elseif ext == ".SMSPEC"
                base = splitext(file)[1]
                if isfile("$base.UNSMRY") && filesize("$base.UNSMRY") <= limit
                    read_summary(file; format = :structured)
                end
            end
            counts[ext] = get(counts, ext, 0) + 1
        catch e
            push!(failures, file => sprint(showerror, e))
            length(failures) <= 12 && println(last(failures))
        end
    end
    println("Validated OPM files: ", sort!(collect(counts)), "; skipped oversized/text files: ", skipped)
    @test isempty(failures)
end
