
function search_xml_nodes(x, tag::String; out = :all)
    for child in children(x)
        # @info "??" i XML.tag(i) XML.attributes(i) children(i)
        if XML.tag(child) == tag
            if out == :all
                v = child
            elseif out == :children
                v = children(child)
            else
                error("Unknown out type $out")
            end
            return v
        end
        val = search_xml_nodes(child, tag; out = out)
        if !ismissing(val)
            return val
        end
    end
    return missing
end

function unwrap_single(x::Missing, T = missing)
    return missing
end

function unwrap_single(x, T = missing)
    x = x |> only |> XML.value
    if !ismissing(T)
        x = convert(T, x)
    else
        x = x
    end
    return x
end

function find_string_by_tag(prop, tag::String)
    return unwrap_single(search_xml_nodes(prop, tag, out = :children), String)
end

function convert_resqml_props(r)
    (haskey(r, :epc) && haskey(r, :h5)) || error("RESQML record must have both :epc and :h5 fields.")
    namespace_resqml = r.epc["namespace_resqml20"]
    prop = missing
    uuid_obj = missing
    is_discrete = is_continuous = false
    for (k, v) in pairs(namespace_resqml)
        is_discrete = startswith(k, "obj_DiscreteProperty")
        is_continuous = startswith(k, "obj_ContinuousProperty")
        if is_discrete || is_continuous
            uuid_obj = split(k, "_")[end] |> splitext |> first
            prop = v
            break
        end
    end
    # @info "??" is_discrete is_continuous prop # XML.attributes(prop[1]) children(prop)

    uuid = find_string_by_tag(prop, "eml20:UUID")

    out = Dict{String, Any}()
    out["is_discrete"] = is_discrete
    out["is_continuous"] = is_continuous
    out["UUID"] = uuid
    out["UUID_obj"] = uuid_obj
    out["kind"] = find_string_by_tag(prop, "resqml20:Kind")
    out["title"] = find_string_by_tag(prop, "eml20:Title")
    out["unit"] = find_string_by_tag(prop, "resqml20:UOM")
    # Are values always patch0?
    read_obj = HDF5.read(r.h5["/RESQML/$uuid_obj"])
    if length(keys(read_obj)) == 1
        read_obj = only(values(read_obj))
    end
    out["values"] = read_obj
    return out
end
