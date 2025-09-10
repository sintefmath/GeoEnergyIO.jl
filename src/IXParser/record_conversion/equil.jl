function convert_ix_record(x, unit_systems, meta, ::Val{:Equilibrium})
    tab = convert_ix_record_to_dict(x)
    convert_dict_entries!(tab, unit_systems)
    return tab
end
