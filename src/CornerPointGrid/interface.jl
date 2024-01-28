"""
    mesh_from_grid_section(f, actnum = missing)

TBW
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
        @warn "DX+DY+DZ+TOPS format is only supported if all cells are equally sized. If you get an error, this is the cause."
        @assert all(actnum)
        dx = only(unique(grid["DX"]))
        dy = only(unique(grid["DY"]))
        dz = only(unique(grid["DZ"]))
        tops = only(unique(grid["TOPS"]))
        G = CartesianMesh(cartdims, cartdims.*(dx, dy, dz))
        # We always want to return an unstructured mesh.
        G = UnstructuredMesh(G)
    end
    if haskey(grid, "FAULTS")
        mesh_add_fault_tags!(G, grid["FAULTS"])
    end
    return G
end
