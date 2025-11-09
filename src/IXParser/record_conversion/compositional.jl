function convert_ix_record(x, unit_systems, meta, ::Val{:ComponentProperties})
    tab = Dict()
    set_ix_array_values!(tab, x.value, T = Float64)
    convert_dict_entries!(tab, unit_systems)
    return tab
end
