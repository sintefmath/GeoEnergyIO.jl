
function restructure_and_convert_units_afi(afi;
        units = :si,
    )
    # First we find starting dates (Simulation / FieldManagement)
    model_def = afi["IX"]["MODEL_DEFINITION"]
    sim_ix = findfirst(x -> x.keyword == "Simulation", model_def)
    !isnothing(sim_ix) || error("No Simulation record found in IX MODEL_DEFINITION.")
    start_time = start_time_from_record(model_def[sim_ix])
    input_units = ix_units(afi)
    unit_systems = get_unit_system_pair(input_units, units)

    model_def_fm = afi["FM"]["MODEL_DEFINITION"]
    fm_ix = findfirst(x -> x.keyword == "FieldManagement", model_def_fm)
    if !isnothing(sim_ix)
        fm_rec = start_time_from_record(model_def[sim_ix])
        if fm_rec != start_time
            @warn "Simulation and FieldManagement start times do not match. IX=$start_time, FM=$fm_rec"
        end
    end

    tsteps = DateTime[]
    push!(tsteps, start_time)
    for m in ["IX", "FM"]
        for d in keys(afi[m]["STEPS"])
            push!(tsteps, time_from_record(d, start_time, input_units))
        end
    end
    unique!(tsteps)
    sort!(tsteps)
    @assert tsteps[1] == start_time
    @info "Found $(length(tsteps)) unique time steps in IX and FM sections, starting at $start_time"
    # out = Dict{String, Any}(
    #     "wells" => Dict{String, Any}(),
    #     "schedule" => Dict{String, Any}(),
    #     "pvtfun" => Dict{String, Any}(),
    #     "satfun" => Dict{String, Any}(),
    #     "init" => Dict{String, Any}()
    # )


    out =  Dict{String, Any}()
    for s in ["IX", "FM"]
        out[s] = copy(afi[s])
        delete!(out[s], "START")
        out[s]["MODEL_DEFINITION"] = convert_ix_records(afi[s]["MODEL_DEFINITION"], "$s MODEL_DEFINITION", unit_systems)
        out[s]["STEPS"] = OrderedDict{DateTime, Any}()
        if haskey(afi[s], "START")
            out[s]["STEPS"][tsteps[1]] = convert_ix_records(afi[s]["START"], "$s START", unit_systems)
        end
        for d in keys(afi[s]["STEPS"])
            dt = time_from_record(d, start_time, input_units)
            out[s]["STEPS"][dt] = convert_ix_records(afi[s]["STEPS"][d], "$s TIME $dt", unit_systems)
        end
    end
    resqml = get(afi["IX"], "RESQML", missing)
    if !ismissing(resqml)
        out["RESQML"] = Dict{String, Any}()
        for r in get(resqml, "props", [])
            v = convert_resqml_props(r)
            out["RESQML"][v["title"]] = v
        end
    end
    return out
end

function ix_units(afi)
    for rec in afi["IX"]["MODEL_DEFINITION"]
        if rec.keyword == "Units"
            for subrec in rec.value
                if subrec isa IXEqualRecord && subrec.keyword == "UnitSystem"
                    u = lowercase(subrec.value.keyword)
                    if u == "eclipse_field"
                        return :field
                    elseif u == "eclipse_metric"
                        return :metric
                    elseif u == "eclipse_lab"
                        return :lab
                    else
                        error("Unknown unit system $u in IX MODEL_DEFINITION.")
                    end
                end
            end
            error("Unable to find UnitSystem in Units record in IX MODEL_DEFINITION. Malformed file?")
        end
    end
    println("No Units record found in IX MODEL_DEFINITION, assuming METRIC units.")
    return :metric
end

function reshape_ix_matrix(m)
    ncols = findfirst(x -> x isa IXArrayEndline, m)
    !isnothing(ncols) || error("No IXKeyword found in matrix, cannot reshape.")
    m = filter(x -> !(x isa IXArrayEndline), m)
    tmp = permutedims(reshape(m, ncols - 1, :))
    header = map(x -> x.keyword, tmp[1, :])
    return (header = header, M = tmp[2:end, :])
end

function set_ix_array_values!(dest, v::Vector)
    if length(v) > 0
        sample = v[1]
        if sample isa IXKeyword
            # We have a matrix with headers
            header, M = reshape_ix_matrix(v)
            for (i, h) in enumerate(header)
                dest[h] = [M[k, i] for k in axes(M, 1)]
            end
        else
            sample::IXEqualRecord
            # We have multiple bare arrays assigning values
            for (i, er) in enumerate(v)
                h = er.keyword
                v = er.value
                if length(v) == 0
                    v = missing
                end
                dest[h] = v
            end
        end
    end
    return dest
end

function set_ix_array_values!(dest, rec::IXEqualRecord)
    return set_ix_array_values!(dest, rec.value)
end

function get_unit_system_pair(from::Symbol, target::Symbol)
    from_sys = GeoEnergyIO.InputParser.DeckUnitSystem(from)
    target_sys = GeoEnergyIO.InputParser.DeckUnitSystem(target)
    # We have a pair of unit systems to convert between
    return (from = from_sys, to = target_sys)
end

function find_keyword(x::Vector, kw::String)
    for i in x
        if i.keyword == kw
            return i
        end
    end
    return nothing
end

function unpack_equals(x::Vector)
    out = OrderedDict{String, Any}()
    for i in x
        i::IXEqualRecord
        out[i.keyword] = i.value
    end
    return out
end

function month_to_int(m::AbstractString)
    m = lowercase(m)[1:3]
    months = Dict(
        "jan" => 1,
        "feb" => 2,
        "mar" => 3,
        "apr" => 4,
        "may" => 5,
        "jun" => 6,
        "jul" => 7,
        "aug" => 8,
        "sep" => 9,
        "oct" => 10,
        "nov" => 11,
        "dec" => 12
    )
    if haskey(months, m)
        return months[m]
    else
        error("Unknown month string: $m")
    end
end

function start_time_from_record(x)
    sim_rec = unpack_equals(x.value)
    start_time = DateTime(
        sim_rec["StartYear"],
        month_to_int(sim_rec["StartMonth"].keyword),
        get(sim_rec, "StartDay", 1),
        get(sim_rec, "StartHour", 0),
        get(sim_rec, "StartMinute", 0),
        get(sim_rec, "StartSecond", 0),
    )
    return start_time
end

function time_from_record(x, start_time, usys)
    if x.keyword == "DATE"
        d, m, y = split(x.value, '-')
        d = parse(Int, d)
        m = month_to_int(m)
        y = parse(Int, y)
        return DateTime(y, m, d)
    else
        error("Not implemented")
        @assert x.keyword == "TIME"
        delta = x.value
    end
end

function conversion_ix_dict()
    u = Dict{String, Symbol}()

    # WellDef
    u["WellBoreRadius"] = :length
    u["Transmissibility"] = :transmissibility
    u["Cell"] = :id
    u["Completion"] = :id
    u["PenetrationDirection"] = :id
    u["PiMultiplier"] = :id
    u["Status"] = :id
    u["RockRegionName"] = :id
    u["SegmentNode"] = :id
    u["Status"] = :id
    # TODO: Check.
    u["Skin"] = :id
    return u
end

function convert_ix_values!(x::AbstractArray, kw, unit_systems; throw = true, u = conversion_ix_dict())
    if haskey(u, kw)
        utype = u[kw]
        if utype != :id
            GeoEnergyIO.InputParser.swap_unit_system!(x, unit_systems, utype)
        end
    elseif throw
        error("No conversion rule for IX array with keyword $kw")
    else
        println("No conversion rule for IX array with keyword $kw, returning as-is.")
    end
    return x
end

function convert_ix_values!(x::AbstractDict, kw, unit_systems; kwarg...)
    for (k, v) in pairs(x)
        convert_ix_values!(v, k, unit_systems; kwarg...)
    end
    return x
end

function convert_ix_values!(x::Missing, kw, unit_systems; kwarg...)
    return x
end

function convert_ix_record(val, unit_systems, unhandled::AbstractDict, ::Val{kw}) where kw
    skip_list = (
        :Units,
        :Simulation,
        :GridMgr,
    )
    single_equals_list = (
        :FluidFlowGrid,
        :AllWellDrawdownLimitOptions,
        :GridReport,
        :TimeStepSolution,
        :RegionFamily
    )
    edit_list = (
        :CellPropertyEdit,
        :BoxPropertyEdit
    )
    if kw in single_equals_list
        val = convert_ix_record_to_dict(val)
    elseif kw in edit_list
        val = convert_edit_record(val)
    elseif !(kw in skip_list)
        if haskey(unhandled, kw)
            unhandled[kw] += 1
        else
            unhandled[kw] = 1
        end

        @info "Unhandled" val
        @info "!!" val.body
        error()
        # println("Unknown IX record with keyword $kw, returning as-is. Units may not be converted, use with care.")
    end
    return val
end

function convert_ix_record(x::IXStandardRecord, unit_systems, unhandled::AbstractDict, ::Val{:StructuredInfo})
    I = 0
    J = 0
    K = 0
    first_cell_id = 1
    uuid = missing
    for rec in x.body
        if rec isa IXEqualRecord
            if rec.keyword == "NumberCellsInI"
                I = rec.value
            elseif rec.keyword == "NumberCellsInJ"
                J = rec.value
            elseif rec.keyword == "NumberCellsInK"
                K = rec.value
            elseif rec.keyword == "UUID"
                uuid = rec.value
            elseif rec.keyword == "FirstCellId"
                first_cell_id = rec.value
            else
                @info "Unhandled IX StructuredInfo field $(rec.keyword)"
            end
        else
            error("Expected IXEqualRecord in StructuredInfo record body, got $(typeof(rec))")
        end
    end
    return Dict{String, Any}(
        "name" => x.value,
        "I" => I,
        "J" => J,
        "K" => K,
        "FirstCellId" => first_cell_id,
        "UUID" => uuid,
    )
end

function convert_ix_record(x::IXEqualRecord, unit_systems, unhandled::AbstractDict, ::Val{:StructuredInfoMgr})
    return Dict(
        "name" => x.keyword,
        "UUID" => only(x.value).value
    )
end

function convert_edit_record(x::IXStandardRecord)
    out = Dict{String, Any}(
        "group" => x.value,
        "name" => x.keyword,
    )
    @info "???" out x.body
    set_ix_array_values!(out, x.body)
    @info "??" out x.body
    return out
end

function convert_ix_record(x::IXStandardRecord, unit_systems, unhandled::AbstractDict, ::Val{:WellDef})
    @assert x.keyword == "WellDef"
    wname = x.value
    well = Dict{String, Any}(
        "WellToCellConnections" => Dict{String, Any}(),
        "Functions" => Any[]
    )
    for rec in x.body
        kw = rec.keyword
        if kw == "WellToCellConnections"
            set_ix_array_values!(well[kw], rec)
        elseif rec isa IXFunctionCall
            push!(well["Functions"], rec)
        elseif rec isa IXEqualRecord
            well[kw] = rec.value
        else
            # No idea...
            well[kw] = rec
        end
    end
    for (k, v) in pairs(well)
        if k == "WellToCellConnections"
            well[k] = convert_ix_values!(v, k, unit_systems; throw = true)
        elseif k in ("Undefined", "ResVolConditions", "Functions", "PseudoPressureModel", "AllowCrossFlow", "HeadDensityCalculation")
            # Do nothing
        else
            @info "Unhandled IX WellDef field $k..."
        end
    end
    return well
end

function convert_ix_record_to_dict(x::IXEqualRecord)
    out = Dict{String, Any}(
        "name" => x.keyword
    )
    for rec in x.value
        rec::IXEqualRecord
        out[rec.keyword] = rec.value
    end
    return out
end

function convert_ix_record_to_dict(x::IXStandardRecord)
    out = Dict{String, Any}(
        "group" => x.value,
        "name" => x.keyword
    )
    for rec in x.body
        rec::IXEqualRecord
        out[rec.keyword] = rec.value
    end
    return out
end

function convert_ix_records(vals::AbstractVector, name, unit_systems)
    out = Any[]
    unhandled = OrderedDict{Symbol, Int}()
    for v in vals
        v_new = convert_ix_record(v, unit_systems, unhandled, Val(Symbol(v.keyword)))
        push!(out, (keyword = v.keyword, value = v_new))
    end
    num_unhandled = length(keys(unhandled))
    if num_unhandled > 0
        println("$name: Found $num_unhandled unhandled IX record types:")
        for (k, v) in pairs(unhandled)
            if v == 1
                println("  $k: $v occurence.")
            else
                println("  $k: $v occurences.")
            end
        end
    end
    return out
end

