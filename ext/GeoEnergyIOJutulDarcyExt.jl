module GeoEnergyIOJutulDarcyExt
    using GeoEnergyIO
    using JutulDarcy
    using Dates
    import Jutul
    import GeoEnergyIO.StandardIO: BinaryKeyword, KeywordFile
    import GeoEnergyIO.StandardIO.output: case_grid, grid_dims, standard_headers, state_keywords, case_start_date

    function GeoEnergyIO.StandardIO.output.phase_mask(system::JutulDarcy.MultiPhaseSystem)
        mask = 0
        for phase in JutulDarcy.get_phases(system)
            mask |= phase isa JutulDarcy.AqueousPhase ? 1 : phase isa JutulDarcy.LiquidPhase ? 2 : phase isa JutulDarcy.VaporPhase ? 4 :
                throw(ArgumentError("Unsupported phase $(typeof(phase))"))
        end
        return mask
    end

    function model_phases(case)
        sys = JutulDarcy.reservoir_model(case).system
        phases = JutulDarcy.get_phases(sys)
        return map(phases) do phase
            phase isa JutulDarcy.AqueousPhase && return :water
            phase isa JutulDarcy.LiquidPhase && return :oil
            phase isa JutulDarcy.VaporPhase && return :gas
            throw(ArgumentError("Cannot map phase $(typeof(phase)) to the industry standard format"))
        end
    end

    function GeoEnergyIO.StandardIO.output.write_jutuldarcy_summary(path::AbstractString,
            case::Jutul.JutulCase, result::JutulDarcy.ReservoirSimResult; units = missing, kw...)
        summary = case_summary(case, result, units)
        return GeoEnergyIO.StandardIO.output.write_jutuldarcy_summary(path, summary; kw...)
    end

    function case_summary(case, result, units)
        summary = JutulDarcy.summary_result(case, result, units; start_date = case_start_date(case))
        summary["DIMENS"] = grid_dims(case_grid(case))
        return summary
    end

    function GeoEnergyIO.StandardIO.output.write_restart(case::Jutul.JutulCase,
            result::JutulDarcy.ReservoirSimResult, path::AbstractString; kw...)
        return GeoEnergyIO.write_restart(case, result.states, path; times = result.time, kw...)
    end

    function GeoEnergyIO.StandardIO.output.write_restart(case::Jutul.JutulCase,
            states::AbstractVector, path::AbstractString; times = cumsum(case.dt), units = :metric,
            unified = true, endian = :big, report_steps = eachindex(states))
        length(states) == length(times) == length(report_steps) || throw(ArgumentError("States, times and report steps must have equal lengths"))
        all(isfinite, times) && all(>=(0), times) && issorted(times) || throw(ArgumentError("Restart times must be finite, nonnegative and sorted"))
        grid = case_grid(case)
        dims = grid_dims(grid)
        nc = count(!iszero, grid["ACTNUM"])
        phases = model_phases(case)
        mask = sum(p -> Dict(:water => 1, :oil => 2, :gas => 4)[p], phases)
        start = case_start_date(case)
        blocks = KeywordFile[]
        for (state, elapsed, report_step) in zip(states, times, report_steps)
            kws = BinaryKeyword[BinaryKeyword("SEQNUM", Int32[report_step])]
            append!(kws, standard_headers(dims, nc; units, phases = mask, elapsed, start_date = start, report_step))
            push!(kws, BinaryKeyword("STARTSOL", UInt8[]; type = "MESS"))
            arrays = state_keywords(state, phases; units)
            all(k -> length(k.data) == nc, arrays) || throw(ArgumentError("State array length differs from case active cells"))
            append!(kws, arrays)
            push!(kws, BinaryKeyword("ENDSOL", UInt8[]; type = "MESS"))
            push!(blocks, KeywordFile(kws))
        end
        return GeoEnergyIO.write_restart(blocks, path; unified, endian)
    end

    """
        write_jutuldarcy_results(case, result, path; units=:metric, unified=true)

    Export EGRID, INIT, SMSPEC/UNSMRY and reservoir UNRST solution arrays from a
    JutulDarcy case and simulation result. Values are converted from SI using
    JutulDarcy's existing summary_result and deck unit conventions.
    """
    function GeoEnergyIO.StandardIO.output.write_jutuldarcy_results(case::Jutul.JutulCase,
            result::JutulDarcy.ReservoirSimResult, path::AbstractString; units = :metric,
            unified = true, endian = :big)
        phases = model_phases(case)
        mask = sum(p -> Dict(:water => 1, :oil => 2, :gas => 4)[p], phases)
        grid = GeoEnergyIO.write_egrid(case, path; units, endian)
        init = GeoEnergyIO.write_init(case, path; units, endian, phases = mask)
        summary = case_summary(case, result, units)
        smry = GeoEnergyIO.write_summary(summary, path; unified, endian)
        restart = GeoEnergyIO.write_restart(case, result, path; units, unified, endian)
        return (grid = grid, init = init, summary = smry, restart = restart)
    end

    function GeoEnergyIO.read_jutuldarcy_states(path::AbstractString, case::Jutul.JutulCase;
            extra_out = false, kw...)
        grid = case_grid(case)
        steps = GeoEnergyIO.read_restart(path; actnum = grid["ACTNUM"], units = :si, kw...)
        phases = model_phases(case)
        nc = count(!iszero, grid["ACTNUM"])
        states = Dict{Symbol, Any}[]
        for step in steps
            h = step["INTEHEAD"]
            Tuple(h[9:11]) == grid_dims(grid) && h[12] == nc || throw(ArgumentError("Restart grid does not match case"))
            state = Dict{Symbol, Any}()
            for (key, name) in ((:Pressure, "PRESSURE"), (:Temperature, "TEMP"), (:Rs, "RS"), (:Rv, "RV"))
                if haskey(step, name)
                    length(step[name]) == nc || throw(ArgumentError("$name length differs from case active cells"))
                    state[key] = copy(step[name])
                end
            end
            if any(k -> haskey(step, k), ("SWAT", "SGAS", "SOIL"))
                sat = zeros(length(phases), nc)
                for (i, phase) in enumerate(phases)
                    key = Dict(:water => "SWAT", :oil => "SOIL", :gas => "SGAS")[phase]
                    if haskey(step, key)
                        length(step[key]) == nc || throw(ArgumentError("$key length differs from case active cells"))
                        sat[i, :] = step[key]
                    elseif phase == :oil
                        sat[i, :] .= 1
                        for other in ("SWAT", "SGAS")
                            haskey(step, other) && (sat[i, :] .-= step[other])
                        end
                    end
                end
                state[:Saturations] = sat
            end
            comps = String[]
            i = 1
            while haskey(step, "ZMF$i")
                push!(comps, "ZMF$i")
                i += 1
            end
            !isempty(comps) && (state[:OverallMoleFractions] = reduce(vcat, [permutedims(step[k]) for k in comps]))
            push!(states, state)
        end
        return extra_out ? (states, steps) : states
    end
end
