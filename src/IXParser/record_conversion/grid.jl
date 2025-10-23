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
        rec.keyword == "FaultNames" || error("Expected FaultNames record in Faults record body, got $(rec.keyword)")
        append!(names, rec.value)
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

function convert_ix_record(x::IXStandardRecord, unit_systems, meta, ::Val{:StraightPillarGrid})
    bdy = x.body
    function to_vec(x)
        [i for i in filter(y -> y isa Number, x.value)]
    end

    function get_entry(k, u)
        rec = find_records(bdy, k, once = true)
        if isnothing(rec)
            out = missing
        else
            out = to_vec(rec)
            swap_unit_system!(out, unit_systems, u)
        end
        return out
    end
    to_vec(x::Nothing) = nothing

    dx = get_entry("DeltaX", :length)
    dy = get_entry("DeltaY", :length)
    dz = get_entry("DeltaZ", :length)
    tops = get_entry("PillarTops", :length)

    props = find_records(bdy, "CellDoubleProperty", once = false)
    out_props = Dict{String, Any}()
    for p in props
        pname = p.value
        @assert length(p.body) == 1
        v = to_vec(p.body[1])
        if pname == "POROSITY" || pname == "NET_TO_GROSS_RATIO"
            # Already identity
            u = :id
        elseif startswith(pname, "PERM")
            u = :permeability
        elseif pname == "PORE_VOLUME"
            u = :volume
        else
            println("Unhandled property $pname in StraightPillarGrid, assuming unitless.")
            u = :id
        end
        swap_unit_system!(v, unit_systems, u)
        out_props[pname] = v
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
