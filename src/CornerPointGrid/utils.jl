function ijk_to_linear(i, j, k, dims)
    nx, ny, nz = dims
    return (k-1)*nx*ny + (j-1)*nx + i
end

function ij_to_linear(i, j, dims)
    nx, ny = dims
    return (j-1)*nx + i
end

function linear_to_ijk(ix, dims)
    nx, ny, nz = dims
    linear_index = ix
    x = mod(linear_index - 1, nx) + 1
    y = mod((linear_index - x) ÷ nx, ny) + 1
    leftover = (linear_index - x - (y-1)*nx)
    z = (leftover ÷ (nx*ny)) + 1
    return (x, y, z)
end

function get_line(coord, i, j, nx, ny)
    ix = ijk_to_linear(i, j, 1, (nx, ny, 1))
    T = SVector{3, eltype(coord)}
    x1 = T(coord[ix, 1], coord[ix, 2], coord[ix, 3])
    x2 = T(coord[ix, 4], coord[ix, 5], coord[ix, 6])

    return (x1, x2)
end

function interp_coord(line::NamedTuple, z)
    if line.equal_points
        x = line.x1
        T = eltype(x)
        pt = SVector{3, T}(x[1], x[2], z)
    else
        pt = interp_coord(line.x1, line.x2, z)
    end
    return pt
end

function interp_coord(p0::SVector{3, T}, p1::SVector{3, T}, z::V) where {T<:Real, V<:Real}
    z0 = p0[3]
    z1 = p1[3]
    if z0 ≈ z1 
        # Coinciding corner points. Just return the point and hope the pillar is
        # inactive.
        interp_pt = p0
    else
        weight = (z - z0)/(z1 - z0)
        interp_pt = p0 .+ weight.*(p1 .- p0)
        z_pt = interp_pt[3]
        if isfinite(z_pt) && !isapprox(z_pt, z, atol = 1e-8) 
            @warn "Possibly malformed COORD: Expected interpolated value $z, but was $(interp_pt[3]) != $z"
        end
    end
    return interp_pt
end

"""
    get_corner_index(cell, corner::NTuple, dims)

Index into ZCORN for a cell (linear index or `(i, j, k)`) and a corner
`(i_upper, j_upper, k_upper)`, with each corner offset equal to zero or one.
"""
function get_corner_index(cell, corner::NTuple, dims)
    if cell isa Integer
        i, j, k = linear_to_ijk(cell, dims)
    else
        i, j, k = cell
    end
    nx, ny, nz = dims
    di, dj, dk = corner
    return LinearIndices((2nx, 2ny, 2nz))[2i-1+di, 2j-1+dj, 2k-1+dk]
end

function corner_index(cell, corner::NTuple, dims)
    Base.depwarn("corner_index is deprecated and uses (j, i, k) corner offsets; use get_corner_index with (i, j, k) offsets instead.", :corner_index)
    return get_corner_index(cell, (corner[2], corner[1], corner[3]), dims)
end

function cell_corners(g, cell, dims = Tuple(g["cartDims"]), coord = reshape(g["COORD"], 6, :)')
    if cell isa Integer
        ijk = linear_to_ijk(cell, dims)
    else
        ijk = cell
    end
    nx, ny, = dims
    zcorn = g["ZCORN"]
    T = promote_type(eltype(g["COORD"]), eltype(zcorn))
    return SVector{8, SVector{3, T}}(ntuple(8) do n
        i, j, k = (n-1)%2, ((n-1)÷2)%2, (n-1)÷4
        line = get_line(coord, ijk[1]+i, ijk[2]+j, nx+1, ny+1)
        z = zcorn[get_corner_index(ijk, (i, j, k), dims)]
        return interp_coord((x1 = line[1], x2 = line[2], equal_points = line[1] ≈ line[2]), z)
    end)
end

"""Volume of a trilinear hexahedron, with corners ordered as `1 + i + 2j + 4k`."""
function cell_volume(corners)
    # Two Gauss points per direction integrate the Jacobian determinant exactly.
    a = (1 - inv(sqrt(3.0)))/2
    volume = zero(eltype(first(corners)))
    origin = first(corners)
    for u in (a, 1-a), v in (a, 1-a), w in (a, 1-a)
        u_weights, v_weights, w_weights = (1-u, u), (1-v, v), (1-w, w)
        du = dv = dw = zero(origin)
        for k in 0:1, j in 0:1, i in 0:1
            p = corners[1+i+2j+4k] - origin
            fu, fv, fw = u_weights[i+1], v_weights[j+1], w_weights[k+1]
            du += (2i-1)*fv*fw*p
            dv += fu*(2j-1)*fw*p
            dw += fu*fv*(2k-1)*p
        end
        volume += dot(du, cross(dv, dw))
    end
    return abs(volume)/8
end

function get_effective_actnum(g)
    if haskey(g, "ACTNUM")
        actnum = copy(g["ACTNUM"])
    else
        actnum = fill(true, g["cartDims"])
    end
    actnum, modified = handle_zero_effective_porosity!(actnum, g)
    return (actnum, modified)
end

function handle_zero_effective_porosity!(actnum, g)
    minpv = get(g, "MINPV", 1e-6)
    minporv = get(g, "MINPORV", 1e-6)
    minpv = max(minpv, minporv)
    if haskey(g, "MINPVV")
        minpv_for_cell = i -> max(g["MINPVV"][i], minpv)
    else
        minpv_for_cell = i -> minpv
    end
    return handle_zero_effective_porosity!(actnum, g, minpv, minpv_for_cell)
end

function handle_zero_effective_porosity!(actnum, g, minpv, minpv_for_cell)
    changed = fill(false, size(actnum))
    if haskey(g, "PORV")
        porv = g["PORV"]
        for i in eachindex(actnum)
            if actnum[i]
                pv = porv[i]
                if pv < minpv_for_cell(i)
                    actnum[i] = false
                    changed[i] = true
                end
            end
        end
    else
        poro = get(g, "PORO", fill(1.0, size(actnum)))
        if haskey(g, "ZCORN")
            zcorn = g["ZCORN"]
            coord = reshape(g["COORD"], 6, :)'
            cartdims = g["cartDims"]
        else
            zcorn = coord = cartdims = missing
        end
        # Have to handle zero or negligble porosity.
        if haskey(g, "NTG")
            ntg = g["NTG"]
        else
            ntg = ones(size(actnum))
        end
        deactivate_minpv!(actnum, changed, g, poro, ntg, zcorn, coord, cartdims, minpv)
    end
    return (actnum, changed)
end

function deactivate_minpv!(actnum, changed, g, poro, ntg, zcorn, coord, cartdims, minpv)
    for i in eachindex(actnum)
        if actnum[i]
            vol = zcorn_volume(g, zcorn, coord, cartdims, i)
            pv = poro[i]*ntg[i]*vol
            if pv < minpv
                changed[i] = true
                actnum[i] = false
            end
        end
    end
    return actnum
end

function zcorn_volume(g, zcorn, coord, dims, linear_ix)
    if ismissing(zcorn)
        vol = 1.0
    else
        vol = cell_volume(cell_corners(g, linear_ix, dims, coord))
    end
    return vol
end

function repair_zcorn!(zcorn, cartdims)
    nx, ny, nz = cartdims
    count_fixed = 0
    # Check that cells are not inside the cell below them. If so, set the lower
    # cells upper coordinate to that of the upper cells' lower coordinate.
    for i = 1:nx
        for j = 1:ny
            for k = 1:(nz-1)
                for I1 in (0, 1)
                    for I2 in (0, 1)
                        self = ijk_to_linear(i, j, k, cartdims)
                        next = ijk_to_linear(i, j, k+1, cartdims)
                        ix_upper = get_corner_index(self, (I1, I2, 1), cartdims)
                        ix_lower = get_corner_index(next, (I1, I2, 0), cartdims)
                        z_upper = zcorn[ix_upper]
                        z_lower = zcorn[ix_lower]
                        if z_lower < z_upper
                            zcorn[ix_lower] = z_upper
                            count_fixed += 1
                        end
                    end
                end
            end
        end
    end
    # Traverse from top to bottom If a cell has flipped points (lower corner at
    # a lower depth than the upper corner) we set the upper corner to the depth
    # of the lower corner.
    for i = 1:nx
        for j = 1:ny
            for k = 1:nz
                ix = ijk_to_linear(i, j, k, cartdims)
                # Iterate over all four columns
                for I1 in (0, 1)
                    for I2 in (0, 1)
                        ix_upper = get_corner_index(ix, (I1, I2, 0), cartdims)
                        ix_lower = get_corner_index(ix, (I1, I2, 1), cartdims)
                        z_upper = zcorn[ix_upper]
                        z_lower = zcorn[ix_lower]
                        if z_upper > z_lower
                            zcorn[ix_lower] = z_lower
                            count_fixed += 1
                        end
                    end
                end
            end
        end
    end
    return zcorn
end

function apply_mapaxes!(g, mapaxes)
    apply_mapaxes!(g.node_points, mapaxes)
    return g
end

function apply_mapaxes!(pts::Vector{SVector{N, T}}, mapaxes::AbstractVector) where {T, N}
    length(mapaxes) == 6 || throw(ArgumentError("Expected 6 values in mapaxes, got $(length(mapaxes))"))
    N == 2 || N == 3 || throw(ArgumentError("Expected 2 or 3 dimensions, got $N"))

    function to_norm_3dvec(a, b)
        v = a - b
        return SVector{3, T}(v[1], v[2], 0)./norm(v, 2)
    end
    p1 = mapaxes[1:2]
    p2 = mapaxes[3:4]
    p3 = mapaxes[5:6]

    u1 = to_norm_3dvec(p3, p2)
    u2 = to_norm_3dvec(p1, p2)

    trans_sgn = dot(
        [0.0 0.0 1], cross(u1, u2)
    )
    if trans_sgn < 0.0
        @warn "Negative sign in MAPAXES. Coordinate system may have changed signature. Geometry calculations may produce negative values (e.g. areas/volumes)"
    end
    if N == 3
        p3_3d = SVector{3, T}(p3[1], p3[2], 0)
        for i in eachindex(pts)
            x, y, z = pts[i]
            new_pt = x.*u1 + y.*u2 + p3_3d + SVector{3, T}(0.0, 0.0, z)
            pts[i] = new_pt
        end
    else
        for i in eachindex(pts)
            x, y = pts[i]
            new_pt = x.*u1[1:2] + y.*u2[1:2] + p3[1:2]
        end
        pts[i] = new_pt
    end
    return pts
end
