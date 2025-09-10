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
