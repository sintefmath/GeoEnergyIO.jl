"""
    read_egrid(path; extra_out=false, units=:si)

Read the main EGRID grid in the dictionary format accepted by
`mesh_from_grid_section`. Coordinates are converted to metres by default;
`units=:native` retains the file's length unit. `extra_out=true` also returns
the ordered `KeywordFile`, including any local grids and NNC arrays.
"""
function read_egrid(path::AbstractString; extra_out = false, units = :si, verbose = false)
    pth = file_path(path, "EGRID")
    if !isfile(pth)
        pth = "$(case_base(path))_GRID.EGRID"
    end
    raw = read_binary(pth)
    haskey(raw, "GRIDHEAD") || throw(ArgumentError("EGRID has no GRIDHEAD"))
    head = raw["GRIDHEAD"]
    length(head) >= 4 || throw(ArgumentError("Truncated GRIDHEAD"))
    head[1] == 1 || throw(ArgumentError("Only corner-point EGRID grids are supported"))
    dims = Tuple(Int.(head[2:4]))
    all(>(0), dims) || throw(ArgumentError("Invalid EGRID dimensions $dims"))
    coord, zcorn = raw["COORD"], raw["ZCORN"]
    nx, ny, nz = dims
    length(coord) == 6*(nx+1)*(ny+1) || throw(ArgumentError("COORD length does not match GRIDHEAD"))
    length(zcorn) == 8*prod(dims) || throw(ArgumentError("ZCORN length does not match GRIDHEAD"))
    actnum = haskey(raw, "ACTNUM") ? raw["ACTNUM"] : ones(Int32, prod(dims))
    length(actnum) == prod(dims) || throw(ArgumentError("ACTNUM length does not match GRIDHEAD"))
    label = haskey(raw, "GRIDUNIT") ? uppercase(first(raw["GRIDUNIT"])) : "METRES"
    factor = grid_length_factor(label)
    units in (:si, :native) || throw(ArgumentError("units must be :si or :native"))
    scale = units == :si ? factor : 1.0
    out = Dict{String, Any}(
        "cartDims" => collect(dims), "SPECGRID" => collect(dims),
        "ACTNUM" => reshape(actnum .!= 0, dims),
        "COORD" => Float64.(coord).*scale, "ZCORN" => Float64.(zcorn).*scale
    )
    for key in ("MAPAXES", "MAPUNITS", "GRIDUNIT", "NNCHEAD", "NNC1", "NNC2")
        haskey(raw, key) && (out[key] = copy(raw[key]))
    end
    if haskey(out, "MAPAXES") && units == :si
        maplabel = haskey(raw, "MAPUNITS") ? first(raw["MAPUNITS"]) : label
        out["MAPAXES"] = Float64.(out["MAPAXES"]).*grid_length_factor(maplabel)
        out["MAPUNITS"] = ["METRES"]
    end
    units == :si && (out["GRIDUNIT"] = ["METRES", ""])
    verbose && println("Read EGRID $dims with $(count(!iszero, actnum)) active cells")
    return extra_out ? (out, raw) : out
end

function grid_length_factor(label)
    label = uppercase(strip(label))
    label in ("METRES", "METERS", "M", "") && return 1.0
    label in ("FEET", "FT") && return 0.3048
    label in ("CM", "CENTIMET") && return 0.01
    throw(ArgumentError("Unknown EGRID length unit '$label'"))
end
