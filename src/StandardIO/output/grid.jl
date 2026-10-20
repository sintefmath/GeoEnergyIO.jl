function grid_dims(data)
    dims = get(data, "cartDims", get(data, "SPECGRID", get(data, "DIMENS", nothing)))
    isnothing(dims) && throw(ArgumentError("Grid requires cartDims, SPECGRID or DIMENS"))
    length(dims) >= 3 || throw(ArgumentError("Grid dimensions require three entries"))
    dims = Tuple(Int.(dims[1:3]))
    all(>(0), dims) || throw(ArgumentError("Grid dimensions must be positive"))
    return dims
end

function rectangular_grid(dx, dy, dz; origin = (0.0, 0.0, 0.0))
    nx, ny, nz = length(dx), length(dy), length(dz)
    xs = origin[1] .+ vcat(0.0, cumsum(dx))
    ys = origin[2] .+ vcat(0.0, cumsum(dy))
    zs = origin[3] .+ vcat(0.0, cumsum(dz))
    coord = Float64[]
    for y in ys, x in xs
        append!(coord, (x, y, first(zs), x, y, last(zs)))
    end
    zcorn = zeros(2*nx, 2*ny, 2*nz)
    for k in 1:nz
        zcorn[:, :, 2*k-1] .= zs[k]
        zcorn[:, :, 2*k] .= zs[k+1]
    end
    return Dict{String, Any}("cartDims" => [nx, ny, nz], "COORD" => coord,
        "ZCORN" => vec(zcorn), "ACTNUM" => trues(nx, ny, nz))
end

# Create a one-metre-wide synthetic row in active-cell order for an unstructured mesh.
fake_grid(n::Integer) = rectangular_grid(ones(n), [1.0], [1.0])

function corner_point_data(data)
    data = haskey(data, "GRID") ? data["GRID"] : data
    haskey(data, "COORD") && return data
    # The deck parser supports separable DX/DY/DZ and DXV/DYV/DZV grids.
    dims = grid_dims(data)
    deltas = map(enumerate(("DX", "DY", "DZ"))) do (axis, name)
        if haskey(data, name*"V")
            v = vec(data[name*"V"])
        else
            a = reshape(data[name], dims)
            indices = ntuple(d -> d == axis ? Colon() : 1, 3)
            v = vec(a[indices...])
            for ix in CartesianIndices(a)
                a[ix] ≈ v[ix[axis]] || throw(ArgumentError("Nonseparable $name cannot be converted to EGRID"))
            end
        end
        length(v) == dims[axis] || throw(ArgumentError("$name length does not match dimensions"))
        return v
    end
    out = rectangular_grid(deltas...)
    tops = get(data, "TOPS", [0.0])
    if all(==(first(tops)), tops)
        out["COORD"][3:3:end] .+= first(tops)
        out["ZCORN"] .+= first(tops)
    else
        # Match the deck mesh's interpolation of top depths onto pillars.
        nx, ny, nz = dims
        x = cumsum(deltas[1]) .- deltas[1]./2
        y = cumsum(deltas[2]) .- deltas[2]./2
        top = reshape(tops[1:nx*ny], nx, ny)
        interp = nx == 1 ? ((a,b) -> Jutul.LinearInterpolant(y, vec(top))(b)) :
            ny == 1 ? ((a,b) -> Jutul.LinearInterpolant(x, vec(top))(a)) : Jutul.BilinearInterpolant(x, y, top)
        heights = zeros(nx+1, ny+1)
        c = reshape(out["COORD"], 6, nx+1, ny+1)
        for j in 1:ny+1, i in 1:nx+1
            h = interp(c[1,i,j], c[2,i,j])
            heights[i,j] = h
            c[3,i,j] += h
            c[6,i,j] += h
        end
        z = reshape(out["ZCORN"], 2*nx, 2*ny, 2*nz)
        for k in 1:2*nz, j in 1:2*ny, i in 1:2*nx
            z[i,j,k] += heights[div(i,2)+1, div(j,2)+1]
        end
    end
    out["ACTNUM"] = get(data, "ACTNUM", out["ACTNUM"])
    return out
end

"""
    write_egrid(data, path; units=:metric, input_units=:si)

Write a deck GRID dictionary or a whole deck to EGRID. Deck geometry uses SI
units by default. Pass a raw `KeywordFile` to `write_binary` to preserve local
grids and other records.
"""
function write_egrid(data::AbstractDict, path::AbstractString; units = :metric, input_units = :si, endian = :big)
    data = corner_point_data(data)
    dims = grid_dims(data)
    nx, ny, nz = dims
    coord, zcorn = vec(data["COORD"]), vec(data["ZCORN"])
    length(coord) == 6*(nx+1)*(ny+1) || throw(ArgumentError("Invalid COORD length"))
    length(zcorn) == 8*prod(dims) || throw(ArgumentError("Invalid ZCORN length"))
    actnum = vec(get(data, "ACTNUM", trues(dims)))
    length(actnum) == prod(dims) || throw(ArgumentError("Invalid ACTNUM length"))
    input_units in (:si, :native) || throw(ArgumentError("input_units must be :si or :native"))
    code = unit_code(units)
    factor = input_units == :si ? unit_system(units).length : 1.0
    filehead = zeros(Int32, 100)
    filehead[1:7] = [3, 2007, 0, 0, 0, 0, 1]
    gridhead = zeros(Int32, 100)
    gridhead[1:4] = [1, nx, ny, nz]
    label = code == 2 ? "FEET" : code == 3 ? "CM" : "METRES"
    kws = BinaryKeyword[BinaryKeyword("FILEHEAD", filehead)]
    if haskey(data, "MAPAXES")
        push!(kws, BinaryKeyword("MAPUNITS", [label]))
        push!(kws, BinaryKeyword("MAPAXES", Float32.(data["MAPAXES"]./factor)))
    end
    append!(kws, [BinaryKeyword("GRIDUNIT", [label, ""]),
        BinaryKeyword("GRIDHEAD", gridhead), BinaryKeyword("COORD", Float32.(coord./factor)),
        BinaryKeyword("ZCORN", Float32.(zcorn./factor)), BinaryKeyword("ACTNUM", Int32.(actnum .!= 0)),
        BinaryKeyword("ENDGRID", Int32[])])
    for key in ("NNCHEAD", "NNC1", "NNC2")
        haskey(data, key) && push!(kws, BinaryKeyword(key, data[key]))
    end
    return write_binary(output_path(path, "EGRID"), kws; endian)
end

function write_egrid(domain::Jutul.DataDomain, data::AbstractDict, path::AbstractString; kw...)
    return write_egrid(Jutul.physical_representation(domain), data, path; kw...)
end
function write_egrid(mesh::Jutul.UnstructuredMesh, data::AbstractDict, path::AbstractString; kw...)
    grid = Dict{String, Any}(corner_point_data(data))
    if mesh.structure isa CartesianIndex
        mask = falses(prod(grid_dims(grid)))
        mask[mesh.cell_map] .= true
        grid["ACTNUM"] = mask
    end
    return write_egrid(grid, path; kw...)
end
