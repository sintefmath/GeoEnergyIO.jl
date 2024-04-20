"""
    mesh_from_grid_section(f, actnum = missing)

Generate a Jutul unstructured mesh from a grid section. The input arugment `f`
can be one of the following:

 - An already parsed complete data file read using `parse_data_file`.
   The "GRID" field will be used.
 - A parsed "GRID" section from `parse_grdecl_file`.
 - The file-name of a `.GRDECL` file to be parsed before processing.

Optionally the `actnum` can be specified separately. The `actnum` should have
equal length to the number of logical cells in the grid with true/false
indicating if a cell is to be included in the processed mesh.
"""
function mesh_from_grid_section(f, actnum = missing)
    if f isa String
        f = InputParser.parse_grdecl_file(f)
    end
    f::AbstractDict
    if haskey(f, "GRID")
        grid = f["GRID"]
    else
        grid = f
    end
    if ismissing(actnum)
        actnum = get_effective_actnum(grid)
    end
    if haskey(grid, "COORD")
        G = mesh_from_zcorn_and_coord(grid, actnum = actnum)
    else
        G = mesh_from_dxdydz_and_tops(grid, actnum = actnum)
    end
    if haskey(grid, "FAULTS")
        mesh_add_fault_tags!(G, grid["FAULTS"])
    end
    return G
end

function mesh_from_zcorn_and_coord(grid; actnum = get_effective_actnum(grid))
    cartdims = grid["cartDims"]
    nnc = get(grid, "NNC", missing)
    coord = grid["COORD"]
    zcorn = grid["ZCORN"]
    primitives = cpgrid_primitives(coord, zcorn, cartdims, actnum = actnum)
    G = grid_from_primitives(primitives, nnc = nnc)
    return G
end

function mesh_from_dxdydz_and_tops(grid; actnum = get_effective_actnum(grid))
    nnc = get(grid, "NNC", missing)
    cartdims = grid["cartDims"]
    nx, ny, nz = cartdims
    function meshgrid_section(k)
        haskey(grid, k) || throw(ArgumentError("Section GRID must have $k section when using DX/DY/DZ/TOPS format."))
        return reshape(grid[k], cartdims)
    end
    ismissing(nnc) || length(nnc) == 0 || throw(ArgumentError("NNC is not supported together with DX/DY/DZ/TOPS mesh."))
    @warn "DX+DY+DZ+TOPS format is only supported if all cells are equally sized and at same TOPS depth. If you get an error, this is the cause."
    # @assert all(actnum)
    DX = meshgrid_section("DX")
    dx = vec(DX[:, 1, 1])
    for i in axes(DX, 1)
        for j in axes(DX, 2)
            for k in axes(DX, 3)
                @assert DX[i, j, k] ≈ DX[i, 1, 1]
            end
        end
    end
    DY = meshgrid_section("DY")
    dy = vec(DY[1, :, 1])
    for i in axes(DY, 1)
        for j in axes(DY, 2)
            for k in axes(DY, 3)
                @assert DY[i, j, k] ≈ DY[1, j, 1]
            end
        end
    end
    DZ = meshgrid_section("DZ")
    dz = vec(DZ[1, 1, :])
    for i in axes(DZ, 1)
        for j in axes(DZ, 2)
            for k in axes(DZ, 3)
                @assert DZ[i, j, k] ≈ DZ[1, 1, k]
            end
        end
    end
    TOPS = meshgrid_section("TOPS")
    tops = TOPS[:, :, 1]
    x_top, nx = cell_centers_from_deltas(dx)
    y_top, ny = cell_centers_from_deltas(dy)
    if nx == 1 && ny == 1
        I_tops = (x, y) -> only(tops)
    elseif nx == 1
        I_y = LinearInterpolant(Y_top, vec(tops))
        I_tops = (x, y) -> I_y(y)
    elseif ny == 1
        I_x = LinearInterpolant(x_top, vec(tops))
        I_tops = (x, y) -> I_x(x)
    else
        I_tops = BilinearInterpolant(x_top, y_top, tops)
    end
    G = CartesianMesh(cartdims, (dx, dy, dz))
    # We always want to return an unstructured mesh.
    G = UnstructuredMesh(G, z_is_depth = true)
    for i in eachindex(G.node_points)
        node = G.node_points[i]
        G.node_points[i] += [0.0, 0.0, I_tops(node[1], node[2])]
    end
    if !all(actnum)
        active_cells = findall(x -> x > 0, vec(actnum))
        G = extract_submesh(G, active_cells)
    end
    return G
end

function cell_centers_from_deltas(dx, x0 = 0.0)
    nx = length(dx)
    x = zeros(nx)
    x[1] = dx[1]/2.0 + x0
    for i in 2:nx
        x[i] = x[i-1] + dx[i]
    end
    return (x, nx)
end
