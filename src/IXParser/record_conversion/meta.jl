function convert_ix_record(x::IXEqualRecord, unit_systems, meta::AbstractDict, ::Val{:StructuredInfoMgr})
    return Dict(
        "name" => x.keyword,
        "UUID" => only(x.value).value
    )
end
