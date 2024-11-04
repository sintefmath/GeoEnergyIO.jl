function finish_current_section!(data, units, cfg, outer_data, ::Val{:SOLUTION})
    
end

# Utilities

function get_cartdims(outer_data)
    g = get_section(outer_data, :GRID, set_current = false)
    @assert haskey(g, "cartDims") "Cannot access cartDims, has not been set."
    return g["cartDims"]
end

function get_boxdims(outer_data)
    gdata = get_section(outer_data, :GRID, set_current = false)
    box = gdata["CURRENT_BOX"]
    dim = @. box.upper - box.lower + 1
    return dim
end

function get_box_indices(outer_data)
    gdata = get_section(outer_data, :GRID, set_current = false)
    box = gdata["CURRENT_BOX"]
    l = box.lower
    u = box.upper
    return (l[1]:u[1], l[2]:u[2], l[3]:u[3])
end

function get_box_indices(outer_data, il, iu, jl, ju, kl, ku)
    return (il:iu, jl:ju, kl:ku)
end

function set_cartdims!(outer_data, dim)
    @assert length(dim) == 3
    g = get_section(outer_data, :GRID, set_current = false)
    dim = tuple(dim...)
    gdata = get_section(outer_data, :GRID, set_current = false)
    gdata["cartDims"] = dim
    reset_current_box!(outer_data)
end

function reset_current_box!(outer_data)
    gdata = get_section(outer_data, :GRID, set_current = false)
    gdata["CURRENT_BOX"] = (lower = (1, 1, 1), upper = gdata["cartDims"])
end

# Keywords follow

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:SGAS})
    data["SGAS"] = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:SWAT})
    data["SWAT"] = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:TEMPI})
    T_i = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
    swap_unit_system!(T_i, units, :relative_temperature)
    data["TEMPI"] = T_i
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:DATUM})
    rec = read_record(f)
    l = parse_defaulted_line(rec, [NaN])
    swap_unit_system!(l, units, :length)
    data["DATUM"] = only(l)
end

function parse_mole_fractions!(f, outer_data)
    d = outer_data["GRID"]["cartDims"]
    nc = compositional_number_of_components(outer_data)
    return parse_grid_vector(f, (d[1], d[2], d[3], nc), Float64)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ZMF})
    data["ZMF"] = parse_mole_fractions!(f, outer_data)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:XMF})
    data["XMF"] = parse_mole_fractions!(f, outer_data)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:YMF})
    data["YMF"] = parse_mole_fractions!(f, outer_data)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PRESSURE})
    p = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
    swap_unit_system!(p, units, :pressure)
    data["PRESSURE"] = p
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Union{Val{:RTEMP}, Val{:RTEMPA}})
    nreg = number_of_tables(outer_data, :eosnum)
    out = Float64[]
    for i in 1:nreg
        rec = read_record(f)
        result = parse_defaulted_line(rec, [NaN])
        swap_unit_system!(result, units, :relative_temperature)
        push!(out, only(result))
    end
    data["RTEMP"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:RS})
    rs = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
    swap_unit_system!(rs, units, :u_rs)
    data["RS"] = rs
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:RV})
    rs = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
    swap_unit_system!(rs, units, :u_rv)
    data["RV"] = rs
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ACTNUM})
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, :ACTNUM, T = Bool)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:RSVD})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    for i = 1:n
        rs = parse_deck_matrix(f)
        swap_unit_system_axes!(rs, units, (:length, :u_rs))
        push!(out, rs)
    end
    data["RSVD"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PBVD})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    for i = 1:n
        rs = parse_deck_matrix(f)
        swap_unit_system_axes!(rs, units, (:length, :pressure))
        push!(out, rs)
    end
    data["PBVD"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ZMFVD})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    ncomp = compositional_number_of_components(outer_data)
    for i = 1:n
        zmfvd = parse_deck_vector(f)
        zmfvd = collect(reshape(zmfvd, ncomp+1, :)')
        for j in 1:size(zmfvd, 1)
            zmfvd[j, 1] = swap_unit_system(zmfvd[j, 1], units, :length)
        end
        push!(out, zmfvd)
    end
    data["ZMFVD"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:COMPVD})
    parser_message(cfg, outer_data, "COMPVD", PARSER_JUTULDARCY_MISSING_SUPPORT)
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    ncomp = compositional_number_of_components(outer_data)
    for i = 1:n
        compvd = parse_deck_vector(f)
        compvd = collect(reshape(compvd, ncomp+3, :)')
        for j in 1:size(compvd, 1)
            compvd[j, 1] = swap_unit_system(compvd[j, 1], units, :length)
            compvd[j, end] = swap_unit_system(compvd[j, end], units, :pressure)
        end
        push!(out, compvd)
    end
    data["COMPVD"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Union{Val{:TEMPVD}, Val{:RTEMPVD}})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    for i = 1:n
        tvd = parse_deck_matrix(f)
        swap_unit_system_axes!(tvd, units, (:length, :relative_temperature))
        push!(out, tvd)
    end
    data["RTEMPVD"] = out
end


function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:RVVD})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    for i = 1:n
        rs = parse_deck_matrix(f)
        swap_unit_system_axes!(rs, units, (:length, :u_rv))
        push!(out, rs)
    end
    data["RVVD"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:EQUIL})
    n = number_of_tables(outer_data, :eqlnum)
    def = [0.0, NaN, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 1, 0]
    eunits = (:length, :pressure, :length, :pressure, :length, :pressure, :id, :id, :id, :id, :id)
    out = []
    for i = 1:n
        rec = read_record(f)
        result = parse_defaulted_line(rec, def)
        swap_unit_system_axes!(result, units, eunits)
        push!(out, result)
    end
    data["EQUIL"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:FIELDSEP})
    u_type = deck_unit_system_label(units.from)
    if u_type == :field
        temp = 60.0
    else
        temp = 15.56
    end
    # TODO: Can be improved.
    p = si_unit(:atm)

    n = number_of_tables(outer_data, :eqlnum)
    def = [1, temp, p, 0, 0, 0, 0, 1, NaN, NaN]
    eunits = (:id, :relative_temperature, :pressure, :id, :id, :id, :id, :id, :relative_temperature, :pressure)
    out = []
    while true
        rec = read_record(f)
        if length(rec) == 0
            break
        end
        result = parse_defaulted_line(rec, def)
        swap_unit_system_axes!(result, units, eunits)
        push!(out, result)
    end
    data["FIELDSEP"] = out
end


function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:AQUCHWAT})
    n = aquifer_dimensions(outer_data, :NANAQU)
    def_and_u = [
        (1, :id),
        (NaN, :length),
        ("PRESSURE", :id),
        (0.0, :pressure),
        (0.0, :aquifer_transmissibility),
        (1, :id),
        (0.0, :concentration),
        (NaN, :pressure),
        (NaN, :pressure),
        ("NO", :id),
        (-Inf, :liquid_rate_surface),
        (Inf, :liquid_rate_surface),
        ("NO", :id),
        (0, :id),
        (NaN, :relative_temperature),
    ]
    def = map(first, def_and_u)
    eunits = map(last, def_and_u)
    out = []
    for i = 1:n
        rec = read_record(f)
        result = parse_defaulted_line(rec, def)
        bc_type = result[3]
        if bc_type == "PRESSURE"
            u = :pressure
        else
            @assert bc_type == "HEAD"
            u = :length
            parser_message(cfg, outer_data, AQUCHWAT, "AQUCHWAT: HEAD option is not fully supported. This option is not supported in JutulDarcy solvers.")
        end
        for j in [4, 8, 9]
            eunits[j] = u
        end
        swap_unit_system_axes!(result, units, eunits)
        push!(out, result)
    end
    data["AQUCHWAT"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:AQUANCON})
    def_and_u = [
        (1, :id), # Aquifer no
        (1, :id), # I start
        (1, :id), # I stop
        (1, :id), # J start
        (1, :id), # J stop
        (1, :id), # K start
        (1, :id), # K stop
        ("Defaulted", :id), # Where does it connect?
        (NaN, :area), # surface area to aquifer
        (1.0, :id), # Magic multiplier to flow rate
        ("NO", :id) # Allow interior aquifer connections
    ]
    defaults = map(first, def_and_u)
    utypes = map(last, def_and_u)
    out = []
    while true
        rec = read_record(f)
        if length(rec) == 0
            break
        end
        l = parse_defaulted_line(rec, defaults)
        swap_unit_system_axes!(l, units, utypes)
        push!(out, l)
    end
    data["AQUANCON"] = out
end
