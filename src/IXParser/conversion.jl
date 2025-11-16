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
    if verbose
        println("Found $(length(tsteps)) unique time steps in IX and FM sections, starting at $start_time")
    end

    parse_arg = (verbose = verbose, strict = strict)
    out =  Dict{String, Any}()
    for s in ["IX", "FM"]
        self = copy(afi[s])
        delete!(self, "START")
        # Sync over timesteps in global order
        self_steps = OrderedDict{DateTime, Any}()
        for step in tsteps
            self_steps[step] = []
        end
        self["MODEL_DEFINITION"] = convert_ix_records(afi[s]["MODEL_DEFINITION"], "$s MODEL_DEFINITION", unit_systems; parse_arg...)
        if haskey(afi[s], "START")
            self_steps[tsteps[1]] = convert_ix_records(afi[s]["START"], "$s START", unit_systems; parse_arg...)
        end
        for d in keys(afi[s]["STEPS"])
            dt = time_from_record(d, start_time, input_units)
            if !haskey(self_steps, dt)
                self_steps[dt] = []
            end
            vals = convert_ix_records(afi[s]["STEPS"][d], "$s TIME $dt", unit_systems; parse_arg...)
            append!(self_steps[dt], vals)
        end
        self["STEPS"] = self_steps
        out[s] = self
    end
    resqml = get(afi["IX"], "RESQML", missing)
    if !ismissing(resqml)
        structured_info = find_records(afi, "StructuredInfo", "IX", steps = false, once = true)
        out["IX"]["RESQML"] = convert_resqml(resqml, unit_systems, verbose = verbose, strict = strict, structured_info = structured_info)
    end
    obsh = get(afi["FM"], "OBSH", missing)
    if !ismissing(obsh)
        out["FM"]["OBSH"] = convert_obsh(obsh, start_time, units, unit_systems; verbose = verbose, strict = strict)
    end
    return out
end

function convert_resqml(resqml, unit_systems; verbose = false, strict = false, structured_info = nothing)
    out = Dict{String, Any}()
    for r in get(resqml, "props", [])
        v = convert_resqml_props(r, unit_systems, verbose = verbose, strict = strict)
        out[v["title"]] = v
    end
    geom_and_props = get(resqml, "geom_and_props", [])
    for (i, g) in enumerate(geom_and_props)
        if i == 1
            t = "GRID"
            # A bit hacky, get the handedness-tag
            is_right_handed = false
            for v in values(g.epc)
                if v isa Dict
                    continue
                end
                rh_tag = find_string_by_tag(v, "resqml2:GridIsRighthanded")
                if !ismissing(rh_tag)
                    is_right_handed = rh_tag == "true"
                    break
                end
            end
            if isnothing(structured_info)
                if length(keys(g.epc)) == 1
                    println("No StructuredInfo provided in IX file, assuming single grid in EPC file.")
                else
                    error("Expected exactly one grid in EPC file, got $(length(keys(g.epc))). Please provide StructuredInfo with UUID record in IX file.")
                end
                uuid = first(keys(g.epc))
            else
                uuid_pos = findfirst(x -> x.keyword == "UUID", structured_info.body)
                !isnothing(uuid_pos) || error("No UUID record found in StructuredInfo, cannot identify grid in EPC file.")
                uuid = structured_info.body[uuid_pos].value
            end
            v = convert_to_grid_section(g.h5[uuid],
                actnum = get(out, "ACTIVE_CELL_FLAG", missing),
                porosity = get(out, "POROSITY", missing),
                net_to_gross = get(out, "NET_TO_GROSS_RATIO", missing)
            )
            v["extra"] = Dict{String, Any}()
            for (k, val) in pairs(v)
                v["extra"][k] = val
            end
            v["IsRightHanded"] = is_right_handed
        else
            # No idea if this actually happens in practice...
            t = "geom_and_props_$i"
            v = g
        end
        out[t] = v
    end
    return out
end

import Jutul: get_1d_interpolator
function convert_obsh(obsh_outer, start_time::DateTime, units, unit_systems; verbose = false, strict = false)
    obsh_outer = deepcopy(obsh_outer)
    diff_interp(x, t) = get_1d_interpolator(diff(t), diff(x))
    for (pth, obsh) in pairs(obsh_outer)
        u = get(obsh["metadata"], "units", missing)
        if ismissing(u)
            println("OBSH file $pth has no units metadata, assuming same as IX file.")
            usys = unit_systems
        else
            usys = get_unit_system_pair(ix_unit_keyword_to_jutul_symbol(u), units, ix_dict = conversion_ix_dict())
        end
        obsh["wells_interp"] = Dict{Symbol, Any}()
        for (k, w) in pairs(obsh["wells"])
            obsh["wells_interp"][Symbol(k)] = Dict{String, Any}()
            for (key, v) in pairs(w)
                if key == "dates"
                    continue
                end
                convert_ix_values!(v, key, usys; throw = strict)
            end
        end
        obsh["metadata"]["units"] = units
        obsh["wells_interp"] = Dict{Symbol, Any}()
        for (k, w) in pairs(obsh["wells"])
            interp_w = Dict{String, Any}()
            obsh["wells_interp"][Symbol(k)] = interp_w
            dates = w["dates"]
            t = map(d -> (d - start_time).value/1000.0, dates)
            for (key, v) in pairs(w)
                if key == "dates"
                    continue
                end
                interp_w[key] = get_1d_interpolator(t, v)
            end
            # Production
            # orat
            has_oprod_rate = haskey(interp_w, "OIL_PRODUCTION_RATE")
            has_oprod_cum = haskey(interp_w, "OIL_PRODUCTION_CUML")
            if !has_oprod_rate && has_oprod_cum
                interp_w["OIL_PRODUCTION_RATE"] = diff_interp(w["OIL_PRODUCTION_CUML"], t)
            end
            # wrat
            has_wprod_rate = haskey(interp_w, "WATER_PRODUCTION_RATE")
            has_wprod_cum = haskey(interp_w, "WATER_PRODUCTION_CUML")
            if !has_wprod_rate && has_wprod_cum
                interp_w["WATER_PRODUCTION_RATE"] = diff_interp(w["WATER_PRODUCTION_CUML"], t)
            end
            # grat
            has_gprod_rate = haskey(interp_w, "GAS_PRODUCTION_RATE")
            has_gprod_cum = haskey(interp_w, "GAS_PRODUCTION_CUML")

            if !has_gprod_rate && has_gprod_cum
                interp_w["GAS_PRODUCTION_RATE"] = diff_interp(w["GAS_PRODUCTION_CUML"], t)
            end
            # lrat
            has_lprod_rate = haskey(interp_w, "LIQUID_PRODUCTION_RATE")
            has_lprod_cum = haskey(interp_w, "LIQUID_PRODUCTION_CUML")
            if !has_lprod_cum
                val = zeros(length(t))
                if has_wprod_cum
                    val .+= w["WATER_PRODUCTION_CUML"]
                end
                if has_oprod_cum
                    val .+= w["OIL_PRODUCTION_CUML"]
                end
                interp_w["LIQUID_PRODUCTION_CUML"] = get_1d_interpolator(t, val)
                interp_w["LIQUID_PRODUCTION_RATE"] = diff_interp(val, t)
            elseif !has_lprod_rate
                interp_w["LIQUID_PRODUCTION_RATE"] = diff_interp(w["LIQUID_PRODUCTION_CUML"], t)
            end
            # Injection
            # water
            has_winj_rate = haskey(interp_w, "WATER_INJECTION_RATE")
            has_winj_cum = haskey(interp_w, "WATER_INJECTION_CUML")
            if !has_winj_rate && has_winj_cum
                interp_w["WATER_INJECTION_RATE"] = diff_interp(w["WATER_INJECTION_CUML"], t)
            end
            # gas
            has_ginj_rate = haskey(interp_w, "GAS_INJECTION_RATE")
            has_ginj_cum = haskey(interp_w, "GAS_INJECTION_CUML")
            if !has_ginj_rate && has_ginj_cum
                interp_w["GAS_INJECTION_RATE"] = diff_interp(w["GAS_INJECTION_CUML"], t)
            end
        end
    end
    return obsh_outer
end

function ix_units(afi)
    for rec in afi["IX"]["MODEL_DEFINITION"]
        if rec.keyword == "Units"
            for subrec in rec.value
                if subrec isa IXEqualRecord && subrec.keyword == "UnitSystem"
                    return ix_unit_keyword_to_jutul_symbol(subrec.value.keyword)
                end
            end
            error("Unable to find UnitSystem in Units record in IX MODEL_DEFINITION. Malformed file?")
        end
    end
    println("No Units record found in IX MODEL_DEFINITION, assuming METRIC units.")
    return :metric
end

function ix_unit_keyword_to_jutul_symbol(u)
    u = lowercase(u)
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

function reshape_ix_matrix(m0)
    m = strip_ix_endlines(m0)
    ncols = findfirst(x -> x isa IXArrayEndline, m)
    if isnothing(ncols)
        ncols = length(m) + 1
    end
    m = filter(x -> !(x isa IXArrayEndline), m)
    tmp = permutedims(reshape(m, ncols - 1, :))
    header = map(x -> x.keyword, tmp[1, :])
    return (header = header, M = tmp[2:end, :])
end

function strip_ix_endlines(m)
    start = findfirst(x -> !(x isa IXArrayEndline), m)
    stop = findlast(x -> !(x isa IXArrayEndline), m)
    return m[start:stop]
end

function set_ix_array_values!(dest, v::Vector; T = missing)
    convert_t(x::AbstractArray, T::Type) = T.(x)
    convert_t(x::AbstractArray{<:AbstractString}, T::Type) = x
    convert_t(x::Number, T::Type) = convert(T, x)
    # These don't convert
    convert_t(x, ::Missing) = x
    convert_t(x::AbstractString, ::Type) = x

    if length(v) > 0
        pos = findfirst(x -> !(x isa IXArrayEndline), v)
        !isnothing(pos) || error("No non-endline entry found in array, cannot set values.")
        v = v[pos:end]
        sample = v[1]
        if sample isa IXKeyword
            # We have a matrix with headers
            header, M = reshape_ix_matrix(v)
            for (i, h) in enumerate(header)
                dest[h] = convert_t([M[k, i] for k in axes(M, 1)], T)
            end
        else
            # We have multiple bare arrays assigning values
            for (i, er) in enumerate(v)
                h = er.keyword
                if er isa IXAssignmentRecord
                    dest_h = get(dest, h, missing)
                    ix = er.index
                    insert_val = convert_t(er.value, T)
                    if h == "PiMultiplier"
                        default = 1.0
                    elseif h == "Status"
                        default = IX_OPEN
                    else
                        @warn "No default value known for keyword $h. Setting uninitialized values."
                        default = missing
                    end
                    if ismissing(dest_h)
                        dest_h = dest[h] = Vector{typeof(insert_val)}(undef, ix)
                        if !ismissing(default)
                            dest_h .= default
                        end
                    end
                    n_current = length(dest_h)
                    if n_current < ix
                        resize!(dest_h, ix)
                        if !ismissing(default)
                            dest_h[n_current+1:end] .= default
                        end
                    end
                    dest_h[ix] = convert_t(er.value, T)
                else
                    v = er.value
                    if length(v) == 0
                        v = missing
                    end
                    dest[h] = convert_t(v, T)
                end
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

function time_from_record(x, start_time = missing, usys = missing)
    # Example str:
    # "1-Dec-2020 01:10:00.10000"
    if x.keyword == "DATE"
        val = strip(x.value)
        sval = rsplit(val, '.', limit = 2)
        if length(sval) == 2
            # Julia uses ms as integers. Strip excess values.
            msstr = sval[end]
            ndig = 3
            if length(msstr) > ndig
                msstr = msstr[1:ndig]
                val = "$(sval[1]).$msstr"
            end
        end
        return DateTime(val, dateformat"d-u-y H:M:S.s")
    else
        error("Not implemented")
        @assert x.keyword == "TIME"
        delta = x.value
    end
end

function convert_ix_value(x::Number, kw, unit_systems; throw = true)
    utype = get_unit_type_ix_keyword(unit_systems, kw; throw = throw)
    if utype != :id
        x = GeoEnergyIO.InputParser.swap_unit_system(x, unit_systems, utype)
    end
    return x
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
        :GuideRateBalanceAction,
        :FluidFlowGrid,
        :CustomControl,
        :ActionSequence,
        :Strategy,
        :Expression,
        :FluidStreamMgr,
        :FluidSourceExternal,
        :FluidSourceInternal,
        :FluidStream,
        :AllWellDrawdownLimitOptions,
        :CouplingProperties,
        :GridReport,
        :FluidMgr,
        :TimeStepSolution,
        :RegionFamily,
        :CellActivity,
        :RockOptions,
        :RockMgr,
        :KilloughRelPermHysteresis,
        :KilloughCapPressureHysteresis
    )
    edit_list = (
        :CellPropertyEdit,
        :FaultPropertyEdit,
        :BoxPropertyEdit
    )
    convert_subrecords_list = (
        :BlackOilFluidModel,
        :CompositionalFluidModel
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


function convert_ix_record_to_dict(x::Union{IXEqualRecord, IXStandardRecord}, unit_systems = missing;
        recurse = true,
        skip = Tuple{}()
    )
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
            kw = rec.keyword
            if kw in skip
                continue
            end
            if rec isa IXEqualRecord
                v = rec.value
            elseif rec isa AbstractString || rec isa IXFunctionCall
                v = rec
            elseif recurse
                v = convert_ix_record_to_dict(rec, unit_systems)
            else
                error("Type conversion for $rec with recurse=false is not implemented")
            end
            out[kw] = v
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
        println("Converting section $name:")
    end
    prev = ""
    count = 0
    count_unique = 0
    t = @elapsed for v in vals
        kw = v.keyword
        if verbose && kw != prev
            println(" | $kw")
            count_unique += 1
        end
        count += 1
        v_new = convert_ix_record(v, unit_systems, meta, kw)
        push!(out, (keyword = kw, value = v_new))
        prev = kw
    end
    if verbose && count > 0
        println(" | Converted $count records ($count_unique unique keywords) in $(round(t, sigdigits=2)) seconds.")
    end
    num_unhandled = length(keys(unhandled))
    if num_unhandled > 0 && verbose > -1
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
        inner_kw = rec.keyword
        kw_val = Val(Symbol(inner_kw))
        next = convert_ix_record(rec, unit_systems, meta, kw_val)
        if haskey(out, inner_kw)
            next =  merge_records!(out[inner_kw], next, kw_val)
        end
        out[inner_kw] = next
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

function convert_dict_entries!(table, unit_systems; skip = [])
    for (k, v) in pairs(table)
        if v isa AbstractString || isnothing(v) || ismissing(v) || k in skip
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
