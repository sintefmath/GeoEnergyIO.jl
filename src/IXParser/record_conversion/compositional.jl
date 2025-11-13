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

function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Val{:ThermalModel})
    return String(x.value)
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:FluidEnthalpy})
    out = Dict()
    out["group"] = String(x.value)
    for v in x.body
        kw = v.keyword
        if kw == "DataType"
            out["DataType"] = String(v.value)
        elseif kw == "Temperature"
            out["Temperature"] = swap_unit_system(v.value, unit_systems, :relative_temperature)
        elseif kw == "Pressure"
            out["Pressure"] = swap_unit_system(v.value, unit_systems, :pressure)
        else
            out[kw] = v.value
        end
    end
    return out
end

function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Union{Val{:EnthalpyLiquidHeatCapacity}, Val{:EnthalpyVaporHeatCapacity}})
    out = Dict()
    for entry in x.value
        entry::IXEqualRecord
        kw = entry.keyword
        val = copy(entry.value)
        u = get_unit_type_ix_keyword(unit_systems, kw)
        out[kw] = swap_unit_system!(val, unit_systems, u)
    end
    return out
end
