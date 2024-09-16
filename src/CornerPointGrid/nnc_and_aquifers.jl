
function insert_nnc_faces!(G::UnstructuredMesh, new_faces_neighbors, new_faces_nodes = fill(Int[], length(new_faces_neighbors)))
    expand_indirection = x -> map(i -> copy(x[i]), 1:length(x))
    c2f = expand_indirection(G.faces.cells_to_faces)
    f2n = expand_indirection(G.faces.faces_to_nodes)

    faceno = number_of_faces(G)
    for neighbors in new_faces_neighbors
        faceno += 1
        l, r = neighbors
        push!(G.faces.neighbors, neighbors)
        push!(c2f[l], faceno)
        push!(c2f[r], faceno)
    end

    for nodes in new_faces_nodes
        push!(f2n, nodes)
    end
    replace_indirection!(G.faces.cells_to_faces, c2f)
    replace_indirection!(G.faces.faces_to_nodes, f2n)

    @assert number_of_faces(G) == faceno
    return G
end

function replace_indirection!(x, expanded)
    empty!(x.vals)
    empty!(x.pos)

    push!(x.pos, 1)
    for vals in expanded
        n = length(vals)
        for v in vals
            push!(x.vals, v)
        end
        push!(x.pos, x.pos[end] + n)
    end
    return x
end

function mesh_insert_cell!(G::UnstructuredMesh, faces, bnd_faces)

end

function setup_numerical_aquifers!(data::AbstractDict)
    aqunum = get(grid, "AQUNUM", missing)
    aqucon = get(grid, "AQUCON", missing)
    return mesh_add_numerical_aquifers!(G, aqunum, aqucon)
end

function mesh_add_numerical_aquifers!(mesh, AQUNUM::Missing, AQUCON)
    return nothing
end

function mesh_add_numerical_aquifers!(mesh, AQUNUM, AQUCON)
    if ismissing(AQUCON)
        @warn "AQUNUM was defined by AQUCON was not found. Aquifer will not have any effect."
        return nothing
    end
    # Remove repeats
    AQUNUM = filter_aqunum(AQUNUM)

    dims = mesh.structure.I
    actnum = fill(false, prod(dims))
    actnum[mesh.cell_map] .= true
    # Create parameter list for aquifers
    prm_T = @NamedTuple{
        cell::Int64,
        area::Float64,
        length::Float64,
        porosity::Float64,
        permeability::Float64,
        depth::Float64,
        pressure::Float64,
        pvtnum::Int64,
        satnum::Int64,
        boundary_faces::Vector{Int},
        added_faces::Vector{Int},
        boundary_transmult::Vector{Float64}
    }
    aquifer_parameters = Dict{Int, prm_T}()
    num_cells_start = number_of_cells(mesh)
    new_cells_cell_map = Int[]
    for aqunum in AQUNUM
        id, I, J, K, A, L, phi, perm, D, p0, pvt, sat = aqunum
        ix = ijk_to_linear(I, J, K, dims)
        # "AQUNUM cannot declare aquifer in active cell ($I, $J, $K), cell must be inactive."
        if actnum[ix] == false
            # Add the cell
            push!(new_cells_cell_map, ix)
            cell = num_cells_start + length(new_cells_cell_map)
        else
            # Cell can be active and should then transition to being treated as
            # aquifer. We find the matching cell.
            cell = cell_index(mesh, (I, J, K))
        end
        aquifer_parameters[id] = (
            cell = cell,
            area = A,
            length = L,
            porosity = phi,
            permeability = perm,
            depth = D,
            pressure = p0,
            pvtnum = pvt,
            satnum = sat,
            boundary_faces = Int[], # Boundary faces that were connected
            added_faces = Int[], # Corresponding fake faces that were aded
            boundary_transmult = Float64[] # Trans mult of those fake faces
        )
    end
    # Add all the faces
    @assert length(keys(aquifer_parameters)) == length(AQUNUM)
    IJK = map(i -> cell_ijk(mesh, i), 1:number_of_cells(mesh))
    nf0 = number_of_faces(mesh)
    added_face_no = 0
    new_faces_neighbors = Tuple{Int, Int}[]
    for (i, aqucon) in enumerate(AQUCON)
        id, I_start, I_stop, J_start, J_stop, K_start, K_stop, dir, tranmult, opt, = aqucon
        bfaces = find_faces_for_aquifer(mesh, I_start:I_stop, J_start:J_stop, K_start:K_stop, dir, IJK)
        prm = aquifer_parameters[id]

        for bface in bfaces
            added_face_no += 1
            push!(prm.boundary_faces, bface)
            push!(prm.boundary_transmult, tranmult)
            push!(prm.added_faces, added_face_no)
            # Add the new faces
            c = mesh.boundary_faces.neighbors[bface]
            push!(new_faces_neighbors, (c, prm.cell))
        end
    end
    fpos = mesh.faces.cells_to_faces.pos
    bpos = mesh.boundary_faces.cells_to_faces.pos
    for (i, c) in enumerate(new_cells_cell_map)
        # Add cells without any face connections since these will be added
        # afterwards as NNCs.
        push!(fpos, fpos[end])
        push!(bpos, bpos[end])
        # Add the indices in the global enumeration of cells that have been
        # added as active.
        push!(mesh.cell_map, c)
    end
    insert_nnc_faces!(mesh, new_faces_neighbors)
    @assert length(mesh.faces.neighbors) == nf0 + added_face_no
    return aquifer_parameters
end

function filter_aqunum(AQUNUM; warn = true)
    indices = Dict{Int, Int}()
    for (i, aqunum) in enumerate(AQUNUM)
        id = first(aqunum)
        if haskey(indices, id) && warn
            # Can overwrite connections (assumed?)
            jutul_message("AQUNUM", "Line $i: Replacing aquifer with id $id from line $(indices[id]) as new entry was provided.", color = :yellow)
        end
        indices[id] = i
    end
    # Do another loop to make sure this operation is stable and doesn't reorder
    # the connections. Could use OrderedDict if we add OrderedCollections.
    keep = Int[]
    for (i, aqunum) in enumerate(AQUNUM)
        id = first(aqunum)
        if indices[id] == i
            push!(keep, i)
        end
    end
    return AQUNUM[keep]
end

function find_faces_for_aquifer(mesh, I_range, J_range, K_range, dir, IJK)
    bnd_faces = Int[]
    if length(dir) == 1 || dir[2] == '+'
        pos = true
    else
        @assert dir[2] == '-'
        pos = false
    end

    d = dir[1]
    if d == 'X' || d == 'I'
        ijk_orientation = :i
        ijk_ix = 1
        if pos
            dir_orientation = :right
        else
            dir_orientation = :left
        end
    elseif d == 'Y' || d == 'J'
        ijk_orientation = :j
        ijk_ix = 2
        if pos
            dir_orientation = :top
        else
            dir_orientation = :bottom
        end
    elseif d == 'Z' || d == 'K'
        ijk_orientation = :k
        ijk_ix = 3
        if pos
            # Positive direction down
            dir_orientation = :lower
        else
            dir_orientation = :upper
        end
    else
        error("Bad direction for aquifer entry: $dir")
    end
    function boundary_face_check(faceno, e)
        if !mesh_entity_has_tag(mesh, e, :ijk_orientation, ijk_orientation, faceno)
            return false
        end
        if !mesh_entity_has_tag(mesh, e, :direction, dir_orientation, faceno)
            return false
        end
        return true
    end

    for cell in 1:number_of_cells(mesh)
        I, J, K = IJK[cell]
        if I in I_range && J in J_range && K in K_range
            # TODO: We assume that aquifers are attached to the boundary here.
            # Could maybe be generalized to handle interior faces too, if some
            # tags were to be added.
            for bfaceno in mesh.boundary_faces.cells_to_faces[cell]
                if boundary_face_check(bfaceno, BoundaryFaces())
                    push!(bnd_faces, bfaceno)
                end
            end
        end
    end
    return bnd_faces
end
