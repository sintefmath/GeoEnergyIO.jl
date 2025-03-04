"""
    cpgrid_from_horizons(X, Y, depths)
    cpgrid_from_horizons(X, Y, depths, (100, 100))
    cpgrid_from_horizons(X, Y, depths, sz = missing;
        layer_width = 1,
        transforms = [(x, y, z, x_c, y_c, i, j, k) -> z],
        xy_transform = (x, y, i, j, z_t, z_b) -> (x, y, x, y)
    )

Create a CornerPointGrid from a set of horizons. The horizons are given as a set
of 2D arrays, where each array represents the depth of a horizon at each point
in the grid. The horizons must be the same size and will be used to create the
top and bottom of each cell in the grid. At least two horizons must be provided,
one for the top and one for the bottom of the grid, and additional horizons can
be provided. If horizons intersect, the cells will be pinched so that the lowest
horizon is preserved.

The grid will be created with the given `X` and `Y` coordinates which are
vectors/ranges of equal length to the number of rows and columns in the depths
arrays. The `sz` argument can be used to resample the grid to a different size
in the I/J directions. If `sz` is not provided, the grid will have the same size
as the horizons.

# Keyword arguments

- `layer_width`: Number of cells inside each layer. Can be a single integer or
  an array of integers with the same length as the number of horizons/depths
  minus one. Default is 1, i.e. that each layer has one cell in the vertical
  direction.
- `transforms`: A function or an array of functions that can be used to modify
  the depth of each cell. The function(s) should take the following arguments:
  `x`, `y`, `z`, `x_c`, `y_c`, `i`, `j`, `k`, where `x`, `y` and `z` are the
  coordinates of the point to be modified, `x_c` and `y_c` are the coordinates
  of the cell center that the point belongs to, `i` and `j` are the indices of
  the cell in the I/J directions, and `k` is the index of the cell in the K
  direction. The function(s) should return the new depth of the point.
- `xy_transform`: A function that can be used to modify the X and Y coordinates
  of each pillar. The function should take the following arguments: `x`, `y`,
  `i`, `j`, `z_t`, `z_b`, where `x` and `y` are the original X and Y coordinates
  of the line, `i` and `j` are the indices of the line in the I/J directions,
  and `z_t` and `z_b` are the top and bottom depths of the line. The function
  should return the new X and Y coordinates of the line.
"""
function cpgrid_from_horizons(X, Y, depths, sz = missing;
        layer_width = 1,
        transforms = [(x, y, z, x_c, y_c, i, j, k) -> z],
        xy_transform = (x, y, i, j, z_t, z_b) -> (x, y, x, y)
    )
    if transforms isa Function
        transforms = [transforms]
    end
    num_layers = length(depths)-1
    if layer_width isa Int
        nz_layer = fill(layer_width, num_layers)
    else
        length(layer_width) == num_layers || throw(ArgumentError("nz must have length $(length(depths)-1)"))
        all(layer_width .> 1) || throw(ArgumentError("nz must be positive for all entries"))
        nz_layer = layer_width
    end
    nz = sum(nz_layer) + 1
    X = collect(X)
    Y = collect(Y)
    nx = length(X)
    ny = length(Y)

    length(depths) > 0 || throw(ArgumentError("depths must have at least two elements (top/bottom)"))
    for (i, d) in enumerate(depths)
        size(d) == (nx, ny) || throw(ArgumentError("depths must have size ($nx, $ny), was $(size(d)) for depth #$i"))
    end
    function resample_2d(vals, new_size)
        nx, ny = new_size
        I = get_2d_interpolator(X, Y, vals)
        new_x = range(first(X), last(X), length = nx)
        new_y = range(first(Y), last(Y), length = ny)
        vals = zeros(nx, ny)
        for i in 1:nx
            for j in 1:ny
                vals[i, j] = I(new_x[i], new_y[j])
            end
        end
        return vals
    end
    function resample_1d(vals, n::Int)
        I = get_1d_interpolator(vals, vals)
        new_x = range(first(vals), last(vals), length = n)
        return I.(new_x)
    end
    if !ismissing(sz)
        length(sz) == 2 || throw(ArgumentError("sz must have length 2"))
        nx, ny = sz
        nx::Int
        ny::Int
        nx > 0 || throw(ArgumentError("sz[1] must be positive"))
        ny > 0 || throw(ArgumentError("sz[2] must be positive"))
        X_new = resample_1d(X, sz[1])
        Y_new = resample_1d(Y, sz[2])
        depths_new = [resample_2d(d, sz) for d in depths]
        # Replace values since they might be captured.
        X = X_new
        Y = Y_new
        depths = depths_new
    end

    coord = zeros(nx*ny, 6)
    for i in 1:nx
        for j in 1:ny
            I = i + (j-1)*nx
            x_t = X[i]
            y_t = Y[j]
            z_t = depths[1][i, j]
            z_b = depths[end][i, j]
            if isnan(z_t) || isnan(z_b)
                z_t = z_b = 0.0
            end
            x_t, y_t, x_b, y_b = xy_transform(x_t, y_t, i, j, z_t, z_b)
            coord[I, 1] = x_t
            coord[I, 2] = y_t
            coord[I, 3] = z_t
            coord[I, 4] = x_b
            coord[I, 5] = y_b
            coord[I, 6] = z_b
        end
    end
    zcorn = zeros((nx-1)*(ny-1)*(nz-1)*8)
    D = (nx-1, ny-1, nz-1)

    k_offset = 0
    actnum = fill(true, nx-1, ny-1, nz-1)
    layer_index = zeros(Int, nx-1, ny-1, nz-1)
    for layerNo in 1:num_layers
        top = depths[layerNo]
        bottom = depths[layerNo+1]
        num_vertical_cells_in_layer = nz_layer[layerNo]
        @. layer_index[:, :, (k_offset+1):(k_offset+num_vertical_cells_in_layer)] = layerNo
        cpgrid_from_horizons_add_layer!(zcorn, actnum, X, Y, top, bottom, D, k_offset, num_vertical_cells_in_layer, transforms)
        k_offset += num_vertical_cells_in_layer
    end
    coord_vec = vec(coord')
    return Dict(
        "COORD" => coord_vec,
        "ZCORN" => zcorn,
        "LAYERNUM" => layer_index,
        "cartDims" => D,
        "ACTNUM" => actnum
    )
end

function cpgrid_from_horizons_add_layer!(zcorn, actnum, X, Y, top, bottom, D, k_offset, num_vertical_cells_in_layer, transforms)
    for k_base in 1:num_vertical_cells_in_layer
        k = k_base + k_offset
        @assert k <= D[3]
        for i in 1:D[1]
            x_cell = (X[i] + X[i+1])/2
            for j in 1:D[2]
                y_cell = (Y[j] + Y[j+1])/2
                cell = ijk_to_linear(i, j, k, D)
                # @info cell
                for i_upper in (0, 1)
                    for j_upper in (0, 1)
                        # Some index issues here (j/i)
                        z_t = top[i+j_upper, j+i_upper]
                        z_d = bottom[i+j_upper, j+i_upper]
                        z_d = max(z_t, z_d)
                        Δz = (z_d - z_t)/num_vertical_cells_in_layer
                        low_ix = corner_index(cell, (i_upper, j_upper, 0), D)
                        hi_ix = corner_index(cell, (i_upper, j_upper, 1), D)

                        z_low = z_t + (k_base-1)*Δz
                        z_high = z_t + k_base*Δz
                        if !isfinite(z_low) || !isfinite(z_high)
                            actnum[i, j, k] = false
                            z_low = z_high = 0.0
                        else
                            x = X[i + j_upper]
                            y = Y[j + i_upper]
                            for F_t in transforms
                                z_low = F_t(x, y, z_low, x_cell, y_cell, i, j, k)
                                z_high = F_t(x, y, z_high, x_cell, y_cell, i, j, k)
                            end
                        end
                        zcorn[low_ix] = z_low
                        zcorn[hi_ix] = z_high
                    end
                end
            end
        end
    end
end
