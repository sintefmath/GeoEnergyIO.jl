function mesh_add_fault_tags!(G::UnstructuredMesh, faults)
    ijk = map(x -> cell_ijk(G, x), 1:number_of_cells(G))
    N = G.faces.neighbors

    sorted_face_pair_I = get_sorted_face_pairs(N, ijk, 1)
    sorted_face_pair_J = get_sorted_face_pairs(N, ijk, 2)
    sorted_face_pair_K = get_sorted_face_pairs(N, ijk, 3)

    sorted_faces = (sorted_face_pair_I, sorted_face_pair_J, sorted_face_pair_K)
    for (fault, specs) in faults
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
            self = range_self[1]
            match_fault_to_faces!(fault_faces, range_1, sorted_faces[ix_1], range_2, sorted_faces[ix_2], self, sorted_faces[ix_self], inc)
        end
        @debug "Fault $fault: Added $(length(fault_faces)) faces"
        set_mesh_entity_tag!(G, Faces(), :faults, Symbol(fault), fault_faces)
    end
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

function match_fault_to_faces!(fault_faces, range_1, sorted_faces_1, range_2, sorted_faces_2, self, sorted_faces_self, inc)
    pair = sorted_neighbor_tuple(self, self+inc)
    rng = searchsorted(sorted_faces_self.N_sorted, pair)
    faces = view(sorted_faces_self.faces_sorted, rng)
    for face in faces
        l_1, r_1 = sorted_faces_1.N[face]
        if l_1 in range_1 && r_1 in range_1
            l_2, r_2 = sorted_faces_2.N[face]
            if l_2 in range_2 && r_2 in range_2
                push!(fault_faces, face)
            end
        end
    end
end
