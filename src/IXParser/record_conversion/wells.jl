function convert_ix_record(x::IXStandardRecord, unit_systems, meta::AbstractDict, ::Val{:WellDef})
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

function convert_ix_record(x::IXStandardRecord, unit_systems, meta::AbstractDict, ::Val{:Separator})
    return convert_ix_record_and_subrecords(x, unit_systems, meta)
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta::AbstractDict, ::Val{:SeparatorStage})
    out = convert_ix_record_to_dict(x, unit_systems)
    return out
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta::AbstractDict, ::Val{:Group})
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

function convert_ix_record(x::IXStandardRecord, unit_systems, meta::AbstractDict, ::Val{:Well})
    out = Dict{String, Any}(
        "name" => x.value,
    )
    for rec in x.body
        if rec isa IXEqualRecord
            kw = rec.keyword
            val = rec.value
            if val isa IXKeyword
                val = String(val)
            elseif val isa AbstractIXRecord
                val = convert_ix_record(rec, unit_systems, meta, kw)
            end
        elseif rec isa IXFunctionCall
            kw = rec.keyword
            val = convert_function_call(rec, unit_systems, "Well")
        elseif rec isa IXStandardRecord
            kw = rec.keyword
            val = convert_ix_record(rec, unit_systems, meta, kw)
        else
            error("Expected IXEqualRecord in Well record body, got $(typeof(rec))")
        end
        out[kw] = val
    end
    return out
end

function convert_ix_record(x::Union{IXEqualRecord, AbstractArray}, unit_systems, meta::AbstractDict, ::Union{Val{:Constraints}, Val{:HistoricalData}})
    constraints = Dict{String, Any}()
    if length(x.value) > 0
        verb = String(x.value[1])
        for k in x.value[2:end]
            constraint_value, constraint_name = k
            constraint_name = String(constraint_name)
            u = get_unit_type_ix_keyword(unit_systems, constraint_name; throw = false)
            constraints[constraint_name] = swap_unit_system(constraint_value, unit_systems, u)
        end
        out = (verb = verb, constraints = constraints)
    else
        out = missing
    end
    return out
end
