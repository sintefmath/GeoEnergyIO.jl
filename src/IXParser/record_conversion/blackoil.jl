function convert_ix_record(x::IXEqualRecord, unit_systems, unhandled::AbstractDict, ::Union{Val{:GasSurfaceDensity}, Val{:OilSurfaceDensity}, Val{:WaterSurfaceDensity}})
    return swap_unit_system(x.value, unit_systems, :density)
end

function convert_ix_record(x::IXStandardRecord, unit_systems, unhandled::AbstractDict, ::Val{:DeadOilTable})
    kw = x.keyword
    @assert kw == "DeadOilTable"
    table = Dict{String, Any}()
    out = Dict{String, Any}(
        "name" => x.value,
        "table" => table,
    )
    set_ix_array_values!(table, x.body, T = Float64)
    upairs = unit_systems.ix_dict
    for (k, v) in pairs(table)
        if k == "FormationVolumeFactor"
            if x.value == "UndersaturatedGasTable"
                u = :gas_formation_volume_factor
            else
                u = :liquid_formation_volume_factor
            end
        else
            u =  upairs[k]
        end
        swap_unit_system!(v, unit_systems, u)
    end
    return out
end

