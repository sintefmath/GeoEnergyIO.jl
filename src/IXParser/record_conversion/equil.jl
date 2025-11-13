function convert_ix_record(x, unit_systems, meta, ::Val{:Equilibrium})
    tab_keys = ("SolutionGORDepthTable", "TemperatureDepthTable")
    tab = convert_ix_record_to_dict(x, skip = tab_keys)
    if x isa IXStandardRecord
        dest = x.body
    else
        dest = x.value
    end
    for val in dest
        if val.keyword in tab_keys
            eq_tab = Dict{String, Any}()
            set_ix_array_values!(eq_tab, val.value, T = Float64)
            convert_dict_entries!(eq_tab, unit_systems)
            tab[val.keyword] = eq_tab
        end
    end
    convert_dict_entries!(tab, unit_systems, skip = tab_keys)
    return Dict(tab["group"] => tab)
end
