
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
    dims = mesh.structure.I
    actnum = fill(false, prod(dims))
    actnum[mesh.cell_map] .= true
    prm_t =  @NamedTuple{
        aquifer_cells::Vector{
            @NamedTuple{cell::Int64, area::Float64, length::Float64, porosity::Float64, permeability::Float64, depth::Float64, pressure::Float64, pvtnum::Int64, satnum::Int64}},
            aquifer_faces::Vector{Int64},
            boundary_faces::Vector{Int64},
            added_faces::Vector{Int64},
            boundary_transmult::Vector{Float64},
            trans_option::Vector{Int64}
        }
    aquifer_parameters = Dict{Int, prm_t}()
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
        new_aquifer = (
            cell = cell,
            area = A,
            length = L,
            porosity = phi,
            permeability = perm,
            depth = D,
            pressure = p0,
            pvtnum = pvt,
            satnum = sat
        )

        if haskey(aquifer_parameters, id)
            push!(aquifer_parameters[id].aquifer_cells, new_aquifer)
        else
            aquifer_parameters[id] = (
                aquifer_cells = [new_aquifer],
                aquifer_faces = Int[], # Fake faces added that are interior to aquifer
                boundary_faces = Int[], # Boundary faces that were connected
                added_faces = Int[], # Corresponding fake faces that were aded
                boundary_transmult = Float64[], # Trans mult of those fake faces
                trans_option = Int[] # Option for how to compute that trans trans
            )
        end
    end
    # Add all the faces
    IJK = map(i -> cell_ijk(mesh, i), 1:number_of_cells(mesh))
    nf0 = number_of_faces(mesh)
    added_face_no = 0
    new_faces_neighbors = Tuple{Int, Int}[]
    for (i, aqucon) in enumerate(AQUCON)
        id, I_start, I_stop, J_start, J_stop, K_start, K_stop, dir, tranmult, opt, = aqucon
        # Defaulted means start and stop at 1?
        I_start = max(I_start, 1)
        J_start = max(J_start, 1)
        K_start = max(K_start, 1)
        I_stop = max(I_stop, 1)
        J_stop = max(J_stop, 1)
        K_stop = max(K_stop, 1)
        bfaces = find_faces_for_aquifer(mesh, I_start:I_stop, J_start:J_stop, K_start:K_stop, dir, IJK)
        prm = aquifer_parameters[id]

        for bface in bfaces
            added_face_no += 1
            push!(prm.boundary_faces, bface)
            push!(prm.boundary_transmult, tranmult)
            push!(prm.added_faces, added_face_no + nf0)
            push!(prm.trans_option, opt)
            # Add the new faces
            c = mesh.boundary_faces.neighbors[bface]
            push!(new_faces_neighbors, (c, prm.aquifer_cells[1].cell))
        end
    end
    # Add aquifer internal connections
    for (id, aquifer) in pairs(aquifer_parameters)
        N = length(aquifer.aquifer_cells)
        for i in 2:N
            added_face_no += 1
            l = aquifer.aquifer_cells[i-1].cell
            r = aquifer.aquifer_cells[i].cell
            push!(new_faces_neighbors, (l, r))
            push!(aquifer.aquifer_faces, added_face_no + nf0)
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
            dir_orientation = :upper
        else
            dir_orientation = :lower
        end
    elseif d == 'Z' || d == 'K'
        ijk_orientation = :k
        ijk_ix = 3
        if pos
            # Positive direction is down in input
            dir_orientation = :bottom
        else
            dir_orientation = :top
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
