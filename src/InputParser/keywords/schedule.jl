@keyword :SCHEDULE (:TUNINGDP, :GCONTOL, :RPTSCHED) RecordKeyword support = :ignored

function finish_current_section!(data, units, cfg, outer_data, ::Val{:SCHEDULE})
    compord = outer_data["SCHEDULE"]["COMPORD"]
    for k in keys(get_wells(outer_data))
        if !haskey(compord, k)
            compord[k] = "TRACK"
        end
    end
end

function welspecs_to_well(ws)
    name = ws[1]::AbstractString
    # TODO: Parse more fields.
    w = (
        group = ws[2],
        head = (ws[3], ws[4]),
        ref_depth = ws[5],
        preferred_phase = ws[6],
        drainage_radius = ws[7]
    )
    return (name, w)
end

function get_wells(outer_data)
    return outer_data["SCHEDULE"]["WELSPECS"]
end

function get_well(outer_data, name)
    return get_wells(outer_data)[name]
end

@keyword(:SCHEDULE, :WELSPECS, RecordsKeyword,
    defaults = [
        "Default", "Default", -1, -1, NaN, "Default", 0.0, "STD", "SHUT", "YES", 0, "SEG", 0, "Default",
        "Default", "STD", 0,
    ],
    units = (:id, :id, :id, :id, :length, :id, :length, :id, :id, :id, :id, :id, :id, :id, :id, :id, :id),
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WELSPECS})
    defaults = keyword_defaults(definition)
    utypes = keyword_units(definition)
    wspecs = parse_defaulted_group(f, defaults)
    push_and_create!(data, "WELSPECS", wspecs)
    wells = get_wells(outer_data)
    for ws in wspecs
        swap_unit_system_axes!(ws, units, utypes)
        name, well = welspecs_to_well(ws)
        # @assert !haskey(wells, name) "Well $name is already defined."
        wells[name] = well
    end
end

@keyword :SCHEDULE :COMPORD RecordsKeyword defaults = ["Default", "TRACK"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:COMPORD})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    compord = parse_defaulted_group_well(f, defaults, wells, 1)
    out = outer_data["SCHEDULE"]["COMPORD"]
    for co in compord
        well, val = co
        out[well] = val
    end
end

@keyword(:SCHEDULE, :COMPDAT, RecordsKeyword,
    defaults = ["Default", -1, -1, -1, -1, "OPEN", -1, NaN, NaN, NaN, 0.0, -1.0, "Z", -1.0],
    units = (:id, :id, :id, :id, :id, :id, :id, :transmissibility, :length, :Kh, :id, :time_over_volume, :id, :length),
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:COMPDAT})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    compdat = parse_defaulted_group_well(f, defaults, wells, 1)
    # Unit conversion
    utypes = keyword_units(definition)
    for cd in compdat
        # A zero connection factor requests a calculated well index, just as a
        # defaulted field does. It does not close the connection.
        if cd[8] == 0.0
            cd[8] = NaN
        end
        swap_unit_system_axes!(cd, units, utypes)
    end
    push_and_create!(data, "COMPDAT", compdat)
end

@keyword :SCHEDULE :WELOPEN RecordsKeyword defaults = ["Default", "OPEN", -1, -1, -1, -1, -1]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WELOPEN})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    welopen = parse_defaulted_group_well(f, defaults, wells, 1)
    push_and_create!(data, "WELOPEN", welopen)
end

@keyword :SCHEDULE (:WELLSHUT, :WELLOPEN) RecordsKeyword defaults = ["Default"]

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordsKeyword{:WELLSHUT}, RecordsKeyword{:WELLOPEN}})
    k = keyword_name(definition)
    # WELLSHUT is recommended to be replaced with WELOPEN. For simplicity we
    # convert WELLSHUT to the corresponding WELOPEN arguments.
    parser_message(cfg, outer_data, "$k", "Converting $k to equivialent WELOPEN inputs.", color = :green)
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    wellshut = parse_defaulted_group_well(f, defaults, wells, 1)
    welopen = []
    for w in wellshut
        if k == :WELLSHUT
            v = "SHUT"
        else
            v = "OPEN"
        end
        push!(welopen, [only(w), v, -1, -1, -1, -1, -1])
    end
    push_and_create!(data, "WELOPEN", welopen)
end

@keyword(:SCHEDULE, :WCONPROD, RecordsKeyword,
    defaults = [
        "Default", "OPEN", "Default", -1.0, -1.0,
        -1.0, -1.0, -1.0, -1.0, -1.0,
        0, 0.0, NaN, NaN, NaN,
        NaN, NaN, NaN, NaN, NaN
    ],
    units = (
        :id, :id, :id, :liquid_rate_surface, :liquid_rate_surface, :gas_rate_surface,
        :liquid_rate_surface, :liquid_rate_reservoir, :pressure, :id, :id, :id, :id, :id, :id, :id, :id, :id, :id, :id,
    ),
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WCONPROD})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    wconprod = parse_defaulted_group_well(f, defaults, wells, 1)
    for kw in wconprod
        for i in 4:10
            # Handle defaults
            if kw[i] < 0
                kw[i] = Inf
            end
        end
    end
    utypes = keyword_units(definition)
    for wp in wconprod
        swap_unit_system_axes!(wp, units, utypes)
    end
    push_and_create!(data, "WCONPROD", wconprod)
end

@keyword(:SCHEDULE, :GCONPROD, RecordsKeyword,
    defaults = Any[
        "Default", "NONE", Inf, Inf, Inf, Inf, "NONE", "YES",
        NaN, "", "NONE", "NONE", "NONE", Inf, NaN, NaN, NaN, NaN, NaN, NaN, "NONE",
    ],
    units = (
        :id, :id, :liquid_rate_surface, :liquid_rate_surface, :gas_rate_surface, :liquid_rate_surface,
        :id, :id, :id, :id, :id, :id, :id, :liquid_rate_reservoir, :id, :id, :id, :id, :id, :id, :id,
    ),
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:GCONPROD})
    defaults = keyword_defaults(definition)
    records = parse_defaulted_group(f, defaults; allow_wildcard = [false; fill(true, length(defaults) - 1)])
    utypes = keyword_units(definition)
    for rec in records
        swap_unit_system_axes!(rec, units, utypes)
    end
    push_and_create!(data, "GCONPROD", records)
end

@keyword(:SCHEDULE, :GCONINJE, RecordsKeyword,
    defaults = Any["Default", "Default", "NONE", Inf, Inf, NaN, NaN, "YES", 0.0, "", "", "", NaN],
    units = [:id, :id, :id, :id, :liquid_rate_reservoir, :id, :id, :id, :id, :id, :id, :id, :gas_rate_surface],
)

function keyword_units(def::RecordsKeyword{:GCONINJE}, record)
    result = copy(keyword_units(def))
    result[4] = record[2] == "GAS" ? :gas_rate_surface : :liquid_rate_surface
    return result
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:GCONINJE})
    defaults = keyword_defaults(definition)
    records = parse_defaulted_group(f, defaults; allow_wildcard = [false; fill(true, length(defaults) - 1)])
    for rec in records
        utypes = keyword_units(definition, rec)
        swap_unit_system_axes!(rec, units, utypes)
    end
    push_and_create!(data, "GCONINJE", records)
end

@keyword :SCHEDULE :WGRUPCON RecordsKeyword defaults = Any["Default", "YES", -1.0, "", 1.0] units = [:id, :id, :id, :id, :id]

function keyword_units(def::RecordsKeyword{:WGRUPCON}, record)
    result = copy(keyword_units(def))
    result[3] = record[4] == "GAS" ? :gas_rate_surface :
        record[4] == "RES" ? :liquid_rate_reservoir : :liquid_rate_surface
    return result
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WGRUPCON})
    # Guide-rate units depend on the selected phase; the scaling factor is dimensionless.
    records = parse_defaulted_group_well(f, keyword_defaults(definition), get_wells(outer_data))
    for rec in records
        if rec[4] in ("OIL", "WAT", "WATER", "LIQ", "GAS", "RES", "RAT")
            utypes = keyword_units(definition, rec)
            # Preserve the negative sentinel for a defaulted potential guide rate.
            if rec[3] >= 0
                swap_unit_system_axes!(rec, units, utypes)
            end
        end
    end
    push_and_create!(data, "WGRUPCON", records)
end

@keyword(:SCHEDULE, :WCONHIST, RecordsKeyword,
    defaults = ["Default", "OPEN", "Default", 0.0, 0.0, 0.0, 0, "Default", 0.0, 0.0, 0.0],
    units = (
        :id, :id, :id, :liquid_rate_surface, :liquid_rate_surface, :gas_rate_surface, :id, :id,
        :pressure, :pressure, :gas_rate_surface,
    ),
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WCONHIST})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    out = parse_defaulted_group_well(f, defaults, wells, 1)
    utypes = keyword_units(definition)
    for o in out
        swap_unit_system_axes!(o, units, utypes)
    end
    push_and_create!(data, "WCONHIST", out)
end

@keyword(:SCHEDULE, :WCONINJ, RecordsKeyword,
    defaults = ["Default", "Default", "OPEN", "Default", Inf, Inf, 0.0, "NONE", -1, Inf, 0.0, 0.0],
    units = [:id, :id, :id, :id, :id, :liquid_rate_surface, :id, :id, :pressure, :pressure, :id, :id],
)

function set_injection_units!(utypes, ::RecordsKeyword{:WCONINJ}, phase)
    if phase == "GAS"
        utypes[5] = :gas_rate_surface
        utypes[12] = :u_rv
    else
        utypes[5] = :liquid_rate_surface
        if phase == "OIL"
            utypes[12] = :u_rs
        end
    end
    return utypes
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WCONINJ})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    out = parse_defaulted_group_well(f, defaults, wells, 1)
    utypes = copy(keyword_units(definition))
    for o in out
        w = get_well(outer_data, o[1])
        set_injection_units!(utypes, definition, w.preferred_phase)
        swap_unit_system_axes!(o, units, utypes)
    end
    push_and_create!(data, "WCONINJ", out)
end

@keyword(:SCHEDULE, :WCONINJE, RecordsKeyword,
    defaults = ["Default", "Default", "OPEN", "Default", -1.0, -1.0, NaN, -1.0, 0, 0.0, 0.0, 0, 0, 0],
    units = [:id, :id, :id, :id, :id, :liquid_rate_reservoir, :pressure, :pressure, :id, :id, :id, :id, :id, :id],
)

function keyword_units(def::RecordsKeyword{:WCONINJE}, record)
    utypes = copy(keyword_units(def))
    if record[2] == "GAS"
        utypes[5] = :gas_rate_surface
        utypes[10] = :u_rv
    else
        utypes[5] = :liquid_rate_surface
        if record[2] == "OIL"
            utypes[12] = :u_rs
        end
    end
    return utypes
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WCONINJE})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    out = parse_defaulted_group_well(f, defaults, wells, 1)
    for o in out
        for i in [5, 6, 8]
            if o[i] <= 0 && !(i == 5 && o[4] == "RATE" && o[i] == 0)
                o[i] = Inf
            end
        end
        utypes = keyword_units(definition, o)
        swap_unit_system_axes!(o, units, utypes)
    end
    push_and_create!(data, "WCONINJE", out)
end

@keyword(:SCHEDULE, :WCONINJH, RecordsKeyword,
    defaults = ["Default", "Default", "OPEN", 0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0, "RATE"],
    units = [:id, :id, :id, :id, :pressure, :pressure, :id, :u_rv, :id, :id, :id, :id],
)

function keyword_units(def::RecordsKeyword{:WCONINJH}, record)
    result = copy(keyword_units(def))
    result[4] = record[2] == "GAS" ? :gas_rate_surface : :liquid_rate_surface
    return result
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WCONINJH})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    out = parse_defaulted_group_well(f, defaults, wells, 1)
    for o in out
        utypes = keyword_units(definition, o)
        swap_unit_system_axes!(o, units, utypes)
    end
    push_and_create!(data, "WCONINJH", out)
end

@keyword :SCHEDULE (:WELLTARG, :WELTARG) RecordsKeyword defaults = ["Default", "ORAT", NaN]

function keyword_units(::Union{RecordsKeyword{:WELLTARG}, RecordsKeyword{:WELTARG}}, cname)
    u = missing
    if cname in ("LRAT", "ORAT", "WRAT", "RATE")
        # TODO: Check these. Could be some combinations of injector keywords
        # that would lead to wrong units here.
        u = :liquid_rate_surface
    elseif cname == "GRAT"
        u = :gas_rate_surface
    elseif cname == "BHP" || cname == "THP"
        u = :pressure
    end
    return u
end

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordsKeyword{:WELLTARG}, RecordsKeyword{:WELTARG}})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    out = parse_defaulted_group_well(f, defaults, wells, 1)
    for kline in out
        wname, cname, val = kline
        cname = uppercase(cname)
        u = keyword_units(definition, cname)
        if ismissing(u)
            parser_message(cfg, outer_data, "WELTARG", "Unit for $cname not known.")
        else
            val = swap_unit_system(val, units, u)
        end
        kline[3] = val
    end
    push_and_create!(data, "WELTARG", out)
end

@keyword(:SCHEDULE, :WPOLYMER, RecordsKeyword,
    defaults = ["Default", 0.0, 0.0, "Default", "Default"],
    units = (:id, :concentration, :concentration, :id, :id),
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WPOLYMER})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    wp = parse_defaulted_group_well(f, defaults, wells, 1)
    # Unit conversion
    utypes = keyword_units(definition)
    for w in wp
        swap_unit_system_axes!(w, units, utypes)
    end
    push_and_create!(data, "WPOLYMER", wp)
end

@keyword :SCHEDULE :WEFAC RecordsKeyword defaults = ["Default", 1.0, "YES"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WEFAC})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    parsed = parse_defaulted_group_well(f, defaults, wells, 1)
    push_and_create!(data, "WEFAC", parsed)
end

@keyword :SCHEDULE :WPIMULT RecordsKeyword defaults = ["Default", 1.0, -1, -1, -1, -1, -1, -1]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WPIMULT})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    parsed = parse_defaulted_group_well(f, defaults, wells, 1)
    push_and_create!(data, "WPIMULT", parsed)
end

@keyword :SCHEDULE :FBHPDEF RecordKeyword units = :pressure defaults = (1.01325e5, 6.895e8)

function keyword_defaults(definition::RecordKeyword{:FBHPDEF}, outer_data, units)
    input_system = DeckUnitSystem(current_unit_system(outer_data))
    pressure_unit = deck_unit(input_system, keyword_units(definition))
    return [convert_from_si(p, pressure_unit) for p in keyword_defaults(definition)]
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:FBHPDEF})
    rec = read_record(f)
    defaults = keyword_defaults(definition, outer_data, units)
    pressures = parse_defaulted_line(rec, defaults)
    swap_unit_system!(pressures, units, keyword_units(definition))
    data["FBHPDEF"] = pressures
end

function convert_date_kw(t)
    @assert length(t) == 4
    function get_month(s)
        s = uppercase(s)
        if s == "JAN"
            return 1
        elseif s == "FEB"
            return 2
        elseif s == "MAR"
            return 3
        elseif s == "APR"
            return 4
        elseif s == "MAY"
            return 5
        elseif s == "JUN"
            return 6
        elseif s == "JLY" || s == "JUL"
            return 7
        elseif s == "AUG"
            return 8
        elseif s == "SEP"
            return 9
        elseif s == "OCT"
            return 10
        elseif s == "NOV"
            return 11
        else
            s == "DEC" || s == "DES" || error("Did not understand month format $s")
            return 12
        end
    end
    yr = t[3]
    m = get_month(t[2])
    d = t[1]

    return parse(DateTime, "$yr-$d-$m $(t[4])", dateformat"y-d-m H:M:S")
end

@keyword :SCHEDULE :DATES RecordsKeyword defaults = [1, "JAN", 1970, "00:00:00"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:DATES})
    defaults = keyword_defaults(definition)
    dt = parse_defaulted_group(f, defaults)
    out = Vector{DateTime}()
    sizehint!(out, length(dt))
    for t in dt
        if length(t[end]) > 8
            # TODO: Fix dirty hack for skipping ms
            t[end] = t[end][1:8]
        end
        push!(out, convert_date_kw(t))
    end
    data["DATES"] = out
end

@keyword :SCHEDULE :TSTEP RecordKeyword units = :time

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:TSTEP})
    dt = parse_deck_vector(f)
    swap_unit_system!(dt, units, keyword_units(definition))
    data["TSTEP"] = dt
end

@keyword :SCHEDULE :TUNING RecordsKeyword records = 3 warning = PARSER_JUTULDARCY_PARTIAL_SUPPORT defaults = (
    timestep = [1.0, 365.0, 0.1, 0.15, 3.0, 0.3, 0.1, 1.25, 1e20, NaN],
    convergence = [0.1, 1e-3, 1e-7, 1e-4, 10.0, 1e-2, 1e-6, 1e-3, 1e-3, 0.025, NaN, 0.01, 1.0],
) units = (:time, :time, :time, :time, :id, :id, :id, :id, :id, :time)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:TUNING})
    defaults = keyword_defaults(definition)
    values = parse_defaulted_line(read_record(f), defaults.timestep)
    utypes = keyword_units(definition)
    swap_unit_system_axes!(values, units, utypes)
    convergence = parse_defaulted_line(read_record(f), defaults.convergence)
    data["TUNING"] = [values, convergence]
    skip_records(f, keyword_layout(definition) - 2)
    parser_message(cfg, outer_data, "TUNING", PARSER_JUTULDARCY_PARTIAL_SUPPORT,
        "Only initial TSINIT, TSMAXZ, TSMINZ, TSFMAX, TSFMIN, TSFCNV, TRGCNV and TRGMBE settings are used by JutulDarcy.")
end

@keyword :SCHEDULE :WSEGITER RecordKeyword defaults = [20, 5, 0.3, 2.0, ] warning = PARSER_JUTULDARCY_MISSING_SUPPORT

@keyword :SCHEDULE :NUPCOL RecordKeyword defaults = [3]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:NUPCOL})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    data["NUPCOL"] = only(parse_defaulted_line(rec, tdims))
end

@keyword :SCHEDULE :WELLSTRE RecordsKeyword

function keyword_defaults(::RecordsKeyword{:WELLSTRE}, outer_data, units)
    n = compositional_number_of_components(outer_data)
    return ["DEFAULT"; zeros(max(1, n))]
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WELLSTRE})
    n = compositional_number_of_components(outer_data)
    defaults = keyword_defaults(definition, outer_data, units)
    rec = parse_defaulted_group(f, defaults)
    for r in rec
        sum = 0.0
        for i in 1:n
            sum += r[i+1]
        end
        @assert sum ≈ 1.0 "Compositions in well stream $(r[1]) defined by WELLSTRE must sum up to one (was $sum)"
    end
    push_and_create!(data, "WELLSTRE", rec)
end

@keyword :SCHEDULE :WINJGAS RecordsKeyword defaults = ["Default", "GRUP", "Default", "Default", 0]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WINJGAS})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    d = parse_defaulted_group_well(f, defaults, wells, 1)
    push_and_create!(data, "WINJGAS", d)
end

@keyword :SCHEDULE :GINJGAS RecordsKeyword defaults = ["Default", "GRUP", "Default", "Default", 0]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:GINJGAS})
    defaults = keyword_defaults(definition)
    records = parse_defaulted_group(f, defaults; allow_wildcard = [false, true, true, true, true])
    push_and_create!(data, "GINJGAS", records)
end

@keyword :SCHEDULE :WRFTPLT RecordsKeyword support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:WRFTPLT})
    parser_message(cfg, outer_data, "WRFTPLT", PARSER_MISSING_SUPPORT)
    skip_record(f)
end

@keyword :SCHEDULE :GRUPTREE RecordsKeyword defaults = ["Default", "Default"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:GRUPTREE})
    rec = parse_defaulted_group(f, keyword_defaults(definition))
    push_and_create!(data, "GRUPTREE", rec)
end

@keyword :SCHEDULE :AQUFETP RecordsKeyword support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:AQUFETP})
    parser_message(cfg, outer_data, "AQUFETP", PARSER_MISSING_SUPPORT)
    skip_record(f)
end

@keyword :SCHEDULE :WTEMP RecordsKeyword defaults = ["Default", NaN] units = (:id, :relative_temperature)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WTEMP})
    defaults = keyword_defaults(definition)
    wells = get_wells(outer_data)
    wtemp = parse_defaulted_group_well(f, defaults, wells, 1)
    for wt in wtemp
        swap_unit_system_axes!(wt, units, keyword_units(definition))
    end
    push_and_create!(data, "WTEMP", wtemp)
end

@keyword :SCHEDULE :WTRACER RecordsKeyword defaults = ["", "", 0.0, NaN, ""]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WTRACER})
    records = parse_defaulted_group_well(f, keyword_defaults(definition), get_wells(outer_data))
    for rec in records
        @assert isfinite(rec[3]) && rec[3] >= 0 "WTRACER concentration must be nonnegative."
    end
    push_and_create!(data, "WTRACER", records)
end

@keyword(:SCHEDULE, :WELSEGS, RecordsKeyword,
    # The last two header fields retain the existing unconverted thermal values.
    defaults = (header = ["Default", NaN, 0.0, 1e-5, "Default", "HFA", "HO", 0.0, 0.0, 0.0, 0.0, 0.0],
        segments = Any[-1, -1, -1, -1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]),
    units = (header = (:id, :length, :length, :volume, :id, :id, :id, :length, :length, :area, :id, :id),
        segments = (:id, :id, :id, :id, :length, :length, :length, :area, :volume, :length, :length, :length, :area, :id, :id)))

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WELSEGS})
    defaults = keyword_defaults(definition)
    utypes = keyword_units(definition)
    rec = read_record(f)
    wheader = parse_defaulted_line(rec, defaults.header)
    swap_unit_system_axes!(wheader, units, utypes.header)

    wname = wheader[1]
    @assert wname != "Default"

    # Now follows the segments
    segments = []
    while true
        rec = read_record(f)
        if length(rec) == 0
            break
        end
        l = parse_defaulted_line(rec, defaults.segments)
        swap_unit_system_axes!(l, units, utypes.segments)
        push!(segments, l)
    end
    if !haskey(data, "WELSEGS")
        data["WELSEGS"] = Dict{String, Any}()
    end
    data["WELSEGS"][wname] = (header = wheader, segments = segments)
end

@keyword(:SCHEDULE, :WSEGVALV, RecordsKeyword,
    defaults = ["Default", -1, NaN, NaN, -1.0, -1.0, -1.0, -1.0, "OPEN", -1.0],
    units = (:id, :id, :id, :area, :length, :length, :length, :area, :id, :area),
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WSEGVALV})
    defaults = keyword_defaults(definition)
    @assert length(defaults) == 10
    wells = get_wells(outer_data)
    compdat = parse_defaulted_group_well(f, defaults, wells, 1)
    # Unit conversion
    utypes = keyword_units(definition)
    for cd in compdat
        swap_unit_system_axes!(cd, units, utypes)
    end
    push_and_create!(data, "WSEGVALV", compdat)
end

@keyword(:SCHEDULE, :COMPSEGS, RecordsKeyword,
    defaults = (header = ["Default"],
        segments = Any[-1, -1, -1, -1, 0.0, 0.0, "Default", -1, 0.0, 0.0, 0]),
    units = (header = nothing,
        segments = (:id, :id, :id, :id, :length, :length, :id, :id, :length, :length, :id)))

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:COMPSEGS})
    defaults = keyword_defaults(definition)
    utypes = keyword_units(definition)
    rec = read_record(f)
    wname = only(parse_defaulted_line(rec, defaults.header))
    @assert wname != "Default"

    segments = []
    while true
        rec = read_record(f)
        if length(rec) == 0
            break
        end
        l = parse_defaulted_line(rec, defaults.segments)
        swap_unit_system_axes!(l, units, utypes.segments)
        push!(segments, l)
    end
    if !haskey(data, "COMPSEGS")
        data["COMPSEGS"] = Dict{String, Any}()
    end
    data["COMPSEGS"][wname] = segments
end

@keyword :SCHEDULE :UDQ RecordsKeyword support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:UDQ})
    skip_record(f)
    parser_message(cfg, outer_data, "UDQ", PARSER_MISSING_SUPPORT)
end

@keyword :SCHEDULE :ACTIONX RecordsKeyword support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:ACTIONX})
    skip_record(f)
    parser_message(cfg, outer_data, "ACTIONX", PARSER_MISSING_SUPPORT)
end

@keyword :SCHEDULE :GTMULT RecordsKeyword support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:GTMULT})
    skip_record(f)
    parser_message(cfg, outer_data, "ACTIONX", PARSER_MISSING_SUPPORT)
end

@keyword :SCHEDULE :VFPINJ RecordsKeyword records = :dependent support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:VFPINJ})
    record_start = read_record(f)
    record_flow = read_record(f)
    record_thp = parse_deck_vector(f)
    # This determines how many lines to read for the remaining records.
    n_lines = length(record_thp)
    for i in 1:n_lines
        rec = read_record(f)
        if length(rec) == 0
            break
        end
    end
    parser_message(cfg, outer_data, "VFPINJ", PARSER_MISSING_SUPPORT)
end
