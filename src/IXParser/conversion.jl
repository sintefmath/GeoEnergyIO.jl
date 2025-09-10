import GeoEnergyIO.InputParser: swap_unit_system, swap_unit_system!, swap_unit_system_axes!

include("record_conversion/record_conversion.jl")

function restructure_and_convert_units_afi(afi;
        units = :si,
        verbose = false,
        strict = false
    )
    # First we find starting dates (Simulation / FieldManagement)
    model_def = afi["IX"]["MODEL_DEFINITION"]
    sim_ix = findfirst(x -> x.keyword == "Simulation", model_def)
    !isnothing(sim_ix) || error("No Simulation record found in IX MODEL_DEFINITION.")
    start_time = start_time_from_record(model_def[sim_ix])
    input_units = ix_units(afi)
    unit_systems = get_unit_system_pair(input_units, units, ix_dict = conversion_ix_dict())

    model_def_fm = afi["FM"]["MODEL_DEFINITION"]
    fm_ix = findfirst(x -> x.keyword == "FieldManagement", model_def_fm)
    if !isnothing(fm_ix)
        fm_rec = start_time_from_record(model_def_fm[fm_ix])
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

    parse_arg = (verbose = verbose, strict = strict)
    out =  Dict{String, Any}()
    for s in ["IX", "FM"]
        out[s] = copy(afi[s])
        delete!(out[s], "START")
        out[s]["MODEL_DEFINITION"] = convert_ix_records(afi[s]["MODEL_DEFINITION"], "$s MODEL_DEFINITION", unit_systems; parse_arg...)
        out[s]["STEPS"] = OrderedDict{DateTime, Any}()
        if haskey(afi[s], "START")
            out[s]["STEPS"][tsteps[1]] = convert_ix_records(afi[s]["START"], "$s START", unit_systems; parse_arg...)
        end
        for d in keys(afi[s]["STEPS"])
            dt = time_from_record(d, start_time, input_units)
            out[s]["STEPS"][dt] = convert_ix_records(afi[s]["STEPS"][d], "$s TIME $dt", unit_systems; parse_arg...)
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

function set_ix_array_values!(dest, v::Vector; T = missing)
    convert_t(x::AbstractArray, T::Type) = T.(x)
    convert_t(x::Number, T::Type) = convert(T, x)
    # These don't convert
    convert_t(x, ::Missing) = x
    convert_t(x::AbstractString, ::Type) = x

    if length(v) > 0
        sample = v[1]
        if sample isa IXKeyword
            # We have a matrix with headers
            header, M = reshape_ix_matrix(v)
            for (i, h) in enumerate(header)
                dest[h] = convert_t([M[k, i] for k in axes(M, 1)], T)
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
                dest[h] = convert_t(v, T)
            end
        end
    end
    return dest
end

function set_ix_array_values!(dest, rec::IXEqualRecord)
    return set_ix_array_values!(dest, rec.value)
end

function get_unit_system_pair(from::Symbol, target::Symbol; kwarg...)
    from_sys = GeoEnergyIO.InputParser.DeckUnitSystem(from)
    target_sys = GeoEnergyIO.InputParser.DeckUnitSystem(target)
    # We have a pair of unit systems to convert between
    return (; from = from_sys, to = target_sys, kwarg...)
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

function convert_ix_values!(x::AbstractArray, kw, unit_systems; throw = true)
    utype = get_unit_type_ix_keyword(unit_systems, kw; throw = throw)
    if utype != :id
        GeoEnergyIO.InputParser.swap_unit_system!(x, unit_systems, utype)
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

function convert_ix_record(val, unit_systems, meta, ::Val{kw}) where kw
    skip_list = (
        :Units,
        :Simulation,
        :FieldManagement,
        :GridMgr,
        :END_INPUT
    )
    single_equals_list = (
        :Completion,
        :HistoricalControlModes,
        :GuideRateBalanceAction,
        :FluidFlowGrid,
        :CustomControl,
        :ActionSequence,
        :Strategy,
        :Expression,
        :FluidStreamMgr,
        :AllWellDrawdownLimitOptions,
        :CouplingProperties,
        :GridReport,
        :FluidMgr,
        :TimeStepSolution,
        :RegionFamily,
        :CellActivity,
        :RockOptions
    )
    edit_list = (
        :CellPropertyEdit,
        :FaultPropertyEdit,
        :BoxPropertyEdit
    )
    convert_subrecords_list = (
        :BlackOilFluidModel,
    )
    # Main.lastrec[] = val
    kw_as_str = "$kw"
    if kw in single_equals_list
        val = convert_ix_record_to_dict(val, recurse = true)
    elseif kw in edit_list || endswith(kw_as_str, "Edit")
        val = convert_edit_record(val)
    elseif kw in convert_subrecords_list
        val = convert_ix_record_and_subrecords(val, unit_systems, meta)
    elseif !(kw in skip_list)
        is_report = endswith(kw_as_str, "Report") || endswith(kw_as_str, "Reports")
        if !is_report
            log_unhandled!(meta, kw)
        end
    end
    return val
end

function log_unhandled!(meta, kw)
    kw = Symbol(kw)
    uhandled = meta.unhandled
    if haskey(uhandled, kw)
        uhandled[kw] += 1
    else
        uhandled[kw] = 1
    end
    if meta.strict
        error("Unhandled keyword $kw. As strict=true, this is an error.")
    end
end

function convert_ix_record(val, unit_systems, meta, kw::Symbol)
    return convert_ix_record(val, unit_systems, meta, Val(kw))
end

function convert_ix_record(val, unit_systems, meta, kw::String)
    return convert_ix_record(val, unit_systems, meta, Symbol(kw))
end

function convert_edit_record(x::IXStandardRecord)
    out = Dict{String, Any}(
        "group" => x.value,
        "name" => x.keyword,
    )
    if length(x.body) == 1
        v = only(x.body)
        v::IXEqualRecord
        out[v.keyword] = v.value
    else
        set_ix_array_values!(out, x.body)
    end
    return out
end


function convert_ix_record_to_dict(x::Union{IXEqualRecord, IXStandardRecord}, unit_systems = missing; recurse = true)
    out = Dict{String, Any}(
        "name" => x.keyword
    )
    if x isa IXStandardRecord
        out["group"] = x.value
        dest = x.body
    else
        dest = x.value
    end
    is_endline = any(y -> y isa IXArrayEndline, dest)
    if is_endline
        # Some kind of matrix/array
        set_ix_array_values!(out, dest)
    else
        for rec in dest
            if rec isa IXEqualRecord
                v = rec.value
            elseif rec isa AbstractString || rec isa IXFunctionCall
                v = rec
            elseif recurse
                v = convert_ix_record_to_dict(rec, unit_systems)
            else
                error("Type conversion for $rec with recurse=false is not implemented")
            end
            out[rec.keyword] = v
        end
    end
    if !ismissing(unit_systems)
        convert_dict_entries!(out, unit_systems)
    end
    return out
end


function convert_ix_records(vals::AbstractVector, name, unit_systems; verbose = false, strict = false)
    out = Any[]
    unhandled = OrderedDict{Symbol, Int}()
    meta = (
        unhandled = unhandled,
        verbose = verbose,
        strict = strict
    )
    if verbose && length(vals) > 0
        println("Converting entry $name")
    end
    for v in vals
        kw = v.keyword
        if verbose
            println("> $kw")
        end
        v_new = convert_ix_record(v, unit_systems, meta, kw)
        push!(out, (keyword = kw, value = v_new))
    end
    num_unhandled = length(keys(unhandled))
    if num_unhandled > 0
        println("$name: Found $num_unhandled meta IX record types:")
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

function convert_ix_record_and_subrecords(x::IXStandardRecord, unit_systems, meta)
    kw = x.keyword
    out = Dict{String, Any}(
        "group" => x.value,
        "name" => kw
    )
    if x.body isa AbstractIXRecord
        x.body = [x.body]
    end
    for rec in x.body
        out[rec.keyword] = convert_ix_record(rec, unit_systems, meta, Val(Symbol(rec.keyword)))
    end
    return out
end

function parse_and_convert_numerical_table(x::IXStandardRecord, unit_systems, k = missing)
    if !ismissing(k)
        @assert x.keyword == k
    end
    table = Dict{String, Any}()
    out = Dict{String, Any}(
        "name" => x.value,
        "table" => table,
    )
    set_ix_array_values!(table, x.body, T = Float64)
    convert_dict_entries!(table, unit_systems)
    return out
end

function convert_dict_entries!(table, unit_systems)
    for (k, v) in pairs(table)
        if v isa AbstractString || isnothing(v) || ismissing(v)
            continue
        end

        if v isa AbstractDict
            convert_dict_entries!(v, unit_systems)
        elseif v isa IXKeyword
            v = v.keyword
        else
            u = get_unit_type_ix_keyword(unit_systems, k)
            if v isa Number
                v = swap_unit_system(v, unit_systems, u)
            else
                swap_unit_system!(v, unit_systems, u)
            end
        end
        table[k] = v
    end
end

function convert_ix_record(x, unit_systems, meta, ::Val{:RockCompressibility})
    return parse_and_convert_numerical_table(x, unit_systems, "RockCompressibility")
end

function get_unit_type_ix_keyword(unit_systems, k; throw = false)
    u = get(unit_systems.ix_dict, k, missing)
    if ismissing(u)
        msg = "No unit type declared for IX entry $k. Units may be wrong! Add it to conversion_ix_dict() if needed."
        u = :id
        if throw
            error(msg)
        else
            println(msg)
        end
    end
    return u
end
