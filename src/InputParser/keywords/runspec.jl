@keyword :RUNSPEC (:NOECHO, :ECHO) FlagKeyword support = :ignored

@keyword :RUNSPEC (
    :METRIC, :FIELD, :WATER, :POLYMER, :OIL, :GAS, :DISGAS, :GASWAT, :DIFFUSE,
    :CO2STOR, :CO2STORE, :NOHYST, :CART, :AIM, :HWELLS, :PRCORR, :MONITOR, :THERMAL,
    :MECH, :VAPOIL, :UNIFOUT, :UNIFIN, :CPR
) FlagKeyword

@keyword :RUNSPEC :SAVE RecordKeyword support = :raw

@keyword :RUNSPEC (:NUMRES, :MULTSAVE) RecordKeyword support = :ignored

function finish_current_section!(data, units, cfg, outer_data, ::Val{:RUNSPEC})

end

@keyword :RUNSPEC :SKIPREST FlagKeyword support = :ignored warning = PARSER_MISSING_SUPPORT

@keyword :RUNSPEC :WPOTCALC RecordKeyword defaults = ["YES", "DEFAULTED"]

@keyword :RUNSPEC :MESSAGES RecordKeyword support = :ignored warning = PARSER_MISSING_SUPPORT

@keyword :RUNSPEC :START RecordKeyword defaults = [1, "JAN", 1970, "00:00:00"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:START})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    start = parse_defaulted_line(rec, tdims)
    data["START"] = convert_date_kw(start)
end

@keyword :RUNSPEC :TITLE TextKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::TextKeyword{:TITLE})
    m = readline(f)
    m = strip(m)
    data["TITLE"] = m
end

@keyword :RUNSPEC :TEMP FlagKeyword support = :flag

function parse_keyword!(data, outer_data, units, cfg, f, ::FlagKeyword{:TEMP})
    # Enable thermal setup, retaining TEMP so the simulator can omit pressure
    # work in the transported energy for the temperature-model formulation.
    data["THERMAL"] = true
    data["TEMP"] = true
end

@keyword(:RUNSPEC, :TRACERS, RecordKeyword,
    defaults = [0, 0, 0, 0, "NODIFF", 12, 1, "NO", NaN, NaN, 1.0, 0],
    warning = PARSER_JUTULDARCY_PARTIAL_SUPPORT,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:TRACERS})
    defaults = keyword_defaults(definition)
    rec = parse_defaulted_line(read_record(f), defaults)
    if rec[5] != "NODIFF"
        parser_message(cfg, outer_data, "TRACERS", PARSER_JUTULDARCY_PARTIAL_SUPPORT,
            "Numerical dispersion control is not implemented; tracers use the simulator's transport discretization.")
    end
    data["TRACERS"] = rec
end

@keyword :RUNSPEC :PATHS RecordsKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:PATHS})
    if !haskey(data, "PATHS")
        data["PATHS"] = Dict{String, String}()
    end
    pths = data["PATHS"]
    while true
        rec = readline(f)
        # Some custom parsing here because of slashes inside entries here
        rec = rstrip(rec, ' ')
        rec = rstrip(rec, '/')
        rec = rstrip(rec, ' ')
        rec = split(rec, " ", keepempty = false)
        if length(rec) == 0
            break
        end
        @assert length(rec) == 2 "PATHS must have exactly two entries per line."
        alias, subst = rec
        alias = strip(alias, '\'')
        subst = strip(subst, '\'')
        pths[alias] = subst
    end
    return pths
end

@keyword(:RUNSPEC, :EHYSTR, RecordKeyword,
    defaults = [0.1, -1000, 1.0, 0.1, "BOTH", "RETR", "DRAIN", "DEFAULT", "NO", "NO", "NO", 0.0, 0],
    warning = PARSER_JUTULDARCY_PARTIAL_SUPPORT,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:EHYSTR})
    rec = read_record(f)
    defaults = keyword_defaults(definition)
    h = parse_defaulted_line(rec, defaults)
    if h[2] == -1000
        if haskey(outer_data, "RUNSPEC")
            rs = outer_data["RUNSPEC"]
            if haskey(rs, "COMPS")
                # Killough is default for E300 type models
                h[2] = 2
                msg = "Found COMPS, setting to 2 (= Killough)"
            elseif haskey(rs, "CO2STORE")
                h[2] = 2
                msg = "Found CO2STORE, setting to 2 (= Killough)"
            else
                h[2] = 0
                msg = "Did not find CO2STORE or COMPS, setting to 0 (= Carlson)"
            end
        else
            h[2] = 0
            msg = "RUNSPEC is not available, setting to 0 (= Carlson)"
        end
        parser_message(cfg, outer_data, "EHYSTR", "EHYSTR second entry is defaulted. $msg", important = true)
    end
    @assert h[2] in -1:9
    @assert h[5] in ("BOTH", "PC", "KR")
    @assert h[6] in ("RETR", "NEW")
    @assert h[7] in ("BOTH", "DRAIN")
    @assert h[8] in ("DEFAULT", "OIL", "GAS")

    parser_message(cfg, outer_data, "EHYSTR", PARSER_JUTULDARCY_PARTIAL_SUPPORT)
    data["EHYSTR"] = h
end

@keyword :RUNSPEC :RADIAL FlagKeyword warning = PARSER_JUTULDARCY_MISSING_SUPPORT

@keyword :RUNSPEC (:STONE1, :STONE2, :BAKER1, :BAKER2) FlagKeyword support = :flag warning = PARSER_JUTULDARCY_MISSING_SUPPORT

@keyword :RUNSPEC :MISCSTR RecordKeyword defaults = [NaN, NaN, NaN] warning = PARSER_JUTULDARCY_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:MISCSTR})
    parser_message(cfg, outer_data, "MISCSTR", PARSER_JUTULDARCY_MISSING_SUPPORT)
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    l = parse_defaulted_line(rec, tdims)
    @assert !isnan(l[1])
    for i in 2:3
        if isnan(l[i])
            l[i] = l[1]
        end
    end
    cm = si_unit(:centi)*si_unit(:meter)
    d = si_unit(:dyne)
    for i in eachindex(l)
        l[i] *= d/cm
    end
    data["MISCSTR"] = l
end

@keyword :RUNSPEC :EXTRAPMS RecordKeyword defaults = [0] warning = PARSER_JUTULDARCY_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:EXTRAPMS})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    v = only(parse_defaulted_line(rec, tdims))
    if v > 0
        parser_message(cfg, outer_data, "EXTRAPMS", PARSER_JUTULDARCY_MISSING_SUPPORT)
    end
    data["EXTRAPMS"] = v
end

@keyword :RUNSPEC :ACTDIMS RecordKeyword defaults = [2, 50, 80, 3]

@keyword :RUNSPEC :TABDIMS RecordKeyword defaults = [1, 1, 20, 20, 1, 20, 20, 1,
             1, -1, 10,  1, -1,  0,  0, -1,
             10, 10, 10, -1,  5,  5,  5,  0, -1]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:TABDIMS})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    # TODO: Special logic for -1 entries
    data["TABDIMS"] = parse_defaulted_line(rec, tdims)
end

@keyword :RUNSPEC :SMRYDIMS RecordKeyword defaults = [-1]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:SMRYDIMS})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    val = only(parse_defaulted_line(rec, tdims))
    if val == -1
        val = 10000
    end
    data["SMRYDIMS"] = val
end

@keyword :RUNSPEC :UDADIMS RecordKeyword defaults = [0, 0, 100]

@keyword :RUNSPEC :UDQDIMS RecordKeyword defaults = [16, 16, 0, 0, 0, 0, 0, 0, 0, 0, "N"]

@keyword :RUNSPEC :FAULTDIM RecordKeyword defaults = [0]

@keyword :RUNSPEC :GRIDOPTS RecordKeyword defaults = ["NO", 0, 0]

@keyword :RUNSPEC :ROCKCOMP RecordKeyword defaults = ["REVERS", 1, "NO", "CZ", 0.0]

@keyword :RUNSPEC :ENDSCALE RecordKeyword defaults = ["NODIR", "REVERS", 1, 20, 0]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:ENDSCALE})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    props = get_section(outer_data, :PROPS, set_current = false)
    if !haskey(props, "SCALECRS")
        props["SCALECRS"] = "NO"
    end
    data["ENDSCALE"] = parse_defaulted_line(rec, tdims)
end

@keyword :RUNSPEC :EQLDIMS RecordKeyword defaults = [1, 100, 50, 1, 50]

@keyword :RUNSPEC :MSGFILE RecordKeyword defaults = [1]

@keyword :RUNSPEC :REGDIMS RecordKeyword defaults = [1, 1, 0, 0, 0, 1, 0, 0, 0, 1]

@keyword :RUNSPEC :WELLDIMS RecordKeyword defaults = [0, 0, 0, 0, 5, 10, 5, 4, 3, 0, 1, 1, 10, 201]

@keyword :RUNSPEC :WSEGDIMS RecordKeyword defaults = [0, 1, 1, 0]

@keyword :RUNSPEC :VFPPDIMS RecordKeyword defaults = [0, 0, 0, 0, 0, 0]

@keyword :RUNSPEC :VFPIDIMS RecordKeyword defaults = [0, 0, 0]

@keyword :RUNSPEC :AQUDIMS RecordKeyword defaults = [1, 1, 1, 36, 1, 1, 0, 0]

@keyword :RUNSPEC :MISCIBLE RecordKeyword defaults = [1, 20, "NONE"] warning = PARSER_JUTULDARCY_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:MISCIBLE})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    parser_message(cfg, outer_data, "MISCIBLE", PARSER_JUTULDARCY_MISSING_SUPPORT)
    data["MISCIBLE"] = parse_defaulted_line(rec, tdims)
end
