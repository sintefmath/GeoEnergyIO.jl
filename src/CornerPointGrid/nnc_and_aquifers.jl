
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

function mesh_add_numerical_aquifers!(mesh, AQUNUM::Missing, AQUCON, actnum)
    return mesh
end

function mesh_add_numerical_aquifers!(mesh, AQUNUM, AQUCON, actnum)
    AQUNUM = filter_aqunum(AQUNUM)

    dims = mesh.structure.I

    new_cells = Int[]
    # g.faces.cells_to_faces
    # g.boundary_faces.cells_to_faces
    # cell_map
    @info "???" mesh.faces.cells_to_faces
    new_cells_to_faces = Vector{Int}[]

    aquifer_cells = Dict{Int, Int}()
    # aquifer_cells = Int[]
    # aquifer_id = Int[]


    num_cells_start = number_of_cells(mesh)
    @info "Starting" AQUNUM
    for aqunum in AQUNUM
        id, I, J, K, = aqunum
        ix = ijk_to_linear(I, J, K, dims)
        # "AQUNUM cannot declare aquifer in active cell ($I, $J, $K), cell must be inactive."
        if actnum[ix] == false
            # Add the cell
            push!(new_cells_to_faces, Int[])
            cell = num_cells_start + length(new_cells_to_faces)
        else
            # Cell can be active and should then transition to being treated as
            # aquifer. We find the matching cell.
            cell = cell_index(mesh, (I, J, K))
        end
        aquifer_cells[id] = cell
    end
    @assert length(keys(aquifer_cells)) == length(AQUNUM)
    if !ismissing(AQUCON)
        @info "Starting faces" AQUCON

        tran_mult_and_opt = Tuple{Float64, Int}[]
        for (i, aqucon) in enumerate(AQUCON)
            id, I_start, I_stop, J_start, J_stop, K_start, K_stop, dir, tranmult, opt, = aqucon
            push!(tran_mult_and_opt, (tranmult, opt))

            find_faces_for_aquifer(mesh, I_start:I_stop, J_start:J_stop, K_start:K_stop, dir)
        end
        # insert_nnc_faces! kan gjenbrukes her.
    end
    # Finally loop over add add everything
    error()
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

function find_faces_for_aquifer(mesh, I, J, K, dir)
    d = dir[1]
    if d == 'X' || d == 'I'
        ix_self = 1
        ix_1 = 2
        ix_2 = 3
    elseif d == 'Y' || d == 'J'
        ix_self = 2
        ix_1 = 1
        ix_2 = 3
    elseif d == 'Z' || d == 'K'
        ix_self = 3
        ix_1 = 1
        ix_2 = 2
    else
        error("Bad direction for fault $fault entry: $dir")
    end
    if length(dir) == 1 || dir[2] == '+'
        inc = 1
    else
        @assert dir[2] == '-'
        inc = -1
    end
end
