function parse_and_set_grid_data!(data, outer_data, units, cfg, f, k; unit = :id, T = Float64, default = zero(T))
    bdims = get_boxdims(outer_data)
    cdims = get_cartdims(outer_data)
    vals = parse_grid_vector(f, bdims, T)
    if unit != :id
        vals = swap_unit_system!(vals, units, Val(unit))
    end
    skey = "$k"
    if bdims == cdims
        data[skey] = vals
    else
        if !haskey(data, skey)
            data[skey] = fill(default, cdims)
        end
        d = data[skey]
        @assert size(d) == cdims
        I, J, K = get_box_indices(outer_data)
        d[I, J, K] = vals
    end
end

function finish_current_section!(data, units, cfg, outer_data, ::Val{:GRID})
    if !haskey(data, "MINPV")
        io = IOBuffer("1e-6\n/\n")
        parse_keyword!(data, outer_data, units, cfg, io, Val(:MINPV))
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:GRIDFILE})
    rec = read_record(f)
    tdims = [0, 1];
    data["GRIDFILE"] = parse_defaulted_line(rec, tdims)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Union{Val{:MINPORV}, Val{:MINPV}})
    rec = read_record(f)
    tdims = [1e-6];
    rec = parse_defaulted_line(rec, tdims)
    rec = swap_unit_system!(rec, units, :volume)
    data["MINPV"] = only(rec)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:INIT})
    data["INIT"] = true
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:COORDSYS})
    read_record(f)
    parser_message(cfg, outer_data, "COORDSYS", PARSER_MISSING_SUPPORT)
end

function check_unit(unit_str, units, kw)
    ref = uppercase("$(deck_unit_system_label(units.from))")
    u = uppercase(unit_str)
    if u != ref
        # Commented out due to missing logic (e.g. METRIC should equal METRES)
        # @warn "Unit mismatch in $kw: Was $u but RUNSPEC declared $ref"
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:FILEUNIT})
    rec = strip(only(read_record(f)))
    check_unit(rec, units, "FILEUNIT")
    data["FILEUNIT"] = rec
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:GRIDUNIT})
    rec = read_record(f)
    tdims = ["Default", "MAP"]
    v = parse_defaulted_line(rec, tdims)
    check_unit(v[1], units, "GRIDUNIT")
    data["GRIDUNIT"] = v
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:MAPUNITS})
    rec = read_record(f)
    tdims = ["Default"]
    v = parse_defaulted_line(rec, tdims)
    data["MAPUNITS"] = only(v)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:GDORIENT})
    # TODO: This needs to be handled
    partial_parse!(data, outer_data, units, cfg, f, :GDORIENT)
end

function partial_parse!(data, outer_data, units, cfg, f, k::Symbol)
    rec = read_record(f)
    parser_message(cfg, outer_data, "$k", PARSER_MISSING_SUPPORT)
    data["$k"] = rec
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:MAPAXES})
    rec = parse_deck_vector(f, Float64)
    data["MAPAXES"] = rec
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:COORD})
    coord = parse_deck_vector(f, Float64)
    coord = swap_unit_system_fast!(coord, units, Val(:length))
    data["COORD"] = coord
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ZCORN})
    zcorn = parse_deck_vector(f, Float64)
    zcorn = swap_unit_system_fast!(zcorn, units, Val(:length))
    data["ZCORN"] = zcorn
end

function unit_type(::Union{Val{:COORD}, Val{:ZCORN}})
    return :length
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:PERMX}, Val{:PERMY}, Val{:PERMZ}, Val{:PORV}, Val{:DEPTH}, Val{:MINPVV}})
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, unit = unit_type(k))
end

function unit_type(::Union{Val{:PERMX}, Val{:PERMY}, Val{:PERMZ}})
    return :permeability
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:DIPAZIMUTH}, Val{:DIPANGLE}})
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, unit = unit_type(k))
end

function unit_type(::Union{Val{:DIPAZIMUTH}, Val{:DIPANGLE}})
    return :id
end

const ENDPOINT_TYPE = Union{
    Val{:SWL}, Val{:SGL}, Val{:SWCR}, Val{:SWU}, Val{:SGCR}, Val{:SGU}, Val{:SOWCR}, Val{:SOGCR},
    Val{:ISWL}, Val{:ISGL}, Val{:ISWCR}, Val{:ISWU}, Val{:ISGCR}, Val{:ISGU}, Val{:ISOWCR}, Val{:ISOGCR}
}

function parse_keyword!(data, outer_data, units, cfg, f, v::ENDPOINT_TYPE)
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, unit = unit_type(k))
end

function unit_type(::ENDPOINT_TYPE)
    return :id
end

function keyword_default_value(x::ENDPOINT_TYPE, T::Type)
    @assert T == Float64
    return NaN
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Val{:MULTREGT})
    defaults = [-1, -1, 1.0, "XYZ", "ALL", "M"]
    mreg = []
    while true
        rec = read_record(f)
        if length(rec) == 0
            break
        end
        parsed = parse_defaulted_line(rec, defaults, required_num = 6, keyword = "MULTREGT")
        @assert parsed[6] in ("M", "O", "F")
        if parsed[5] != "ALL"
            parser_message(cfg, outer_data, "MULTREGT", PARSER_JUTULDARCY_PARTIAL_SUPPORT, "Only the \"F\" option is supported in the solvers, not $(parsed[5])")
        end
        push!(mreg, parsed)
    end
    data["MULTREGT"] = mreg
end

const MULTXYZ_TYPE = Union{Val{:MULTX}, Val{:MULTY}, Val{:MULTZ},Val{Symbol("MULTX-")}, Val{Symbol("MULTY-")}, Val{Symbol("MULTZ-")}}

function parse_keyword!(data, outer_data, units, cfg, f, v::MULTXYZ_TYPE)
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, unit = :id, default = 1.0)
end

function unit_type(::MULTXYZ_TYPE)
    return :id
end

const THERMAL_CONDUCTIVITY_TYPE = Union{Val{:THCROCK}, Val{:THCWATER}, Val{:THCGAS}, Val{:THCSOLID}, Val{:THCAVE}}

function parse_keyword!(data, outer_data, units, cfg, f, v::THERMAL_CONDUCTIVITY_TYPE)
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, unit = unit_type(k))
end

function unit_type(::THERMAL_CONDUCTIVITY_TYPE)
    return :rock_conductivity
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Val{:MULTPV})
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, default = 1.0)
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:PRATIO}, Val{:BIOTCOEF}})
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k)
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:YMODULE}})
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, unit = :gigapascal)
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:POELCOEF}, Val{:THELCOEF}, Val{:THERMEXR}, Val{:THCONR}})
    k = unpack_val(v)
    vals = parse_grid_vector(f, get_cartdims(outer_data), Float64)
    parser_message(cfg, outer_data, "$k", PARSER_PARTIAL_SUPPORT)
    data["$k"] = vals
end

const REGION_TYPE = Union{Val{:FIPNUM}, Val{:PVTNUM}, Val{:SATNUM}, Val{:EQLNUM}, Val{:ROCKNUM}, Val{:IMBNUM}, Val{:MULTNUM}, Val{:FIPZON}, Val{:FLUXNUM}, Val{:OPERNUM}, Val{:MULTNUM}, Val{:EOSNUM}}

function parse_keyword!(data, outer_data, units, cfg, f, v::REGION_TYPE)
    k = unpack_val(v)
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, k, T = Int)
end

function unit_type(::REGION_TYPE)
    return :id
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PORO})
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, :PORO)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:NTG})
    parse_and_set_grid_data!(data, outer_data, units, cfg, f, :NTG)
end

function unit_type(::Union{Val{:PORO}, Val{:NTG}})
    return :id
end

function unit_type(::Val{:PORV})
    return :liquid_volume_reservoir
end

function unit_type(::Val{:MINPVV})
    return :liquid_volume_reservoir
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Union{Val{:DX}, Val{:DY}, Val{:DZ}})
    k = unpack_val(v)
    Δ = parse_grid_vector(f, get_cartdims(outer_data), Float64)
    swap_unit_system_fast!(Δ, units, Val(:length))
    data["$k"] = Δ
end

function unit_type(::Union{Val{:DX}, Val{:DY}, Val{:DZ}})
    return :length
end


function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:TOPS})
    tops = parse_deck_vector(f, Float64)
    data["TOPS"] = swap_unit_system!(tops, units, Val(:length))
end

function unit_type(::Val{:TOPS})
    return :length
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:NNC})
    defaults = Union{Int, Float64}[
        -1, -1, -1, -1, -1, -1, # First six are mandatory, 2x I, J, K for pair
        0.0, 0.0, -1, -1, -1, -1, -1, -1, 0.0, NaN, NaN
    ]
    eachunit = fill(:id, 17)
    eachunit[7] = :transmissibility
    eachunit[16] = :area
    eachunit[17] = :permeability

    nnc = []
    while true
        rec = read_record(f)
        if length(rec) == 0
            break
        end
        parsed = parse_defaulted_line(rec, defaults, required_num = 6, keyword = "NNC")
        swap_unit_system_axes!(parsed, units, eachunit)
        push!(nnc, parsed)
    end
    data["NNC"] = nnc
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:DIMENS})
    rec = read_record(f)
    to_int = x -> Parsers.parse(Int, x)
    d = to_int.(filter!(x -> length(x) > 0, split(only(rec), DECK_SPLIT_REGEX)))
    data["DIMENS"] = d
    set_cartdims!(outer_data, d)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:SPECGRID})
    rec = read_record(f)
    tdims = [1, 1, 1, 1, "F"]
    data["SPECGRID"] = parse_defaulted_line(rec, tdims)
    set_cartdims!(outer_data, data["SPECGRID"][1:3])
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:PINCH})
    rec = read_record(f)
    tdims = [0.001, "GAP", Inf, "TOPBOT", "TOP"]
    parser_message(cfg, outer_data, "PINCH", PARSER_JUTULDARCY_PARTIAL_SUPPORT)
    data["PINCH"] = parse_defaulted_line(rec, tdims)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:FAULTS})
    read_record
    tdims = ["NAME", -1, -1, -1, -1, -1, -1, "XYZ_IJK"]
    if !haskey(data, "FAULTS")
        data["FAULTS"] = Dict{String, Any}()
    end
    faults = data["FAULTS"]
    while true
        rec = read_record(f)
        if length(rec) == 0
            break
        end
        parsed = parse_defaulted_line(rec, tdims, required_num = length(tdims), keyword = "FAULTS")
        name = parsed[1]
        flt = (
            i = parsed[2]:parsed[3],
            j = parsed[4]:parsed[5],
            k = parsed[6]:parsed[7],
            direction = parsed[8]
        )
        if haskey(faults, name)
            push!(faults[name], flt)
        else
            faults[name] = [flt]
        end
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:MULTFLT})
    d = "*"
    tdims = [d, 1.0, 1.0]
    faults = outer_data["GRID"]["FAULTS"]
    out = parse_defaulted_group_well(f, tdims, faults);
    if !haskey(data, "MULTFLT")
        data["MULTFLT"] = Dict{String, Tuple{Float64, Float64}}()
    end
    for (name, mul_t, mul_d) in out
        data["MULTFLT"][name] = (mul_t, mul_d)
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:AQUNUM})
    def_and_u = [
        (1, :id), # Aquifer no
        (-1, :id), # I
        (-1, :id), # J
        (-1, :id), # K
        (NaN, :area), # surface area to aquifer
        (NaN, :length), # length of aquifer
        (NaN, :id), # poro of aquifer
        (NaN, :permeability), # perm of aquifer
        (NaN, :length), # depth of aquifer
        (NaN, :pressure), # initial pressure aquifer
        (1, :id), # PVTNUM for aquifer
        (1, :id), # SATNUM for aquifer
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
    data["AQUNUM"] = out
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:AQUCON})
    def_and_u = [
        (1, :id), # Aquifer no
        (-1, :id), # I start
        (-1, :id), # I stop
        (-1, :id), # J start
        (-1, :id), # J stop
        (-1, :id), # K start
        (-1, :id), # K stop
        ("Defaulted", :id), # Face orientation, I+, I-, ...
        (1.0, :id), # Trans multiplier
        (0, :id), # Type of trans calculator to use
        ("NO", :id), # Allow internal aquifer connections
        (1.0, :id), # Unsupported?
        (1.0, :id) # Unsupported?
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
        dir = l[8]
        if length(dir) != 2
            ok = false
        else
            d1, d2 = dir
            ok = d1 in ('I', 'J', 'K') && d2 in ('+', '-')
        end
        if !ok
            throw(ArgumentError("Direction for AQUCON was $dir, must be on the format I/J/K and +-, i.e. I+"))
        end
        swap_unit_system_axes!(l, units, utypes)
        push!(out, l)
    end
    data["AQUCON"] = out
end
