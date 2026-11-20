struct GridArrayKeyword{K, T} <: SingleRecordKeyword{K}
    default::T
    units::Symbol
    edit_unit::Union{Symbol, Nothing}
    warning::Union{PARSER_WARNING, Nothing}
    endpoint::Bool
end

function GridArrayKeyword{K}(; default = 0.0, units = :id, edit_unit = units, warning = nothing,
        endpoint = false) where K
    return GridArrayKeyword{K, typeof(default)}(default, units, edit_unit, warning, endpoint)
end

keyword_defaults(def::GridArrayKeyword) = def.default
keyword_units(def::GridArrayKeyword) = def.units
keyword_edit_unit(def::GridArrayKeyword) = def.edit_unit
keyword_warning(def::GridArrayKeyword) = def.warning

function parse_keyword!(data, outer_data, units, cfg, f, def::GridArrayKeyword{K, T}) where {K, T}
    report_keyword_warning(cfg, outer_data, def)
    return parse_and_set_grid_data!(data, outer_data, units, cfg, f, K;
        unit = keyword_units(def), T = T, default = keyword_defaults(def))
end

function keyword_default_value(def::GridArrayKeyword, T::Type)
    if def.endpoint
        @assert T == Float64
        return NaN
    end
    return zero(T)
end

const GridLengthKeyword = Union{RecordKeyword{:COORD}, RecordKeyword{:ZCORN},
    RecordKeyword{:DX}, RecordKeyword{:DY}, RecordKeyword{:DZ}, RecordKeyword{:TOPS}}
keyword_edit_unit(def::GridLengthKeyword) = keyword_units(def)

@keyword :GRID (:PERMX, :PERMY, :PERMZ) GridArrayKeyword units = :permeability
@keyword :GRID (:PORV, :MINPVV) GridArrayKeyword units = :liquid_volume_reservoir
@keyword :GRID :DEPTH GridArrayKeyword units = :length
@keyword :GRID (:PORO, :NTG, :DIPAZIMUTH, :DIPANGLE) GridArrayKeyword
@keyword :GRID (
    :SWL, :SGL, :SWCR, :SWU, :SGCR, :SGU, :SOWCR, :SOGCR,
    :ISWL, :ISGL, :ISWCR, :ISWU, :ISGCR, :ISGU, :ISOWCR, :ISOGCR
) GridArrayKeyword endpoint = true
@keyword :GRID (:MULTX, :MULTY, :MULTZ, "MULTX-", "MULTY-", "MULTZ-") GridArrayKeyword default = 1.0
@keyword :GRID :MULTPV GridArrayKeyword default = 1.0 edit_unit = nothing
@keyword :GRID (:THCONR, :THCROCK, :THCWATER, :THCOIL, :THCGAS, :THCSOLID, :THCAVE) GridArrayKeyword units = :rock_conductivity
@keyword :GRID (:PRATIO, :BIOTCOEF) GridArrayKeyword edit_unit = nothing
@keyword :GRID :YMODULE GridArrayKeyword units = :gigapascal edit_unit = nothing
@keyword :REGIONS (
    :FIPNUM, :PVTNUM, :SATNUM, :EQLNUM, :ROCKNUM, :IMBNUM, :MULTNUM, :FIPZON, :OPERNUM, :EOSNUM
) GridArrayKeyword default = 0
@keyword :REGIONS :FLUXNUM GridArrayKeyword default = 0 warning = PARSER_JUTULDARCY_MISSING_SUPPORT

@keyword :GRID :INIT FlagKeyword

function parse_and_set_grid_data!(data, outer_data, units, cfg, f, k; unit = :id, T = Float64, default = zero(T))
    bdims = Tuple(get_boxdims(outer_data))
    cdims = Tuple(get_cartdims(outer_data))
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
        io = IOBuffer("/\n")
        parse_keyword!(data, outer_data, units, cfg, io, Val(:MINPV))
    end
end

@keyword :GRID :GRIDFILE RecordKeyword defaults = [0, 1]

@keyword :GRID (:MINPORV, :MINPV) RecordKeyword defaults = [1e-6] units = :volume

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordKeyword{:MINPORV}, RecordKeyword{:MINPV}})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    rec = parse_defaulted_line(rec, tdims)
    rec = swap_unit_system!(rec, units, keyword_units(definition))
    data["MINPV"] = only(rec)
end

@keyword :GRID :COORDSYS RecordKeyword support = :ignored warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:COORDSYS})
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

@keyword :GRID :FILEUNIT RecordKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:FILEUNIT})
    rec = strip(only(read_record(f)))
    check_unit(rec, units, "FILEUNIT")
    data["FILEUNIT"] = rec
end

@keyword :GRID :GRIDUNIT RecordKeyword defaults = ["Default", "MAP"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:GRIDUNIT})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    v = parse_defaulted_line(rec, tdims)
    check_unit(v[1], units, "GRIDUNIT")
    data["GRIDUNIT"] = v
end

@keyword :GRID :MAPUNITS RecordKeyword defaults = ["Default"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:MAPUNITS})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    v = parse_defaulted_line(rec, tdims)
    data["MAPUNITS"] = only(v)
end

@keyword :GRID :GDORIENT RecordKeyword support = :raw warning = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:GDORIENT})
    # TODO: This needs to be handled
    partial_parse!(data, outer_data, units, cfg, f, :GDORIENT)
end

function partial_parse!(data, outer_data, units, cfg, f, k::Symbol)
    rec = read_record(f)
    parser_message(cfg, outer_data, "$k", PARSER_MISSING_SUPPORT)
    data["$k"] = rec
end

@keyword :GRID :MAPAXES RecordKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:MAPAXES})
    rec = parse_deck_vector(f, Float64)
    data["MAPAXES"] = rec
end

@keyword :GRID :COORD RecordKeyword units = :length

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:COORD})
    coord = parse_deck_vector(f, Float64)
    coord = swap_unit_system_fast!(coord, units, Val(keyword_units(definition)))
    data["COORD"] = coord
end

@keyword :GRID :ZCORN RecordKeyword units = :length

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:ZCORN})
    zcorn = parse_deck_vector(f, Float64)
    zcorn = swap_unit_system_fast!(zcorn, units, Val(keyword_units(definition)))
    data["ZCORN"] = zcorn
end

@keyword :GRID :MULTREGT RecordsKeyword defaults = [-1, -1, 1.0, "XYZ", "ALL", "M"] warning = PARSER_JUTULDARCY_PARTIAL_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:MULTREGT})
    defaults = keyword_defaults(definition)
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

@keyword :GRID (:POELCOEF, :THELCOEF, :THERMEXR) RecordKeyword support = :partial warning = PARSER_PARTIAL_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordKeyword{:POELCOEF}, RecordKeyword{:THELCOEF}, RecordKeyword{:THERMEXR}})
    k = keyword_name(definition)
    vals = parse_grid_vector(f, get_cartdims(outer_data), Float64)
    parser_message(cfg, outer_data, "$k", PARSER_PARTIAL_SUPPORT)
    data["$k"] = vals
end

@keyword :GRID (:DX, :DY, :DZ) RecordKeyword units = :length

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordKeyword{:DX}, RecordKeyword{:DY}, RecordKeyword{:DZ}})
    k = keyword_name(definition)
    Δ = parse_grid_vector(f, get_cartdims(outer_data), Float64)
    swap_unit_system_fast!(Δ, units, Val(keyword_units(definition)))
    data["$k"] = Δ
end

@keyword :GRID (:DXV, :DYV, :DZV) RecordKeyword units = :length

function parse_keyword!(data, outer_data, units, cfg, f,
        definition::Union{RecordKeyword{:DXV}, RecordKeyword{:DYV}, RecordKeyword{:DZV}})
    k = keyword_name(definition)
    Δ = parse_deck_vector(f, Float64)
    swap_unit_system_fast!(Δ, units, Val(keyword_units(definition)))
    data["$k"] = Δ
end

@keyword :GRID :TOPS RecordKeyword units = :length

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:TOPS})
    tops = parse_deck_vector(f, Float64)
    data["TOPS"] = swap_unit_system!(tops, units, Val(keyword_units(definition)))
end

@keyword :GRID :NNC RecordsKeyword defaults = Union{Int, Float64}[
        -1, -1, -1, -1, -1, -1, # First six are mandatory, 2x I, J, K for pair
        0.0, 0.0, -1, -1, -1, -1, -1, -1, 0.0, NaN, NaN
    ] units = (:id, :id, :id, :id, :id, :id, :transmissibility, :id, :id, :id, :id, :id, :id, :id, :id, :area, :permeability)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:NNC})
    defaults = keyword_defaults(definition)
    eachunit = keyword_units(definition)

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

@keyword :GRID :DIMENS RecordKeyword

function parse_keyword!(data, outer_data, units, cfg, f, ::RecordKeyword{:DIMENS})
    rec = read_record(f)
    to_int = x -> Parsers.parse(Int, x)
    d = to_int.(filter!(x -> length(x) > 0, split(only(rec), DECK_SPLIT_REGEX)))
    data["DIMENS"] = d
    set_cartdims!(outer_data, d)
end

@keyword :GRID :SPECGRID RecordKeyword defaults = [1, 1, 1, 1, "F"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:SPECGRID})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    data["SPECGRID"] = parse_defaulted_line(rec, tdims)
    set_cartdims!(outer_data, data["SPECGRID"][1:3])
end

@keyword(:GRID, :PINCH, RecordKeyword,
    defaults = [0.001, "GAP", Inf, "TOPBOT", "TOP"],
    units = (:length, :id, :length, :id, :id),
    warning = PARSER_JUTULDARCY_PARTIAL_SUPPORT,
)

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordKeyword{:PINCH})
    rec = read_record(f)
    tdims = keyword_defaults(definition)
    parser_message(cfg, outer_data, "PINCH", PARSER_JUTULDARCY_PARTIAL_SUPPORT)
    parsed = parse_defaulted_line(rec, tdims)
    swap_unit_system_axes!(parsed, units, keyword_units(definition))
    data["PINCH"] = parsed
end

@keyword :GRID :FAULTS RecordsKeyword defaults = ["NAME", -1, -1, -1, -1, -1, -1, "XYZ_IJK"]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:FAULTS})
    tdims = keyword_defaults(definition)
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

@keyword :GRID :MULTFLT RecordsKeyword defaults = ["*", 1.0, 1.0]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:MULTFLT})
    tdims = keyword_defaults(definition)
    faults = outer_data["GRID"]["FAULTS"]
    out = parse_defaulted_group_well(f, tdims, faults);
    if !haskey(data, "MULTFLT")
        data["MULTFLT"] = Dict{String, Tuple{Float64, Float64}}()
    end
    for (name, mul_t, mul_d) in out
        data["MULTFLT"][name] = (mul_t, mul_d)
    end
end

@keyword :GRID :AQUNUM RecordsKeyword fields = [
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

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:AQUNUM})
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
    data["AQUNUM"] = out
end

@keyword :GRID :AQUCON RecordsKeyword fields = [
    (1, :id), # Aquifer no
    (1, :id), # I start
    (1, :id), # I stop
    (1, :id), # J start
    (1, :id), # J stop
    (1, :id), # K start
    (1, :id), # K stop
    ("Defaulted", :id), # Face orientation, I+, I-, ...
    (1.0, :id), # Trans multiplier
    (0, :id), # Type of trans calculator to use
    ("NO", :id), # Allow internal aquifer connections
    (1.0, :id), # Unsupported?
    (1.0, :id) # Unsupported?
]

function parse_keyword!(data, outer_data, units, cfg, f, definition::RecordsKeyword{:AQUCON})
    defaults = keyword_defaults(definition)
    utypes = keyword_units(definition)
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
            d1 = uppercase(d1)
            d2 = uppercase(d2)
            ok = d1 in ('I', 'J', 'K') && d2 in ('+', '-')
            l[8] = d1 * d2
        end
        if !ok
            throw(ArgumentError("Direction for AQUCON was $dir, must be on the format I/J/K and +-, i.e. I+"))
        end
        swap_unit_system_axes!(l, units, utypes)
        push!(out, l)
    end
    data["AQUCON"] = out
end
