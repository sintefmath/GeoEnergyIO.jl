function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:ViscosityTemperatureTable})
    tabname = x.value
    out = Dict{String, Any}()
    out[tabname] = Dict{String, Any}()
    if length(x.body) == 1
        xb = only(x.body)
        xb::IXEqualRecord
        out[tabname][xb.keyword] = String(xb.value)
    else
        out[tabname]["table"] = parse_and_convert_numerical_table(x, unit_systems, x.keyword)
    end
    return out
end

function merge_records!(a, b, ::Val{:ViscosityTemperatureTable})
    keysa = keys(a)
    keysb = keys(b)
    out = Dict{String, Any}()
    for k in intersect(keysa, keysb)
        out[k] = merge(a[k], b[k])
    end
    for ka in setdiff(keysa, keysb)
        out[ka] = a[ka]
    end
    for kb in setdiff(keysb, keysa)
        out[kb] = b[kb]
    end
    return out
end
