function mesh_add_fault_tags!(G::UnstructuredMesh, faults)
    ijk = map(x -> cell_ijk(G, x), 1:number_of_cells(G))
    N = G.faces.neighbors
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
            match_fault_to_faces!(fault_faces, N, ijk, range_1, ix_1, range_2, ix_2, self, ix_self, inc)
        end
        @debug "Fault $fault: Added $(length(fault_faces)) faces"
        set_mesh_entity_tag!(G, Faces(), :faults, Symbol(fault), fault_faces)
    end
end

function match_fault_to_faces!(fault_faces, N, ijk_cells, range_1, ix_1, range_2, ix_2, self, ix_self, inc)
    function sorted_tuple(a, b)
        if a < b
            pair = (a, b)
        else
            pair = (b, a)
        end
    end
    pair = sorted_tuple(self, self+inc)
    face = 0
    for (l, r) in N
        face += 1
        ijk_l = ijk_cells[l]
        ijk_r = ijk_cells[r]
        self_l = ijk_l[ix_self]
        self_r = ijk_r[ix_self]
        fpair = sorted_tuple(self_l, self_r)
        if fpair != pair
            continue
        end
        # Keep going unless fixed indices match
        cr_1 = ijk_r[ix_1]
        if !(cr_1 in range_1)
            continue
        end
        cr_2 = ijk_r[ix_2]
        if !(cr_2 in range_2)
            continue
        end
        cl_1 = ijk_l[ix_1]
        if !(cl_1 in range_1)
            continue
        end
        cl_2 = ijk_l[ix_2]
        if !(cl_2 in range_2)
            continue
        end
        push!(fault_faces, face)
    end
end
