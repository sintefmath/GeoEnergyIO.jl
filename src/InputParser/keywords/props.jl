@keyword :PROPS (:RPTPROPS, :FULLIMP) RecordKeyword support = :ignored

@keyword :PROPS :FILLEPS FlagKeyword

function finish_current_section!(data, units, cfg, outer_data, ::Val{:PROPS})

end

@keyword :PROPS :CNAMES RecordKeyword

function keyword_defaults(::RecordKeyword{:CNAMES}, outer_data, units)
    return fill("", compositional_number_of_components(outer_data))
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:CNAMES})
    templ = keyword_defaults(definition, outer_data, units)
    rec = read_record(f)
    data["CNAMES"] = parse_defaulted_line(rec, templ)
end

@keyword :PROPS :EOS RecordsKeyword defaults = ["PR"] records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:EOS})
    out = String[]
    for i in 1:number_of_tables(outer_data, :eosnum)
        rec = read_record(f)
        v = only(parse_defaulted_line(rec, keyword_defaults(definition)))
        push!(out, v)
    end
    data["EOS"] = out
end

@keyword :PROPS :NCOMPS RecordKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:NCOMPS})
    rec = read_record(f)
    data["NCOMPS"] = parse(Int, only(rec))
end

@keyword :PROPS :SALINITY RecordKeyword defaults = [0.0]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:SALINITY})
    rec = read_record(f)
    data["SALINITY"] = only(parse_defaulted_line(rec, keyword_defaults(definition)))
end

@keyword :PROPS (:OMEGAA, :OMEGAB) RecordsKeyword records = :regional

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordsKeyword{:OMEGAA}, RecordsKeyword{:OMEGAB}})
    k = keyword_name(definition)
    data["$k"] = parse_compositional_helper!(f, outer_data, data, "$k")
end

@keyword :PROPS :LBCCOEF RecordKeyword defaults = [0.1023, 0.023364, 0.058533, -0.040758, 0.0093324]

@keyword :PROPS :STCOND RecordKeyword units = (:relative_temperature, :pressure)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:STCOND})
    std = parse_deck_vector(f)
    @assert length(std) == 2
    swap_unit_system_axes!(std, units, keyword_units(definition))
    data["STCOND"] = std
end

@keyword :PROPS :BIC RecordsKeyword records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:BIC})
    n = compositional_number_of_components(outer_data)
    out = []
    for i in 1:number_of_tables(outer_data, :eosnum)
        bic = parse_deck_vector(f)
        @assert length(bic) == n*(n-1)÷2 "Bad length for BIC input."
        m = zeros(n, n)
        ix = 1
        for i in 1:n
            for j in 1:(i-1)
                m[i, j] = bic[ix]
                ix += 1
            end
        end
        push!(out, Symmetric(collect(m')))
    end
    data["BIC"] = out
end

function parse_compositional_helper!(f, outer_data, data, k; table_type = :eosnum)
    n = compositional_number_of_components(outer_data)
    out = Vector{Float64}[]
    for i in 1:number_of_tables(outer_data, table_type)
        val = parse_deck_vector(f)
        @assert length(val) == n "One $k should be provided per component (expected $n, was $(length(val)))."
        push!(out, val)
    end
    return out
end

@keyword :PROPS :ACF RecordsKeyword records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:ACF})
    data["ACF"] = parse_compositional_helper!(f, outer_data, data, "ACF")
end

@keyword :PROPS :ZCRIT RecordsKeyword records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:ZCRIT})
    data["ZCRIT"] = parse_compositional_helper!(f, outer_data, data, "ZCRIT")
end

@keyword :PROPS :SSHIFT RecordsKeyword records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:SSHIFT})
    data["SSHIFT"] = parse_compositional_helper!(f, outer_data, data, "SSHIFT")
end

@keyword :PROPS :SSHIFTS RecordsKeyword records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:SSHIFTS})
    data["SSHIFTS"] = parse_compositional_helper!(f, outer_data, data, "SSHIFTS"; table_type = :surface_eosnum)
end

@keyword :PROPS :PARACHOR RecordsKeyword records = :regional warning = PARSER_JUTULDARCY_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:PARACHOR})
    parser_message(cfg, outer_data, "PARACHOR", PARSER_JUTULDARCY_MISSING_SUPPORT)
    # TODO: Units.
    data["PARACHOR"] = parse_compositional_helper!(f, outer_data, data, "PARACHOR")
end

@keyword :PROPS :VCRITVIS RecordsKeyword records = :regional warning = PARSER_JUTULDARCY_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:VCRITVIS})
    parser_message(cfg, outer_data, "VCRITVIS", PARSER_JUTULDARCY_MISSING_SUPPORT)
    # TODO: Units.
    data["VCRITVIS"] = parse_compositional_helper!(f, outer_data, data, "VCRITVIS")
end

@keyword :PROPS :ZCRITVIS RecordsKeyword records = :regional warning = PARSER_JUTULDARCY_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:ZCRITVIS})
    parser_message(cfg, outer_data, "ZCRITVIS", PARSER_JUTULDARCY_MISSING_SUPPORT)
    # TODO: Units.
    data["ZCRITVIS"] = parse_compositional_helper!(f, outer_data, data, "ZCRITVIS")
end

@keyword :PROPS :ZI RecordsKeyword records = :regional warning = PARSER_JUTULDARCY_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:ZI})
    parser_message(cfg, outer_data, "ZI", PARSER_JUTULDARCY_MISSING_SUPPORT)
    data["ZI"] = parse_compositional_helper!(f, outer_data, data, "ZI")
end

@keyword :PROPS :PCRIT RecordsKeyword units = :pressure records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PCRIT})
    p_c = parse_compositional_helper!(f, outer_data, data, "PCRIT")
    swap_unit_system!(p_c, units, keyword_units(definition))
    data["PCRIT"] = p_c
end

@keyword :PROPS :TCRIT RecordsKeyword units = :absolute_temperature records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:TCRIT})
    p_c = parse_compositional_helper!(f, outer_data, data, "TCRIT")
    swap_unit_system!(p_c, units, keyword_units(definition))
    data["TCRIT"] = p_c
end

@keyword :PROPS :MW RecordsKeyword units = :molar_mass records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:MW})
    mw = parse_compositional_helper!(f, outer_data, data, "MW")
    swap_unit_system!(mw, units, keyword_units(definition))
    data["MW"] = mw
end

@keyword :PROPS :VCRIT RecordsKeyword units = :critical_volume records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:VCRIT})
    V = parse_compositional_helper!(f, outer_data, data, "VCRIT")
    swap_unit_system!(V, units, keyword_units(definition))
    data["VCRIT"] = V
end

@keyword :PROPS :PLYVISC RecordsKeyword units = (:concentration, :identity) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PLYVISC})
    k = keyword_name(definition)
    npvt = number_of_tables(outer_data, :pvtnum)
    ply_tab = parse_region_matrix_table(f, npvt)
    for tab in ply_tab
        swap_unit_system_axes!(tab, units, keyword_units(definition))
    end
    data["$k"] = ply_tab
end

@keyword :PROPS :PLYROCK RecordsKeyword units = (:identity, :identity, :density, :identity, :identity) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PLYROCK})
    k = keyword_name(definition)
    nsat = number_of_tables(outer_data, :satnum)
    ply_tab = parse_region_matrix_table(f, nsat)
    for tab in ply_tab
        swap_unit_system_axes!(tab, units, keyword_units(definition))
    end
    data["$k"] = map(vec, ply_tab)
end

@keyword :PROPS :PLYADS RecordsKeyword units = (:concentration, :identity) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PLYADS})
    k = keyword_name(definition)
    nsat = number_of_tables(outer_data, :satnum)
    ply_tab = parse_region_matrix_table(f, nsat)
    for tab in ply_tab
        swap_unit_system_axes!(tab, units, keyword_units(definition))
    end
    data["$k"] = ply_tab
end

@keyword :PROPS :PLMIXPAR RecordsKeyword records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PLMIXPAR})
    k = keyword_name(definition)
    nreg = number_of_tables(outer_data, :nplmix)
    ply_tab = parse_region_matrix_table(f, nreg)
    data["$k"] = map(only, ply_tab)
end

@keyword :PROPS :PLYMAX RecordsKeyword units = (:concentration, :concentration) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PLYMAX})
    k = keyword_name(definition)
    nreg = number_of_tables(outer_data, :nplmix)
    ply_tab = parse_region_matrix_table(f, nreg)
    for tab in ply_tab
        swap_unit_system_axes!(tab, units, keyword_units(definition))
    end
    data["$k"] = map(vec, ply_tab)
end

struct SaturationTable{K, U} <: SaturationTableKeyword{K}
    units::U
end

SaturationTable{K}(; units = nothing) where K = SaturationTable{K, typeof(units)}(units)
keyword_units(def::SaturationTable) = def.units

@keyword :PROPS (:SWOF, :SGOF, :SLGOF) SaturationTable units = (:identity, :identity, :identity, :pressure)
@keyword :PROPS (:SWFN, :SGFN, :GSF) SaturationTable units = (:identity, :identity, :pressure)
@keyword :PROPS (:SOF2, :SOF3, :WSF, :SOMGAS, :SOMWAT) SaturationTable

function parse_keyword!(data, outer_data, units, cfg, f, def::SaturationTableKeyword)
    tables = parse_saturation_table(f, outer_data)
    column_units = keyword_units(def)
    if !isnothing(column_units)
        for table in tables
            swap_unit_system_axes!(table, units, column_units)
        end
    end
    return data[String(keyword_name(def))] = tables
end

@keyword :PROPS :PVDG RecordsKeyword units = (:pressure, :gas_formation_volume_factor, :viscosity) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PVDG})
    pvdg = parse_dead_pvt_table(f, outer_data)
    for tab in pvdg
        swap_unit_system_axes!(tab, units, keyword_units(definition))
    end
    data["PVDG"] = pvdg
end

@keyword(:PROPS, :PVTO, RecordsKeyword,
    records = :regional,
    units = (key = :u_rs,
        data = (:pressure, :liquid_formation_volume_factor, :viscosity)),
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PVTO})
    pvto = parse_live_pvt_table(f, outer_data)
    for tab in pvto
        swap_unit_system_axes!(tab["data"], units, keyword_units(definition).data)
        swap_unit_system!(tab["key"], units, keyword_units(definition).key)
    end
    data["PVTO"] = pvto
end

@keyword(:PROPS, :PVTG, RecordsKeyword,
    records = :regional,
    units = (key = :pressure,
        data = (:u_rv, :gas_formation_volume_factor, :viscosity)),
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PVTG})
    pvtg = parse_live_pvt_table(f, outer_data)
    for tab in pvtg
        swap_unit_system_axes!(tab["data"], units, keyword_units(definition).data)
        swap_unit_system!(tab["key"], units, keyword_units(definition).key)
    end
    data["PVTG"] = pvtg
end

@keyword(:PROPS, :PVTW, RecordsKeyword,
    defaults = [NaN, NaN, NaN, NaN, 0.0],
    units = (:pressure, :liquid_formation_volume_factor, :compressibility, :viscosity, :compressibility),
    records = :regional,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PVTW})
    tdims = keyword_defaults(definition)
    utypes = keyword_units(definition)
    nreg = number_of_tables(outer_data, :pvtnum)
    out = []
    for i = 1:nreg
        rec = read_record(f)
        t = parse_defaulted_line(rec, tdims)
        swap_unit_system_axes!(t, units, utypes)
        @assert all(isfinite, t) "PVTW cannot be defaulted, found defaulted record in region $i"
        push!(out, t)
    end
    data["PVTW"] = out
end

@keyword(:PROPS, :PVCDO, RecordsKeyword,
    defaults = [NaN, NaN, NaN, NaN, NaN],
    units = (:pressure, :liquid_formation_volume_factor, :compressibility, :viscosity, :compressibility),
    records = :regional,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PVCDO})
    tdims = keyword_defaults(definition)
    utypes = keyword_units(definition)
    nreg = number_of_tables(outer_data, :pvtnum)
    out = []
    for i = 1:nreg
        rec = read_record(f)
        t = parse_defaulted_line(rec, tdims)
        swap_unit_system_axes!(t, units, utypes)
        @assert all(isfinite, t) "PVCDO cannot be defaulted, found defaulted record in region $i"
        push!(out, t)
    end
    data["PVCDO"] = out
end

@keyword :PROPS :PVDO RecordsKeyword units = (:pressure, :liquid_formation_volume_factor, :viscosity) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:PVDO})
    pvdo = parse_dead_pvt_table(f, outer_data)
    for tab in pvdo
        swap_unit_system_axes!(tab, units, keyword_units(definition))
    end
    data["PVDO"] = pvdo
end

@keyword(:PROPS, :VISCREF, RecordsKeyword,
    defaults = [NaN, NaN, NaN],
    units = (:pressure, :u_rs, :id),
    records = :regional,
    support = :partial,
    warning = PARSER_PARTIAL_SUPPORT,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:VISCREF})
    nreg = number_of_tables(outer_data, :pvtnum)
    viscref = []
    tdims = keyword_defaults(definition)
    for tab in 1:nreg
        rec = read_record(f)
        tab = parse_defaulted_line(rec, tdims)
        # TODO: Last entry here is API related, should have a unit added.
        swap_unit_system_axes!(tab, units, keyword_units(definition))
        push!(viscref, tab)
    end
    parser_message(cfg, outer_data, "VISCREF", PARSER_PARTIAL_SUPPORT)
    data["VISCREF"] = viscref
end

@keyword :PROPS :ROCKTAB RecordsKeyword units = :pressure records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:ROCKTAB})
    nrock = outer_data["RUNSPEC"]["ROCKCOMP"][2]
    tables = parse_region_matrix_table(f, nrock)
    for tab in tables
        for i in axes(tab, 1)
            tab[i, 1] = swap_unit_system(tab[i, 1], units, keyword_units(definition))
        end
    end
    data["ROCKTAB"] = tables
end

@keyword(:PROPS, :SPECHEAT, RecordsKeyword,
    units = (:relative_temperature, :mass_heat_capacity, :mass_heat_capacity, :mass_heat_capacity),
    records = :regional,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:SPECHEAT})
    nreg = number_of_tables(outer_data, :pvtnum)
    speacheat = parse_region_matrix_table(f, nreg)
    for tab in speacheat
        swap_unit_system_axes!(tab, units, keyword_units(definition))
    end
    data["SPECHEAT"] = speacheat
end

@keyword :PROPS :TRACER RecordsKeyword defaults = ["", "", "", "", 0, ""]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:TRACER})
    records = parse_defaulted_group(f, keyword_defaults(definition))
    names = String[]
    for rec in records
        name, phase = rec[1:2]
        @assert !isempty(name) "TRACER requires a name."
        @assert !(name in names) "Duplicate TRACER name $name."
        @assert phase in ("WAT", "WATER", "OIL", "GAS") "Unknown TRACER phase $phase."
        push!(names, name)
    end
    data["TRACER"] = records
end

@keyword :PROPS :SPECROCK RecordsKeyword units = (:relative_temperature, :volume_heat_capacity) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:SPECROCK})
    nreg = number_of_tables(outer_data, :satnum)
    specrock = parse_region_matrix_table(f, nreg)
    for tab in specrock
        swap_unit_system_axes!(tab, units, keyword_units(definition))
    end
    data["SPECROCK"] = specrock
end

@keyword :PROPS (:WATVISCT, :OILVISCT, :GASVISCT) RecordsKeyword units = (:relative_temperature, :viscosity) records = :regional

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordsKeyword{:WATVISCT}, RecordsKeyword{:OILVISCT}, RecordsKeyword{:GASVISCT}})
    k = keyword_name(definition)
    nreg = number_of_tables(outer_data, :pvtnum)
    visct = parse_region_matrix_table(f, nreg)
    for tab in visct
        swap_unit_system_axes!(tab, units, keyword_units(definition))
    end
    data["$k"] = visct
end

@keyword(:PROPS, :WATDENT, RecordsKeyword,
    records = :regional,
    defaults = [293.15, 3.0e-4, 3.0e-6],
    units = (:absolute_temperature, :thermal_expansion_c1, :thermal_expansion_c2),
)

function keyword_defaults(def::RecordsKeyword{:WATDENT}, outer_data, units)
    return defaults_for_unit(units.from, keyword_units(def); metric = keyword_defaults(def))
end

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:WATDENT})
    nreg = number_of_tables(outer_data, :pvtnum)
    watdent = []
    uids = keyword_units(definition)
    tdims = keyword_defaults(definition, outer_data, units)
    for tab in 1:nreg
        rec = read_record(f)
        tab = parse_defaulted_line(rec, tdims)
        swap_unit_system_axes!(tab, units, uids)
        push!(watdent, tab)
    end
    data["WATDENT"] = watdent
end

@keyword(:PROPS, :ROCK, RecordsKeyword,
    defaults = [NaN, NaN, NaN, NaN, NaN, NaN],
    units = [:pressure, :compressibility, :compressibility, :compressibility, :id, :id],
    records = :regional,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:ROCK})
    tdims = keyword_defaults(definition)
    utypes = keyword_units(definition)
    out = []
    nreg = number_of_tables(outer_data, :pvtnum)
    for i = 1:nreg
        rec = read_record(f)
        l = parse_defaulted_line(rec, tdims)
        swap_unit_system_axes!(l, units, utypes)
        push!(out, l)
    end
    data["ROCK"] = out
end

@keyword :PROPS :DIFFC RecordsKeyword records = :regional support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:DIFFC})
    parser_message(cfg, outer_data, "DIFFC", PARSER_MISSING_SUPPORT)
    nreg = number_of_tables(outer_data, :pvtnum)
    for i = 1:nreg
        rec = read_record(f)
    end
end

@keyword :PROPS :COMPS RecordKeyword defaults = [0]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:COMPS})
    rec = read_record(f)
    ncomp = only(parse_defaulted_line(rec, keyword_defaults(definition)))
    data["COMPS"] = ncomp
end

@keyword(:PROPS, (:KRW, :KRWX, :KRWY, :KRWZ, :KRWR, :KRWRX, :KRWRY, :KRWRZ), GridArrayKeyword,
    edit_unit = nothing,
    warning = PARSER_JUTULDARCY_MISSING_SUPPORT,
)
@keyword(:PROPS, (":KRWX-", ":KRWY-", ":KRWZ-", ":KRWRX-", ":KRWRY-", ":KRWRZ-"), GridArrayKeyword,
    edit_unit = nothing,
    warning = PARSER_JUTULDARCY_MISSING_SUPPORT,
)

@keyword :PROPS :SCALECRS RecordKeyword defaults = ["NO"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:SCALECRS})
    rec = read_record(f)
    scale = only(parse_defaulted_line(rec, keyword_defaults(definition)))
    scale = uppercase(scale)
    if scale == "Y"
        scale = "YES"
    elseif scale == "N"
        scale = "NO"
    end
    if scale == "YES" || scale == "NO"
        data["SCALECRS"] = scale
    else
        error("SCALECRS must be one of the following: Y, N, YES, NO")
    end
end

@keyword :PROPS :DENSITY RecordsKeyword defaults = [NaN, NaN, NaN] units = :density records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:DENSITY})
    tdims = keyword_defaults(definition)
    nreg = number_of_tables(outer_data, :pvtnum)
    out = []
    for i = 1:nreg
        rec = read_record(f)
        t = parse_defaulted_line(rec, tdims)
        swap_unit_system!(t, units, keyword_units(definition))
        push!(out, t)
    end
    data["DENSITY"] = out
end

@keyword :PROPS :GRAVITY RecordsKeyword defaults = [45.5, 1.0, 0.7773] records = :regional

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:GRAVITY})
    tdims = keyword_defaults(definition)
    file_units = current_unit_system(outer_data)
    if file_units == :field
        rho_wat = 62.4
        rho_air = 0.076363
    elseif file_units == :lab
        rho_wat = 1.0
        rho_air = 0.0012232
    elseif file_units in (:si, :metric)
        rho_wat = 1000.0
        rho_air = 1.22
    else
        error("Unknown unit system: $units")
    end
    nreg = number_of_tables(outer_data, :pvtnum)
    out = []
    for i = 1:nreg
        rec = read_record(f)
        t = parse_defaulted_line(rec, tdims)
        grav_oil = 141.15/(t[1]+131.5)
        vals = [grav_oil*rho_wat, t[2]*rho_wat, t[3]*rho_air]
        push!(out, vals)
    end
    data["DENSITY"] = out
end

@keyword :PROPS (:RSCONST, :RSCONSTT) RecordKeyword defaults = [NaN, NaN] support = :partial warning = PARSER_PARTIAL_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordKeyword{:RSCONST}, RecordKeyword{:RSCONSTT}})
    rec = read_record(f)
    # TODO: This is missing units.
    tdims = keyword_defaults(definition)
    parsed = parse_defaulted_line(rec, tdims, required_num = length(tdims), keyword = "RSCONST")
    parser_message(cfg, outer_data, "RSCONST", PARSER_PARTIAL_SUPPORT)
    data["RSCONST"] = parsed
end

@keyword(:PROPS, :ROCKOPTS, RecordKeyword,
    defaults = ["PRESSURE", "NOSTORE", "PVTNUM", "DEFLATION"],
    warning = PARSER_JUTULDARCY_MISSING_SUPPORT,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:ROCKOPTS})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    parsed = parse_defaulted_line(rec, tdims)
    parser_message(cfg, outer_data, "ROCKOPTS", PARSER_JUTULDARCY_MISSING_SUPPORT)
    data["ROCKOPTS"] = parsed
end

@keyword :PROPS :AQUTAB RecordsKeyword records = :regional support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:AQUTAB})
    num = outer_data["RUNSPEC"]["AQUDIMS"][3]-1
    for i in 1:num
        skip_record(f)
    end
    parser_message(cfg, outer_data, "AQUTAB", PARSER_MISSING_SUPPORT)
end

@keyword :PROPS :AQUCT RecordsKeyword support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordsKeyword{:AQUCT})
    skip_record(f)
    parser_message(cfg, outer_data, "AQUCT", PARSER_MISSING_SUPPORT)
end

@keyword :PROPS :SWATINIT GridArrayKeyword

@keyword :PROPS (:DIFCCOG, :DIFFCOIL, :DIFFCGAS, :DIFFCWAT, :DIFFCWG) RecordKeyword units = :diffusivity

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{
            RecordKeyword{:DIFCCOG}, RecordKeyword{:DIFFCOIL}, RecordKeyword{:DIFFCGAS},
            RecordKeyword{:DIFFCWAT}, RecordKeyword{:DIFFCWG}
        })
    k = keyword_name(definition)
    n = compositional_number_of_components(outer_data)
    out = zeros(n)
    val = parse_deck_vector(f)
    nv = length(val)
    @assert nv <= n "$k has more entries ($nv) than components ($n)"
    out[1:nv] = val
    swap_unit_system!(out, units, keyword_units(definition))
    data["$k"] = out
end
