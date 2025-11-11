function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Val{:StructuredInfoMgr})
    if length(x.value) == 0
        uuid = missing
    else
        uuid = only(x.value).value
    end
    return Dict(
        "name" => x.keyword,
        "UUID" => uuid
    )
end
