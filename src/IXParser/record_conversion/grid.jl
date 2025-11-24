function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:StructuredInfo})
    I = 0
    J = 0
    K = 0
    first_cell_id = 1
    uuid = missing
    for rec in x.body
        if rec isa IXEqualRecord
            if rec.keyword == "NumberCellsInI"
                I = rec.value
            elseif rec.keyword == "NumberCellsInJ"
                J = rec.value
            elseif rec.keyword == "NumberCellsInK"
                K = rec.value
            elseif rec.keyword == "UUID"
                uuid = rec.value
            elseif rec.keyword == "FirstCellId"
                first_cell_id = rec.value
            else
                @info "Unhandled IX StructuredInfo field $(rec.keyword)"
            end
        else
            error("Expected IXEqualRecord in StructuredInfo record body, got $(typeof(rec))")
        end
    end
    return Dict{String, Any}(
        "name" => x.value,
        "I" => I,
        "J" => J,
        "K" => K,
        "FirstCellId" => first_cell_id,
        "UUID" => uuid,
    )
end

function convert_ix_record(x::IXEqualRecord, unit_systems, meta, ::Val{:Faults})
    names = String[]
    for rec in x.value
        v = rec.value
        rec.keyword == "FaultNames" || error("Expected FaultNames record in Faults record body, got $(rec.keyword)")
        if v isa String
            append!(names, v)
        end
    end
    return names
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:FaultDefinition})
    name = x.value
    data = Dict{String, Any}()
    for rec in x.body
        if !haskey(data, rec.keyword)
            data[rec.keyword] = Dict{String, Any}()
        end
        if rec.keyword == "FaultIJKBoxDefinition"
            d = Dict{String, Any}()
            set_ix_array_values!(d, rec.body)
            data[rec.keyword][rec.value] = d
        else
            data[rec.keyword] = rec
        end
    end
    return (name = name, data = data)
end

function convert_ix_record(x, unit_systems, meta, ::Val{:RockRegionMapping})
    return convert_region_mapping(x)
end

function convert_ix_record(x, unit_systems, meta, ::Val{:FluidRegionMapping})
    return convert_region_mapping(x)
end

function convert_ix_record(x, unit_systems, meta, ::Val{:EquilibriumRegionMapping})
    return convert_region_mapping(x)
end

function convert_region_mapping(x::IXEqualRecord)
    tab = Dict{String, Any}()
    set_ix_array_values!(tab, x)
    out = Dict(
        "name" => x.value,
        "table" => tab,
    )
    return out
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:ConnectionSet})
    out = Dict{String, Any}(
        "name" => x.value
    )
    if x.body[1] isa IXEqualRecord
        for subrec in x.body
            val = subrec.value
            if val isa IXKeyword
                val = String(val)
            end
            out[subrec.keyword] = val
        end
    else
        table = Dict{String, Any}()
        set_ix_array_values!(table, x.body)
        for (k, v) in pairs(table)
            u = get_unit_type_ix_keyword(unit_systems, k; throw = false)
            if u != :id
                if eltype(v)<:Integer
                    v = Float64.(v)
                    table[k] = v
                end
                swap_unit_system!(v, unit_systems, u)
            end
        end
        out["table"] = table
    end
    return out
end

function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:StraightPillarGrid})
    bdy = x.body
    function to_vec(x, T = missing)
        xv = x.value
        if ismissing(T)
            out = [i for i in filter(y -> y isa Number, xv)]
        else
            out = [convert(T, i) for i in filter(y -> y isa Number, xv)]
        end
        return out
    end

    function to_vec(x::Nothing, T = missing)
        return nothing
    end

    function get_entry(k, u, T = missing)
        rec = find_records(bdy, k, once = true)
        if isnothing(rec)
            out = missing
        else
            out = to_vec(rec, T)
            T_out = eltype(out)
            if !isconcretetype(T_out)
                @warn "Non-concrete type detected for $k: $T_out"
            end
            swap_unit_system!(out, unit_systems, u)
        end
        return out
    end

    dx = get_entry("DeltaX", :length, Float64)
    dy = get_entry("DeltaY", :length, Float64)
    dz = get_entry("DeltaZ", :length, Float64)
    tops = get_entry("PillarTops", :length, Float64)

    out_props = Dict{String, Any}()
    for (ptype, is_int) in [("CellIntegerProperty", true), ("CellDoubleProperty", false)]
        props = find_records(bdy, ptype, once = false)
        for p in props
            pname = p.value
            @assert length(p.body) == 1
            if is_int
                T = Int
            else
                # Probably Float64 but who knows, some datasets have Ints here
                # as well.
                T = missing
            end
            v = to_vec(p.body[1], T)
            if !is_int && !(eltype(v)<:Integer)
                u = get_unit_type_ix_keyword(unit_systems, pname)
                swap_unit_system!(v, unit_systems, u)
            end
            out_props[pname] = v
        end
    end
    return Dict(
        "name" => x.value,
        "DeltaX" => dx,
        "DeltaY" => dy,
        "DeltaZ" => dz,
        "PillarTops" => tops,
        "CellDoubleProperty" => out_props,
    )
end
