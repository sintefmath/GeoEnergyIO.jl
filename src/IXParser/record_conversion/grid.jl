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
