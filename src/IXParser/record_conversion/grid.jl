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

function convert_ix_record(x::IXEqualRecord, unit_systems, unhandled::AbstractDict, ::Val{:Faults})
    names = String[]
    for rec in x.value
        rec.keyword == "FaultNames" || error("Expected FaultNames record in Faults record body, got $(rec.keyword)")
        append!(names, rec.value)
    end
    return names
end

function convert_ix_record(x::IXStandardRecord, unit_systems, unhandled::AbstractDict, ::Val{:FaultDefinition})
    name = x.value
    data = Dict{String, Any}()
    for rec in x.body
        if !haskey(data, rec.keyword)
            data[rec.keyword] = Dict{String, Any}()
        end
        if rec.keyword == "FaultIJKBoxDefinition"
            d = Dict{String, Any}()
            set_ix_array_values!(d, rec.body)
            data[rec.keyword][rec.value] = d
        else
            data[rec.keyword] = rec
        end
    end
    return (name = name, data = data)
end

function convert_ix_record(x, unit_systems, unhandled::AbstractDict, ::Val{:RockRegionMapping})
    return convert_region_mapping(x)
end

function convert_ix_record(x, unit_systems, unhandled::AbstractDict, ::Val{:FluidRegionMapping})
    return convert_region_mapping(x)
end

function convert_ix_record(x, unit_systems, unhandled::AbstractDict, ::Val{:EquilibriumRegionMapping})
    return convert_region_mapping(x)
end

function convert_region_mapping(x::IXEqualRecord)
    tab = Dict{String, Any}()
    set_ix_array_values!(tab, x)
    out = Dict(
        "name" => x.value,
        "table" => tab,
    )
    return out
end
