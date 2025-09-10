function convert_ix_record(x, unit_systems, unhandled::AbstractDict, ::Val{:SaturationFunction})
    return parse_and_convert_numerical_table(x, unit_systems, "SaturationFunction")
end

function parse_and_convert_numerical_table(x::IXStandardRecord, unit_systems, k = missing)
    if !ismissing(k)
        @assert x.keyword == k
    end
    table = Dict{String, Any}()
    out = Dict{String, Any}(
        "name" => x.value,
        "table" => table,
    )
    set_ix_array_values!(table, x.body, T = Float64)
    upairs = unit_systems.ix_dict
    for (k, v) in pairs(table)
        if v isa AbstractString
            continue
        end
        u = upairs[k]
        if v isa Number
            table[k] = swap_unit_system(v, unit_systems, u)
        else
            swap_unit_system!(v, unit_systems, u)
        end
    end
    return out
end