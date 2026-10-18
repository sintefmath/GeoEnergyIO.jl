# Optional integration suite: run in an environment containing JutulDarcy.
using GeoEnergyIO, JutulDarcy, Jutul, Test, Dates

@testset "StandardIO JutulDarcy states and results" begin
    g = UnstructuredMesh(CartesianMesh((3, 2, 1), (30.0, 20.0, 5.0)))
    domain = reservoir_domain(g; porosity = 0.25, permeability = 1e-12)
    # Reversed phase ordering detects accidental hard-coded saturation rows.
    sys = ImmiscibleSystem((LiquidPhase(), AqueousPhase()); reference_densities = [800.0, 1000.0])
    model, parameters = setup_reservoir_model(domain, sys; extra_out = true)
    state0 = setup_reservoir_state(model; Pressure = 1e7, Saturations = [0.7, 0.3])
    dt = [86400.0, 86400.0]
    case = JutulCase(model, dt; state0, parameters, start_date = DateTime(2020, 1, 1))
    states = [deepcopy(state0[:Reservoir]), deepcopy(state0[:Reservoir])]
    states[2][:Pressure] .*= 1.1
    mktempdir() do dir
        base = joinpath(dir, "RESULT")
        @test read_egrid(write_egrid(case, base))["cartDims"] == [6, 1, 1]
        griddata = GeoEnergyIO.StandardIO.output.rectangular_grid([10.0, 10.0, 10.0], [10.0, 10.0], [5.0])
        structured_case = JutulCase(model, dt; state0, parameters,
            input_data = Dict("GRID" => griddata), start_date = case.start_date)
        @test read_egrid(write_egrid(structured_case, base))["cartDims"] == [3, 2, 1]
        for units in (:metric, :field, :lab)
            write_init(case, base; units)
            init = read_init(base; units = :si)
            @test init["PORO"] ≈ fill(0.25, 6)
            @test init["INTEHEAD"][15] == 3
            @test init["PERMX"] ≈ fill(1e-12, 6) rtol=1e-6
            @test init["PORV"] ≈ fill(125.0, 6) rtol=1e-6
            for unified in (true, false)
                path = base*"_$(units)_$unified"
                write_restart(case, states, path; units, unified)
                back = read_jutuldarcy_states(path, case)
                @test read_restart(path)[1]["days"] == 1.0
                @test length(back) == 2
                for (a, b) in zip(states, back)
                    @test a[:Pressure] ≈ b[:Pressure] rtol=1e-6
                    @test a[:Saturations] ≈ b[:Saturations] rtol=1e-6
                end
            end
        end
        # A real simulation exercises ReservoirSimResult and summary_result.
        result = simulate_reservoir(case; info_level = -1)
        paths = write_jutuldarcy_results(case, result, joinpath(dir, "SIM"))
        @test isfile(paths.init)
        @test isfile(paths.grid)
        @test isfile(paths.restart)
        smry = read_summary(joinpath(dir, "SIM"); format = :jutuldarcy)
        @test smry["TIME"].seconds ≈ result.time
        @test smry["TIME"].start_date == case.start_date
        @test smry["DIMENS"] == Tuple(read_egrid(paths.grid)["cartDims"])
        @test length(read_jutuldarcy_states(paths.restart, case)) == length(result.states)
        write_summary(result.summary, joinpath(dir, "DIRECT_RESULT"))
        direct = read_summary(joinpath(dir, "DIRECT_RESULT"); format = :jutuldarcy)
        expected = JutulDarcy.summary_result(case, result, :metric)
        @test direct["VALUES"]["FIELD"]["FPR"] ≈ expected["VALUES"]["FIELD"]["FPR"] rtol=1e-6
    end
end
