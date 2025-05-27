"""
    mesh_from_grid_section(f, actnum = missing, repair_zcorn = true, process_pinch = false)

Generate a Jutul unstructured mesh from a grid section. The input arugment `f`
can be one of the following:

 - (1) An already parsed complete data file read using `parse_data_file`. The
   "GRID" field will be used.
 - (2) A parsed "GRID" section from `parse_grdecl_file`.
 - (3) The file-name of a `.GRDECL` file to be parsed before processing.

Optionally the `actnum` can be specified separately. The `actnum` should have
equal length to the number of logical cells in the grid with true/false
indicating if a cell is to be included in the processed mesh.

The additional argument `repair_zcorn` only applies when the grid is defined
using COORD/ZCORN arrays. If set to `true`, the monotonicity of the ZCORN
coordinates in each corner-point pillar will be checked and optionally fixed
prior to mesh construction. Note that if non-monotone ZCORN are fixed, if the
first input argument to this function is an already parsed data structure, the
ZCORN array will be mutated during fixing to avoid a copy.
"""
function mesh_from_grid_section(f; actnum = missing, repair_zcorn = true, process_pinch = true)
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
        actnum, minpv_removed = get_effective_actnum(grid)
    end
    if haskey(grid, "COORD")
        G = mesh_from_zcorn_and_coord(grid,
            actnum = actnum,
            minpv_removed = minpv_removed,
            repair = repair_zcorn,
            process_pinch = process_pinch
        )
    else
        G = mesh_from_dxdydz_and_tops(grid, actnum = actnum)
    end
    # Handle faults
    faults = get(grid, "FAULTS", missing)
    mesh_add_fault_tags!(G, faults)
    return G
end

function mesh_from_grid_section(f, actnum, repair_zcorn = true, process_pinch = true)
    # Backwards compatibility to old interface
    return mesh_from_grid_section(f, actnum = actnum, repair_zcorn = repair_zcorn, process_pinch = process_pinch)
end

function mesh_from_zcorn_and_coord(grid; actnum = missing, minpv_removed = missing, repair = true, process_pinch = true)
    if ismissing(actnum)
        actnum, minpv_removed = get_effective_actnum(grid)
    end
    cartdims = grid["cartDims"]
    nnc = get(grid, "NNC", missing)
    coord = grid["COORD"]
    zcorn = grid["ZCORN"]
    if repair
        repair_zcorn!(zcorn, cartdims)
    end
    primitives = cpgrid_primitives(coord, zcorn, cartdims, actnum = actnum)
    if process_pinch
        pinch = pinch_primitives(grid, minpv_removed)
    else
        pinch = missing
    end
    G = grid_from_primitives(primitives, nnc = nnc, pinch = pinch)
    return G
end

function pinch_primitives(grid, minpv_removed)
    pinch = get(grid, "PINCH", [0.001, "GAP", Inf, "TOPBOT", "TOP"])
    if ismissing(minpv_removed)
        minpv_removed = fill(false, size(actnum))
    end
    return (pinch = pinch, minpv_removed = minpv_removed)
end

function mesh_from_dxdydz_and_tops(grid; actnum = get_effective_actnum(grid))
    nnc = get(grid, "NNC", missing)
    cartdims = grid["cartDims"]
    nx, ny, nz = cartdims
    function meshgrid_section(k)
        gvec = grid[k]
        haskey(grid, k) || throw(ArgumentError("Section GRID must have $k section when using DX/DY/DZ/TOPS format."))
        if k == "TOPS" && length(gvec) < nx*ny*nz
            # We only need the top layer - extract this and discard the rest if
            # too little data is provided.
            out = reshape(gvec[1:nx*ny], nx, ny, 1)
        else
            out = reshape(gvec, cartdims)
        end
        return out
    end
    if haskey(grid, "DX")
        DX = meshgrid_section("DX")
        dx = vec(DX[:, 1, 1])
        for i in axes(DX, 1)
            for j in axes(DX, 2)
                for k in axes(DX, 3)
                    @assert DX[i, j, k] ≈ DX[i, 1, 1]
                end
            end
        end
    else
        @assert haskey(grid, "DXV") "Either DX or DXV must be provided in GRID."
        dx = vec(grid["DXV"])
    end
    if haskey(grid, "DY")
        DY = meshgrid_section("DY")
        dy = vec(DY[1, :, 1])
        for i in axes(DY, 1)
            for j in axes(DY, 2)
                for k in axes(DY, 3)
                    @assert DY[i, j, k] ≈ DY[1, j, 1]
                end
            end
        end
    else
        @assert haskey(grid, "DYV") "Either DY or DYV must be provided in GRID."
        dy = vec(grid["DYV"])
    end
    if haskey(grid, "DZ")
        DZ = meshgrid_section("DZ")
        dz = vec(DZ[1, 1, :])
        for i in axes(DZ, 1)
            for j in axes(DZ, 2)
                for k in axes(DZ, 3)
                    @assert DZ[i, j, k] ≈ DZ[1, 1, k]
                end
            end
        end
    else
        @assert haskey(grid, "DZV") "Either DZ or DZV must be provided in GRID."
        dz = vec(grid["DZV"])
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
    if !ismissing(nnc)
        function cell_index(i, j, k)
            ix = ijk_to_linear(i, j, k, cartdims)
        end
        nnc_neighbors = Tuple{Int, Int}[]
        for nnc_entry in nnc
            c1 = cell_index(nnc_entry[1], nnc_entry[2], nnc_entry[3])
            c2 = cell_index(nnc_entry[4], nnc_entry[5], nnc_entry[6])
            if c1 > 0 && c2 > 0
                @assert c1 != c2 "NNC cell pair must be distinct."
                push!(nnc_neighbors, (c1, c2))
            else
                error("NNC connects inactive cells, cannot proceed: $(Tuple(nnc_entry[1:3])) -> $(Tuple(nnc_entry[4:6]))")
            end
        end
        insert_nnc_faces!(G, nnc_neighbors)
    end
    if !all(actnum)
        active_cells = findall(x -> x > 0, vec(actnum))
        G = extract_submesh(G, active_cells)
    end
    return G
end

function cell_centers_from_deltas(dx, x0 = 0.0)
    T = promote_type(eltype(dx), typeof(x0))
    nx = length(dx)
    x = zeros(T, nx)
    x[1] = dx[1]/2.0 + x0
    for i in 2:nx
        x[i] = x[i-1] + dx[i]
    end
    return (x, nx)
end
