function convert_ix_record(x, unit_systems, meta::AbstractDict, ::Val{:SaturationFunction})
    return parse_and_convert_numerical_table(x, unit_systems, "SaturationFunction")
end
