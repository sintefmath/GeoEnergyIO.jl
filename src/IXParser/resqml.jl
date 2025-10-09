
function search_xml_nodes(x, search_tag::String; out = :all)
    for child in children(x)
        if tag(child) == search_tag
            if out == :all
                v = child
            elseif out == :children
                v = children(child)
            else
                error("Unknown out type $out")
            end
            return v
        end
        val = search_xml_nodes(child, search_tag; out = out)
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
    x = x |> only |> value
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

function convert_resqml_props(r, unit_systems = missing; verbose = false, strict = false)
    (haskey(r, :epc) && haskey(r, :h5)) || error("RESQML record must have both :epc and :h5 fields.")
    if haskey(r.epc, "namespace_resqml20")
        namespace_resqml = r.epc["namespace_resqml20"]
    else
        # Bare format?
        namespace_resqml = r.epc
    end
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
        if is_continuous
            read_obj, out["unit"] = convert_resqml_units(read_obj, out["unit"], unit_systems; throw = strict)
        else
            # Assume that units only apply for continuous props
            @assert ismissing(out["unit"])
        end
    else
        @warn "Expected only one dataset in /RESQML/$uuid_obj, got $(keys(read_obj)). Returning all values. No unit conversion will be done."
    end
    out["values"] = read_obj
    return out
end

function convert_resqml_units(data, unit, ::Missing)
    return data
end

function convert_resqml_units(data, unit, unit_systems; throw = true)
    sys = unit_systems.to
    unit = lowercase(unit)
    if unit == "md"
        v = si_unit(:milli)*si_unit(:darcy)/sys.permeability
    elseif unit == "euc" || unit == "m3/m3"
        v = missing
    else
        msg = "Unit conversion for RESQML unit $unit not implemented."
        if throw
            error(msg)
        else
            @warn msg
            v = missing
        end
    end
    if ismissing(v)
        data = map(Float64, data)
        u = unit
    else
        l = GeoEnergyIO.InputParser.deck_unit_system_label(sys)
        data = resqml_mapconvert(data, v)
        u = "$unit (converted to $l)"
    end
    return (data, u)
end

function resqml_mapconvert(data, v)
    return map(x -> Float64(x)*v, data)
end

