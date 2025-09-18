function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Union{Val{:GasSurfaceDensity}, Val{:OilSurfaceDensity}, Val{:WaterSurfaceDensity}})
    return swap_unit_system(x.value, unit_systems, :density)
end

function convert_ix_record(
        x::IXStandardRecord,
        unit_systems,
        meta,
            ::Union{
                Val{:OilTable},
                Val{:UndersaturatedGasTable},
                Val{:DeadOilTable}
            }
    )
    table = Dict{String, Any}()
    out = Dict{String, Any}(
        "name" => x.value,
        "table" => table,
    )
    set_ix_array_values!(table, x.body, T = Float64)
    for (k, v) in pairs(table)
        if k == "FormationVolumeFactor"
            if x.value == "UndersaturatedGasTable"
                u = :gas_formation_volume_factor
            else
                u = :liquid_formation_volume_factor
            end
        else
            u = get_unit_type_ix_keyword(unit_systems, k)
        end
        if v isa Number
            table[k] = swap_unit_system(v, unit_systems, u)
        else
            swap_unit_system!(v, unit_systems, u)
        end
    end
    return out
end

function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Val{:WaterCompressibilities})
    kw = x.keyword
    @assert kw == "WaterCompressibilities"
    table = Dict{String, Any}()
    set_ix_array_values!(table, x.value, T = Float64)
    for (k, v) in pairs(table)
        if k == "FormationVolumeFactor"
            u = :liquid_formation_volume_factor
        else
            u = get_unit_type_ix_keyword(unit_systems, k)
        end
        if v isa Number
            table[k] = swap_unit_system(v, unit_systems, u)
        else
            swap_unit_system!(v, unit_systems, u)
        end
    end
    return table
end

function convert_ix_record(x::IXSimulationRecord, unit_systems, meta, ::Val{:PhasesPresent})
    return map(String, x.arg)
end
