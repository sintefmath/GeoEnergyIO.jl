function mesh_add_fault_tags!(G::UnstructuredMesh, faults)
    lookups = get_ijk_lookups(G)
    for (fault, specs) in faults
        fault_faces = fault_to_faces(G::UnstructuredMesh, specs, lookups, fault)
        @debug "Fault $fault: Added $(length(fault_faces)) faces"
        set_mesh_entity_tag!(G, Faces(), :faults, Symbol(fault), fault_faces)
    end
    return G
end

function build_ijk_lookup(all_ijk, dim, cartdims)
    @assert dim in (1, 2, 3)
    lookup = Dict{Int, Vector{Int}}()
    for i in 1:cartdims[dim]
        lookup[i] = Int[]
    end
    for (cell, ijk) in enumerate(all_ijk)
        push!(lookup[ijk[dim]], cell)
    end
    for i in 1:cartdims[dim]
        lookup[i] = sort(lookup[i])
    end
    return lookup
end

function get_ijk_lookups(G::UnstructuredMesh)
    ijk = map(x -> cell_ijk(G, x), 1:number_of_cells(G))
    cartdims = G.structure.I
    getl(dim) = build_ijk_lookup(ijk, dim, cartdims)
    lookups = (I = getl(1), J = getl(2), K = getl(3))
    return (lookups, ijk)
end

function fault_to_faces(G::UnstructuredMesh, specs, lookups = missing, faultname = :FAULT)
    if ismissing(lookups)
        ijk_lookups, ijk_cells = get_ijk_lookups(G)
    else
        ijk_lookups, ijk_cells = lookups
    end
    fault_faces = Int[]
    for (I, J, K, dir) in specs
        IJK = (I, J, K)
        @assert length(dir) == 1 || length(dir) == 2
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
        range_self = IJK[ix_self]
        range_1 = IJK[ix_1]
        range_2 = IJK[ix_2]
        @assert length(range_self) == 1
        self = only(range_self)
        self_ijk_lookup = ijk_lookups[ix_self][self]
        other_ijk_lookup = ijk_lookups[ix_self][self+inc]
        match_fault_to_faces!(fault_faces, G, ijk_cells, range_1, range_2, ix_1, ix_2, self_ijk_lookup, other_ijk_lookup)
    end
    return fault_faces
end

function mesh_add_fault_tags!(G::UnstructuredMesh, faults::Missing)
    return G
end

function get_sorted_face_pairs(N, IJK, ijk_ix)
    nf = length(N)
    N_val = similar(N)
    for i in 1:nf
        l, r = N[i]
        N_val[i] = sorted_neighbor_tuple(IJK[l][ijk_ix], IJK[r][ijk_ix])
    end
    faces = sortperm(N_val)
    return (
        faces_sorted = faces, # Sorted face order
        N_sorted = N_val[faces], # Sorted tuple pairs
        N = N_val # Tuple pairs in original order
    )
end

function sorted_neighbor_tuple(a, b)
    if a < b
        pair = (a, b)
    else
        pair = (b, a)
    end
end

function match_fault_to_faces!(fault_faces, G, ijk, range_1, range_2, ix_1, ix_2, self_cells, other_cells)
    function cell_in_ranges(c)
        ijk_c = ijk[c]
        return ijk_c[ix_1] in range_1 && ijk_c[ix_2] in range_2
    end
    n_other = length(other_cells)
    for cell in self_cells
        if cell_in_ranges(cell)
            for f in G.faces.cells_to_faces[cell]
                l, r = G.faces.neighbors[f]
                if l == cell
                    other_cell = r
                else
                    other_cell = l
                end
                if insorted(other_cell, other_cells)
                    push!(fault_faces, f)
                end
            end
        end
    end
end
