function convert_ix_record(x, unit_systems, meta, ::Val{:ComponentProperties})
    tab = Dict()
    set_ix_array_values!(tab, x.value, T = Float64)
    convert_dict_entries!(tab, unit_systems)
    return tab
end

function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Val{:StandardPressure})
    return swap_unit_system(x.value, unit_systems, :pressure)
end

function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Val{:StandardTemperature})
    return swap_unit_system(x.value, unit_systems, :relative_temperature)
end
