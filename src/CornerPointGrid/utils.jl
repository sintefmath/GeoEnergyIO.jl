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
    handle_zero_effective_porosity!(actnum, g)
    return actnum
end

function handle_zero_effective_porosity!(actnum, g)
    if haskey(g, "MINPV")
        minpv = g["MINPV"]
    else
        minpv = 1e-6
    end
    added = 0
    active = 0

    if haskey(g, "PORV")
        porv = G["PORV"]
        for i in eachindex(actnum)
            if actnum[i]
                pv = porv[i]
                active += active
                if pv < minpv
                    added += 1
                    actnum[i] = false
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
    return actnum
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
