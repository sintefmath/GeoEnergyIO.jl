function convert_ix_record(x, unit_systems, meta, ::Val{:SaturationFunction})
    to_convert = []
    out = Dict{String, Any}()
    for rec in x.body
        if rec isa IXEqualRecord
            out[rec.keyword] = rec.value
        else
            rec::IXStandardRecord
            kw = rec.keyword
            if !haskey(out, kw)
                out[kw] = Dict{String, Any}()
            end
            group = rec.value
            if !haskey(out[kw], group)
                out[kw][group] = Dict{String, Any}()
            end
            set_ix_array_values!(out[kw][group], rec.body, T = Float64)
            push!(to_convert, (kw, group))
        end
    end
    for (kw, group) in to_convert
        convert_dict_entries!(out[kw][group], unit_systems)
    end
    return out
end
