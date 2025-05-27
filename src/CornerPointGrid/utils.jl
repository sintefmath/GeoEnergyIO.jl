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
    T = SVector{3, Float64}
    x1 = T(coord[ix, 1:3])
    x2 = T(coord[ix, 4:end])

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

function interp_coord(p0::SVector{3, T}, p1::SVector{3, T}, z::T) where T<:Real
    z0 = p0[3]
    z1 = p1[3]
    if z0 ≈ z1 
        # Coinciding corner points. Just return the point and hope the pillar is
        # inactive.
        interp_pt = p0
    else
        weight = (z - z0)/(z1 - z0)
        interp_pt = p0 .+ weight.*(p1 .- p0)
        @assert interp_pt[3] ≈ z "expected $z was $(interp_pt[3]) != $z"
    end
    return interp_pt
end

function corner_index(cell, corner::NTuple, dims)
    # Cell 1 [corner1, corner2], cell 2 [corner1, corner2], ..., cell n [corner1, corner2] repeated for nx in top plane
    # Cell 1 [corner3, corner4], cell 2 [corner3, corner4], ..., cell n [corner3, corner4]
    # Cell 1 [corner5, corner6], cell 2 [corner5, corner6], ..., cell n [corner5, corner6]
    # Cell 1 [corner7, corner8], cell 2 [corner7, corner8], ..., cell n [corner7, corner8]

    if cell isa Int
        i, j, k = linear_to_ijk(cell, dims)
    else
        i, j, k = cell
        cell = ijk_to_linear(i, j, k, cartdims)
    end
    nx, ny, nz = dims
    i_is_upper, j_is_upper, k_is_upper = corner

    j_is_upper, i_is_upper, k_is_upper = corner
    cell_i_offset = 2*(i-1)
    cell_j_offset = 4*nx*(j-1)
    cell_k_offset = 8*nx*ny*(k-1)

    cell_offset = cell_i_offset + cell_j_offset + cell_k_offset

    i_offset = i_is_upper+1
    j_offset = j_is_upper*2*nx
    k_offset = k_is_upper*4*nx*ny

    ijk = i_offset + j_offset + k_offset
    return cell_offset + ijk
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
    if haskey(g, "MINPVV")
        minpv_for_cell = i -> max(g["MINPVV"][i], minpv)
    else
        minpv_for_cell = i -> minpv
    end
    return handle_zero_effective_porosity!(actnum, g, minpv, minpv_for_cell)
end

function handle_zero_effective_porosity!(actnum, g, minpv, minpv_for_cell)
    added = 0
    active = 0
    changed = fill(false, size(actnum))

    if haskey(g, "PORV")
        porv = G["PORV"]
        for i in eachindex(actnum)
            if actnum[i]
                pv = porv[i]
                active += active
                if pv < minpv_for_cell(i)
                    added += 1
                    actnum[i] = false
                    changed[i] = true
                end
            end
        end
    elseif haskey(g, "PORO")
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
        poro = g["PORO"]
        for i in eachindex(actnum)
            if actnum[i]
                vol = zcorn_volume(g, zcorn, coord, cartdims, i)
                pv = poro[i]*ntg[i]*vol
                active += active
                if pv < minpv
                    added += 1
                    actnum[i] = false
                end
            end
        end
    end
    @debug "$added disabled cells out of $(length(actnum)) due to low effective pore-volume."
    return (actnum, changed)
end

function zcorn_volume(g, zcorn, coord, dims, linear_ix)
    if ismissing(zcorn)
        return 1.0
    end
    nx, ny, nz = dims
    i, j, k = linear_to_ijk(linear_ix, dims)

    get_zcorn(I1, I2, I3) = zcorn[corner_index(linear_ix, (I1, I2, I3), dims)]
    get_pair(I, J) = (get_zcorn(I, J, 0), get_zcorn(I, J, 1))
    function pillar_line(I, J)
        x1, x2 = get_line(coord, i+I, j+J, nx+1, ny+1)
        return (x1 = x1, x2 = x2, equal_points = false)
    end

    function interpolate_line(I, J, L)
        pl = pillar_line(I, J)
        return interp_coord(pl, L)
    end

    l_11, t_11 = get_pair(0, 0)
    l_12, t_12 = get_pair(0, 1)
    l_21, t_21 = get_pair(1, 0)
    l_22, t_22 = get_pair(1, 1)

    pt_11 = interpolate_line(0, 0, l_11)
    pt_12 = interpolate_line(0, 1, l_12)
    pt_21 = interpolate_line(1, 0, l_21)
    pt_22 = interpolate_line(1, 1, l_22)


    A_1 = norm(cross(pt_21 - pt_11, pt_12 - pt_11), 2)
    A_2 = norm(cross(pt_21 - pt_22, pt_12 - pt_22), 2)
    area = (A_1 + A_2)/2.0

    d_11 = t_11 - l_11
    d_12 = t_12 - l_12
    d_21 = t_21 - l_21
    d_22 = t_22 - l_22

    d_avg = 0.25*(d_11 + d_12 + d_21 + d_22)
    return d_avg*area
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
                        ix_upper = corner_index(self, (I1, I2, 1), cartdims)
                        ix_lower = corner_index(next, (I1, I2, 0), cartdims)
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
                        ix_upper = corner_index(ix, (I1, I2, 0), cartdims)
                        ix_lower = corner_index(ix, (I1, I2, 1), cartdims)
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
