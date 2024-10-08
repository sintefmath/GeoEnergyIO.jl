function finish_current_section!(data, units, cfg, outer_data, ::Val{:PROPS})
    
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:RPTPROPS})
    read_record(f)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:FULLIMP})
    read_record(f)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:CNAMES})
    n = compositional_number_of_components(outer_data)
    templ = fill("", n)
    rec = read_record(f)
    data["CNAMES"] = parse_defaulted_line(rec, templ)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:EOS})
    out = String[]
    for i in 1:number_of_tables(outer_data, :eosnum)
        rec = read_record(f)
        v = only(parse_defaulted_line(rec, ["PR"]))
        push!(out, v)
    end
    data["EOS"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:NCOMPS})
    rec = read_record(f)
    data["NCOMPS"] = parse(Int, only(rec))
end

function parse_keyword!(data, outer_data, units, cfg, f, val::Union{Val{:OMEGAA}, Val{:OMEGAB}})
    k = unpack_val(val)
    out = []
    for i in 1:number_of_tables(outer_data, :eosnum)
        push!(out, parse_deck_vector(f))
    end
    parser_message(cfg, outer_data, "$k", PARSER_JUTULDARCY_MISSING_SUPPORT)
    data["$k"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:LBCCOEF})
    parser_message(cfg, outer_data, "LBCCOEF", PARSER_JUTULDARCY_MISSING_SUPPORT)
    rec = read_record(f)
    defaults = [0.1023, 0.023364, 0.058533, -0.040758, 0.0093324]
    data["LBCCOEF"] = parse_defaulted_line(rec, defaults)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:STCOND})
    std = parse_deck_vector(f)
    @assert length(std) == 2
    swap_unit_system_axes!(std, units, [:relative_temperature, :pressure])
    data["STCOND"] = std
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:BIC})
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

function parse_compositional_helper!(f, outer_data, data, k)
    n = compositional_number_of_components(outer_data)
    out = Vector{Float64}[]
    for i in 1:number_of_tables(outer_data, :eosnum)
        val = parse_deck_vector(f)
        @assert length(val) == n "One $k should be provided per component (expected $n, was $(length(val)))."
        push!(out, val)
    end
    return out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ACF})
    data["ACF"] = parse_compositional_helper!(f, outer_data, data, "ACF")
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ZCRIT})
    parser_message(cfg, outer_data, "ZCRIT", PARSER_JUTULDARCY_MISSING_SUPPORT)
    data["ZCRIT"] = parse_compositional_helper!(f, outer_data, data, "ZCRIT")
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:SSHIFT})
    data["SSHIFT"] = parse_compositional_helper!(f, outer_data, data, "SSHIFT")
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PARACHOR})
    parser_message(cfg, outer_data, "PARACHOR", PARSER_MISSING_SUPPORT)
    # TODO: Units.
    data["PARACHOR"] = parse_compositional_helper!(f, outer_data, data, "PARACHOR")
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:VCRITVIS})
    parser_message(cfg, outer_data, "VCRITVIS", PARSER_MISSING_SUPPORT)
    # TODO: Units.
    data["VCRITVIS"] = parse_compositional_helper!(f, outer_data, data, "VCRITVIS")
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ZI})
    parser_message(cfg, outer_data, "ZI", PARSER_JUTULDARCY_MISSING_SUPPORT)
    data["ZI"] = parse_compositional_helper!(f, outer_data, data, "ZI")
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PCRIT})
    p_c = parse_compositional_helper!(f, outer_data, data, "PCRIT")
    swap_unit_system!(p_c, units, :pressure)
    data["PCRIT"] = p_c
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:TCRIT})
    p_c = parse_compositional_helper!(f, outer_data, data, "TCRIT")
    swap_unit_system!(p_c, units, :absolute_temperature)
    data["TCRIT"] = p_c
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:MW})
    mw = parse_compositional_helper!(f, outer_data, data, "MW")
    swap_unit_system!(mw, units, :molar_mass)
    data["MW"] = mw
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:VCRIT})
    V = parse_compositional_helper!(f, outer_data, data, "VCRIT")
    swap_unit_system!(V, units, :critical_volume)
    data["VCRIT"] = V
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:SOMGAS}, Val{:SOMWAT}})
    k = unpack_val(v)
    ns = number_of_tables(outer_data, :satnum)
    data["$k"] = parse_region_matrix_table(f, ns)
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:SWOF}, Val{:SGOF}, Val{:SLGOF}})
    k = unpack_val(v)
    sat_tab = parse_saturation_table(f, outer_data)
    for tab in sat_tab
        swap_unit_system_axes!(tab, units, (:identity, :identity, :identity, :pressure))
    end
    data["$k"] = sat_tab
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:SWFN}, Val{:SGFN}})
    k = unpack_val(v)
    sat_tab = parse_saturation_table(f, outer_data)
    for tab in sat_tab
        swap_unit_system_axes!(tab, units, (:identity, :identity, :pressure))
    end
    data["$k"] = sat_tab
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:SOF2}, Val{:SOF3}})
    k = unpack_val(v)
    sat_tab = parse_saturation_table(f, outer_data)
    data["$k"] = sat_tab
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PVDG})
    pvdg = parse_dead_pvt_table(f, outer_data)
    for tab in pvdg
        swap_unit_system_axes!(tab, units, (:pressure, :gas_formation_volume_factor, :viscosity))
    end
    data["PVDG"] = pvdg
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PVTO})
    pvto = parse_live_pvt_table(f, outer_data)
    for tab in pvto
        swap_unit_system_axes!(tab["data"], units, (:pressure, :liquid_formation_volume_factor, :viscosity))
        swap_unit_system!(tab["key"], units, :u_rs)
    end
    data["PVTO"] = pvto
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PVTG})
    pvtg = parse_live_pvt_table(f, outer_data)
    for tab in pvtg
        swap_unit_system_axes!(tab["data"], units, (:u_rv, :gas_formation_volume_factor, :viscosity))
        swap_unit_system!(tab["key"], units, :pressure)
    end
    data["PVTG"] = pvtg
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PVTW})
    tdims = [NaN, NaN, NaN, NaN, 0.0]
    utypes = (:pressure, :liquid_formation_volume_factor, :compressibility, :viscosity, :compressibility)
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

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PVCDO})
    tdims = [NaN, NaN, NaN, NaN, NaN]
    utypes = (:pressure, :liquid_formation_volume_factor, :compressibility, :viscosity, :compressibility)
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

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PVDO})
    pvdo = parse_dead_pvt_table(f, outer_data)
    for tab in pvdo
        swap_unit_system_axes!(tab, units, (:pressure, :liquid_formation_volume_factor, :viscosity))
    end
    data["PVDO"] = pvdo
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:VISCREF})
    nreg = number_of_tables(outer_data, :pvtnum)
    viscref = []
    tdims = [NaN, NaN, NaN]
    for tab in 1:nreg
        rec = read_record(f)
        tab = parse_defaulted_line(rec, tdims)
        # TODO: Last entry here is API related, should have a unit added.
        swap_unit_system_axes!(tab, units, (:pressure, :u_rs, :id))
        push!(viscref, tab)
    end
    parser_message(cfg, outer_data, "VISCREF", PARSER_PARTIAL_SUPPORT)
    data["VISCREF"] = viscref
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Val{:ROCKTAB})
    nrock = outer_data["RUNSPEC"]["ROCKCOMP"][2]
    tables = parse_region_matrix_table(f, nrock)
    for tab in tables
        for i in axes(tab, 1)
            tab[i, 1] = swap_unit_system(tab[i, 1], units, :pressure)
        end
    end
    data["ROCKTAB"] = tables
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:SPECHEAT})
    nreg = number_of_tables(outer_data, :pvtnum)
    speacheat = parse_region_matrix_table(f, nreg)
    for tab in speacheat
        swap_unit_system_axes!(tab, units, (:relative_temperature, :mass_heat_capacity, :mass_heat_capacity, :mass_heat_capacity))
    end
    data["SPECHEAT"] = speacheat
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:SPECROCK})
    nreg = number_of_tables(outer_data, :satnum)
    specrock = parse_region_matrix_table(f, nreg)
    for tab in specrock
        rec = read_record(f)
        swap_unit_system_axes!(tab, units, (:relative_temperature, :mass_heat_capacity))
    end
    data["SPECROCK"] = specrock
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:WATVISCT}, Val{:OILVISCT}})
    k = unpack_val(v)
    nreg = number_of_tables(outer_data, :pvtnum)
    visct = parse_region_matrix_table(f, nreg)
    for tab in visct
        swap_unit_system_axes!(tab, units, (:relative_temperature, :viscosity))
    end
    data["$k"] = visct
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:WATDENT})
    nreg = number_of_tables(outer_data, :pvtnum)
    watdent = []
    uids = (:absolute_temperature, :thermal_expansion_c1, :thermal_expansion_c2)
    tdims = defaults_for_unit(units.from, uids, metric = [293.15, 3.0e-4, 3.0e-6])
    for tab in 1:nreg
        rec = read_record(f)
        tab = parse_defaulted_line(rec, tdims)
        swap_unit_system_axes!(tab, units, uids)
        push!(watdent, tab)
    end
    data["WATDENT"] = watdent
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ROCK})
    tdims = [NaN, NaN, NaN, NaN, NaN, NaN]
    utypes = [:pressure, :compressibility, :compressibility, :compressibility, :id, :id]
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

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:DIFFC})
    parser_message(cfg, outer_data, "DIFFC", PARSER_MISSING_SUPPORT)
    nreg = number_of_tables(outer_data, :pvtnum)
    for i = 1:nreg
        rec = read_record(f)
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:COMPS})
    rec = read_record(f)
    ncomp = only(parse_defaulted_line(rec, [0]))
    data["COMPS"] = ncomp
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{
            Val{:KRW},
            Val{:KRWX},
            Val{Symbol(":KRWX-")},
            Val{:KRWY},
            Val{Symbol(":KRWY-")},
            Val{:KRWZ},
            Val{Symbol(":KRWZ-")},
            Val{:KRWR},
            Val{:KRWRX},
            Val{Symbol(":KRWRX-")},
            Val{:KRWRY},
            Val{Symbol(":KRWRY-")},
            Val{:KRWRZ},
            Val{Symbol(":KRWRZ-")},
            }
        )
    k = unpack_val(v)
    parser_message(cfg, outer_data, "$k", PARSER_JUTULDARCY_MISSING_SUPPORT)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, unit = :id)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:SCALECRS})
    rec = read_record(f)
    scale = only(parse_defaulted_line(rec, ["NO"]))
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


function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:DENSITY})
    tdims = [NaN, NaN, NaN]
    nreg = number_of_tables(outer_data, :pvtnum)
    out = []
    for i = 1:nreg
        rec = read_record(f)
        t = parse_defaulted_line(rec, tdims)
        swap_unit_system!(t, units, :density)
        push!(out, t)
    end
    data["DENSITY"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Union{Val{:RSCONST}, Val{:RSCONSTT}})
    rec = read_record(f)
    # TODO: This is missing units.
    tdims = [NaN, NaN]
    parsed = parse_defaulted_line(rec, tdims, required_num = length(tdims), keyword = "RSCONST")
    parser_message(cfg, outer_data, "RSCONST", PARSER_PARTIAL_SUPPORT)
    data["RSCONST"] = parsed
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:FILLEPS})
    data["FILLEPS"] = true
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ROCKOPTS})
    rec = read_record(f)
    tdims = ["PRESSURE", "NOSTORE", "PVTNUM", "DEFLATION"]
    parsed = parse_defaulted_line(rec, tdims)
    parser_message(cfg, outer_data, "ROCKOPTS", PARSER_JUTULDARCY_MISSING_SUPPORT)
    data["ROCKOPTS"] = parsed
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:AQUTAB})
    num = outer_data["RUNSPEC"]["AQUDIMS"][3]-1
    for i in 1:num
        skip_record(f)
    end
    parser_message(cfg, outer_data, "AQUTAB", PARSER_MISSING_SUPPORT)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:AQUCT})
    skip_record(f)
    parser_message(cfg, outer_data, "AQUCT", PARSER_MISSING_SUPPORT)
end


function parse_keyword!(data, outer_data, units, cfg, f, v::Val{:SWATINIT})
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, unit = unit_type(k))
end

function unit_type(::Val{:SWATINIT})
    return :id
end

const DIFFUSION_TYPE = Union{Val{:DIFCCOG}, Val{:DIFFCOIL}, Val{:DIFFCGAS}, Val{:DIFFCWAT}, Val{:DIFFCWG}}

function parse_keyword!(data, outer_data, units, cfg, f, val::DIFFUSION_TYPE)
    k = unpack_val(val)
    # TODO: Units.
    n = compositional_number_of_components(outer_data)
    out = zeros(n)
    val = parse_deck_vector(f)
    nv = length(val)
    @assert nv <= n "$k has more entries ($nv) than components ($n)"
    out[1:nv] = val
    if !all(isequal(0), out)
        parser_message(cfg, outer_data, "$k", PARSER_JUTULDARCY_MISSING_SUPPORT)
    end
    data["$k"] = out
end
