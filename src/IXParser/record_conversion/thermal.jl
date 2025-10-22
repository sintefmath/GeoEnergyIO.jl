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
    error("Merging of ViscosityTemperatureTable records is not supported.")
end
