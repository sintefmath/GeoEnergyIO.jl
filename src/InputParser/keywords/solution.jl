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
    if haskey(gdata, "CURRENT_BOX")
        box = gdata["CURRENT_BOX"]
        dim = @. box.upper - box.lower + 1
    else
        dim = get_cartdims(outer_data)
    end
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

@keyword :SOLUTION :SGAS RecordKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:SGAS})
    data["SGAS"] = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
end

@keyword :SOLUTION :SWAT RecordKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:SWAT})
    data["SWAT"] = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
end

@keyword :SOLUTION :TEMPI RecordKeyword units = :relative_temperature

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:TEMPI})
    T_i = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
    swap_unit_system!(T_i, units, keyword_units(definition))
    data["TEMPI"] = T_i
end

@keyword :SOLUTION :DATUM RecordKeyword defaults = [NaN] units = :length

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:DATUM})
    rec = read_record(f)
    l = parse_defaulted_line(rec, keyword_defaults(definition))
    swap_unit_system!(l, units, keyword_units(definition))
    data["DATUM"] = only(l)
end

function parse_mole_fractions!(f, outer_data)
    d = outer_data["GRID"]["cartDims"]
    nc = compositional_number_of_components(outer_data)
    return parse_grid_vector(f, (d[1], d[2], d[3], nc), Float64)
end

@keyword :SOLUTION :ZMF RecordKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:ZMF})
    data["ZMF"] = parse_mole_fractions!(f, outer_data)
end

@keyword :SOLUTION :XMF RecordKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:XMF})
    data["XMF"] = parse_mole_fractions!(f, outer_data)
end

@keyword :SOLUTION :YMF RecordKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:YMF})
    data["YMF"] = parse_mole_fractions!(f, outer_data)
end

@keyword :SOLUTION :PRESSURE RecordKeyword units = :pressure

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:PRESSURE})
    p = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
    swap_unit_system!(p, units, keyword_units(definition))
    data["PRESSURE"] = p
end

@keyword :SOLUTION (:RTEMP, :RTEMPA) RecordsKeyword defaults = [NaN] units = :relative_temperature records = :regional

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordsKeyword{:RTEMP}, RecordsKeyword{:RTEMPA}})
    nreg = number_of_tables(outer_data, :eosnum)
    out = Float64[]
    for i in 1:nreg
        rec = read_record(f)
        result = parse_defaulted_line(rec, keyword_defaults(definition))
        swap_unit_system!(result, units, keyword_units(definition))
        push!(out, only(result))
    end
    data["RTEMP"] = out
end

@keyword :SOLUTION :RS RecordKeyword units = :u_rs

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:RS})
    rs = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
    swap_unit_system!(rs, units, keyword_units(definition))
    data["RS"] = rs
end

@keyword :SOLUTION :RV RecordKeyword units = :u_rv

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:RV})
    rs = parse_grid_vector(f, outer_data["GRID"]["cartDims"], Float64)
    swap_unit_system!(rs, units, keyword_units(definition))
    data["RV"] = rs
end

@keyword :GRID :ACTNUM GridArrayKeyword default = false

@keyword :SOLUTION :RSVD RecordsKeyword units = (:length, :u_rs) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:RSVD})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    for i = 1:n
        rs = parse_deck_matrix(f)
        swap_unit_system_axes!(rs, units, keyword_units(definition))
        push!(out, rs)
    end
    data["RSVD"] = out
end

@keyword :SOLUTION :PBVD RecordsKeyword units = (:length, :pressure) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PBVD})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    for i = 1:n
        rs = parse_deck_matrix(f)
        swap_unit_system_axes!(rs, units, keyword_units(definition))
        push!(out, rs)
    end
    data["PBVD"] = out
end

@keyword :SOLUTION :ZMFVD RecordsKeyword units = :length records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:ZMFVD})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    ncomp = compositional_number_of_components(outer_data)
    for i = 1:n
        zmfvd = parse_deck_vector(f)
        zmfvd = collect(reshape(zmfvd, ncomp+1, :)')
        for j in 1:size(zmfvd, 1)
            zmfvd[j, 1] = swap_unit_system(zmfvd[j, 1], units, keyword_units(definition))
        end
        push!(out, zmfvd)
    end
    data["ZMFVD"] = out
end

@keyword :SOLUTION :COMPVD RecordsKeyword units = (:length, :pressure) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:COMPVD})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    ncomp = compositional_number_of_components(outer_data)
    for i = 1:n
        compvd = parse_deck_vector(f)
        compvd = collect(reshape(compvd, ncomp+3, :)')
        for j in 1:size(compvd, 1)
            compvd[j, 1] = swap_unit_system(compvd[j, 1], units, first(keyword_units(definition)))
            compvd[j, end] = swap_unit_system(compvd[j, end], units, last(keyword_units(definition)))
        end
        push!(out, compvd)
    end
    data["COMPVD"] = out
end

@keyword :SOLUTION (:TEMPVD, :RTEMPVD) RecordsKeyword units = (:length, :relative_temperature) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordsKeyword{:TEMPVD}, RecordsKeyword{:RTEMPVD}})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    for i = 1:n
        tvd = parse_deck_matrix(f)
        swap_unit_system_axes!(tvd, units, keyword_units(definition))
        push!(out, tvd)
    end
    data["RTEMPVD"] = out
end

@keyword :SOLUTION :RVVD RecordsKeyword units = (:length, :u_rv) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:RVVD})
    n = number_of_tables(outer_data, :eqlnum)
    out = []
    for i = 1:n
        rs = parse_deck_matrix(f)
        swap_unit_system_axes!(rs, units, keyword_units(definition))
        push!(out, rs)
    end
    data["RVVD"] = out
end

@keyword(:SOLUTION, :EQUIL, RecordsKeyword,
    defaults = [0.0, NaN, 0.0, 0.0, 0.0, 0.0, 0, 0, 0, 1, 0],
    units = (:length, :pressure, :length, :pressure, :length, :pressure, :id, :id, :id, :id, :id),
    records = :regional,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:EQUIL})
    n = number_of_tables(outer_data, :eqlnum)
    def = keyword_defaults(definition)
    eunits = keyword_units(definition)
    out = []
    for i = 1:n
        rec = read_record(f)
        result = parse_defaulted_line(rec, def)
        swap_unit_system_axes!(result, units, eunits)
        push!(out, result)
    end
    data["EQUIL"] = out
end

@keyword(:SOLUTION, :FIELDSEP, RecordsKeyword,
    units = (:id, :relative_temperature, :pressure, :id, :id, :id, :id, :id, :relative_temperature, :pressure),
    defaults = [1, 15.56, si_unit(:atm), 0, 0, 0, 0, 1, NaN, NaN],
)

function keyword_defaults(def::RecordsKeyword{:FIELDSEP}, outer_data, units)
    defaults = copy(keyword_defaults(def))
    if deck_unit_system_label(units.from) == :field
        defaults[2] = 60.0
    end
    return defaults
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:FIELDSEP})
    def = keyword_defaults(definition, outer_data, units)
    eunits = keyword_units(definition)
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

@keyword :SOLUTION :AQUCHWAT RecordsKeyword fields = [
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
] records = :regional

function set_aquifer_condition_units!(units, ::RecordsKeyword{:AQUCHWAT}, condition)
    unit = condition == "PRESSURE" ? :pressure : :length
    for j in (4, 8, 9)
        units[j] = unit
    end
    return units
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:AQUCHWAT})
    n = aquifer_dimensions(outer_data, :NANAQU)
    def = keyword_defaults(definition)
    eunits = copy(keyword_units(definition))
    out = []
    for i = 1:n
        rec = read_record(f)
        result = parse_defaulted_line(rec, def)
        bc_type = result[3]
        if bc_type != "PRESSURE"
            @assert bc_type == "HEAD"
            parser_message(cfg, outer_data, AQUCHWAT, "AQUCHWAT: HEAD option is not fully supported. This option is not supported in JutulDarcy solvers.")
        end
        set_aquifer_condition_units!(eunits, definition, bc_type)
        swap_unit_system_axes!(result, units, eunits)
        push!(out, result)
    end
    data["AQUCHWAT"] = out
end

@keyword :SOLUTION :AQUANCON RecordsKeyword fields = [
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

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:AQUANCON})
    defaults = keyword_defaults(definition)
    utypes = keyword_units(definition)
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
