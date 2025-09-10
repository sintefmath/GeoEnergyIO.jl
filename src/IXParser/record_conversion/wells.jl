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

function convert_ix_record(x::IXStandardRecord, unit_systems, unhandled::AbstractDict, ::Val{:Separator})
    return convert_ix_record_and_subrecords(x, unit_systems, unhandled)
end

function convert_ix_record(x::IXStandardRecord, unit_systems, unhandled::AbstractDict, ::Val{:SeparatorStage})
    out = convert_ix_record_to_dict(x, unit_systems)
    return out
end

function convert_ix_record(x::IXStandardRecord, unit_systems, unhandled::AbstractDict, ::Val{:Group})
    Main.lastrec[] = x
    group_name = x.value
    members = Tuple{String, String}[]
    for rec in x.body
        rec.keyword == "Members" || error("Expected Members record in Group record body, got $(rec.keyword))")
        @assert length(rec.value) == 2
        group_type, group_members = rec.value
        for v in group_members
            push!(members, (group_type, v))
        end
    end
    return (group = group_name, members = members, )
end

function convert_ix_record(x::IXStandardRecord, unit_systems, unhandled::AbstractDict, ::Val{:Well})
    @info "???" x

    out = Dict{String, Any}(
        "name" => x.value,
    )
    for rec in x.body
        @info "???" rec
        if rec isa IXEqualRecord
            kw = rec.keyword
            val = rec.value
            if val isa IXKeyword
                val = String(val)
            end
        elseif rec isa IXFunctionCall
            kw = rec.keyword
            val = convert_function_call(rec, unit_systems, "Well")
        elseif rec isa IXStandardRecord
            kw = rec.keyword
            val = convert_ix_record(rec, unit_systems, unhandled, kw)
        else
            error("Expected IXEqualRecord in Well record body, got $(typeof(rec))")
        end
        out[kw] = val
    end
    return out
end

function convert_function_call(fcall::IXFunctionCall, unit_systems, context_kw = missing)
    kw = fcall.keyword
    args = fcall.args
        Main.lastrec[] = fcall

    converted_args = map(arg -> convert_function_argument(arg, unit_systems, context_kw), args)
    return IXFunctionCall(kw, converted_args)
end

function convert_function_argument(arg, unit_systems, context_kw = missing)
    kw = arg.keyword
    function convert_farg(x::IXKeyword)
        return x
    end
    function convert_farg(x::AbstractString)
        return x
    end
    function convert_farg(x)
        @info "???" x
        error()
    end

    return IXEqualRecord(kw, map(convert_farg, arg.value))
end
