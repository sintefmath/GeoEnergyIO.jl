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
    cartdims = grid["cartDims"]
    if haskey(grid, "COORD")
        coord = grid["COORD"]
        zcorn = grid["ZCORN"]
        primitives = cpgrid_primitives(coord, zcorn, cartdims, actnum = actnum)
        G = grid_from_primitives(primitives)
    else
        @assert haskey(grid, "DX")
        @assert haskey(grid, "DY")
        @assert haskey(grid, "DZ")
        @assert haskey(grid, "TOPS")
        @warn "DX+DY+DZ+TOPS format is only supported if all cells are equally sized and at same TOPS depth. If you get an error, this is the cause."
        @assert all(actnum)
        dx = only(unique(grid["DX"]))
        dy = only(unique(grid["DY"]))
        dz = only(unique(grid["DZ"]))
        tops = only(unique(grid["TOPS"]))
        G = CartesianMesh(cartdims, cartdims.*(dx, dy, dz))
        # We always want to return an unstructured mesh.
        G = UnstructuredMesh(G, z_is_depth = true)
        offset = [0.0, 0.0, tops]
        for i in eachindex(G.node_points)
            G.node_points[i] += offset
        end
    end
    if haskey(grid, "FAULTS")
        mesh_add_fault_tags!(G, grid["FAULTS"])
    end
    return G
end
