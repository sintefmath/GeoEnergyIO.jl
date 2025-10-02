function cpgrid_primitives(coord, zcorn, cartdims; actnum = missing)
    # Add all lines that have at least one active neighbor
    coord = reshape(coord, 6, :)'
    nx, ny, nz = cartdims
    if ismissing(actnum)
        actnum = Array{Bool, 3}(undef, nx, ny, nz)
        @. actnum = true
    end
    # Create bounding box used to get boundaries correct
    z_mean = max(sum(zcorn)/length(zcorn), 1.0)
    z_max = maximum(zcorn) + z_mean
    z_min = minimum(zcorn) - z_mean
    nactive = sum(vec(actnum))
    remapped_indices = Vector{Int}(undef, nx*ny*nz)
    tmp = vec(actnum)
    active_cell_indices = findall(isequal(1), tmp)
    @. remapped_indices[tmp] = 1:nactive

    nlinex = nx+1
    nliney = ny+1
    @assert nliney*nlinex == size(coord, 1)

    function generate_line(p1, p2)
        T_coord = promote_type(eltype(p1), eltype(p2), typeof(z_mean))
        line_length_hint = 4*nz
        z = sizehint!(Vector{T_coord}(), line_length_hint)
        cells = sizehint!(Vector{Int}(), line_length_hint)
        cellpos = sizehint!(Vector{Int}(), line_length_hint)
        nodes = sizehint!(Vector{Int}(), line_length_hint)

        return (
            z = z,
            cells = cells,
            cellpos = cellpos,
            nodes = nodes,
            x1 = SVector{3, T_coord}(p1),
            x2 = SVector{3, T_coord}(p2),
            equal_points = p1 ≈ p2
            )
    end
    # active_lines = BitArray(undef, nlinex, nliney)
    x1, x2 = get_line(coord, 1, 1, nlinex, nliney)
    line0 = generate_line(x1, x2)
    function boundary_index(i, j, is_top)
        if is_top
            layer_offset = -(2*nx*ny*nz)
        else
            layer_offset = -(nx*ny*nz)
        end
        return layer_offset - ij_to_linear(i, j, cartdims[1:2])
    end

    function cell_index(i, j, k, actnum)
        ix = ijk_to_linear(i, j, k, cartdims)
        if actnum[i, j, k]
            cell = remapped_indices[ix]
        else
            cell = -ix
            @assert cell <= 0
        end
        return cell
    end

    linear_line_ix(i, j) = ij_to_linear(i, j, (nlinex, nliney))
    L_t = typeof(line0)
    lines = Matrix{Union{L_t, Missing}}(undef, nlinex, nliney)
    for i in 1:nlinex
        for j in 1:nliney
            p1, p2 = get_line(coord, i, j, nlinex, nliney)
            lines[i, j] = generate_line(p1, p2)
        end
    end
    for i = 1:nx
        for j = 1:ny
            for k = 1:nz
                ix = ijk_to_linear(i, j, k, cartdims)
                active_cell_index = cell_index(i, j, k, actnum)
                for I1 in (0, 1)
                    for I2 in (0, 1)
                        L = lines[i + I2, j + I1]
                        for I3 in (0, 1)
                            zcorn_ix = corner_index(ix, (I1, I2, I3), cartdims)
                            c = zcorn[zcorn_ix]
                            # Note reversed indices, this is a bit of a mess
                            push!(L.z, c)
                            push!(L.cells, active_cell_index)
                        end
                    end
                end
            end
        end
    end
    # Add fake boundary nodes with corresponding cells
    for i in 1:(nx+1)
        for j in 1:(ny+1)
            L = lines[i, j]
            z_top = minimum(L.z)
            z_bottom = maximum(L.z)
            for i_offset in (-1, 0)
                for j_offset in (-1, 0)
                    I = i+i_offset
                    J = j+j_offset
                    if I > 0 && J > 0
                        t = boundary_index(I, J, true)
                        b = boundary_index(I, J, false)
                        # Top layer
                        push!(L.z, z_min, z_top)
                        push!(L.cells, t, t)
                        # Bottom layer
                        push!(L.z, z_bottom, z_max)
                        push!(L.cells, b, b)
                    end
                end
            end
        end
    end

    # Process lines and merge similar nodes
    nodes, lines_active = process_lines!(lines)
    if true
        for i in eachindex(lines)
            if !lines_active[i]
                lines[i] = missing
            end
        end
    end
    GC.gc()

    # The four lines making up each column
    column_lines = Vector{NTuple{4, Int64}}()

    # Tag columns as active or inactive
    active_columns = Matrix{Bool}(undef, nx, ny)
    for i in 1:nx
        for j in 1:ny
            is_active = false
            for k in 1:nz
                is_active = is_active || actnum[i, j, k]
            end
            active_columns[i, j] = is_active
        end
    end
    # Generate the columns with cell lists
    make_column(i, j) = (cells = Int[], i = i, j = j)
    cT = typeof(make_column(1, 1))
    col_counter = 1
    columns = Vector{cT}()
    column_indices = zeros(Int, nx, ny)
    for i in 1:nx
        for j in 1:ny
            if active_columns[i, j]
                col = make_column(i, j)
                prev = boundary_index(i, j, true) 
                push!(col.cells, prev)
                for k in 1:nz
                    cell = cell_index(i, j, k, actnum)
                    if cell != prev
                        push!(col.cells, cell)
                    end
                    prev = cell
                end
                # Put a boundary at the end
                push!(col.cells, boundary_index(i, j, false))
                push!(columns, col)
                column_indices[i, j] = col_counter
                col_counter += 1

                ll = linear_line_ix(i, j)
                rl = linear_line_ix(i+1, j)
                lr = linear_line_ix(i, j+1)
                rr = linear_line_ix(i+1, j+1)
                push!(column_lines, (ll, rl, rr, lr))
            end
        end
    end
    ncol = length(columns)
    ncoll = length(column_lines)
    @assert ncol == ncoll "Mismatch in columns ($ncol) and column lines ($ncoll)"

    function get_edge(i, j, t)
        if t == :right
            p1 = linear_line_ix(i+1, j+1)
            p2 = linear_line_ix(i+1, j)
        elseif t == :left
            p1 = linear_line_ix(i, j)
            p2 = linear_line_ix(i, j+1)
        elseif t == :upper
            p1 = linear_line_ix(i, j+1)
            p2 = linear_line_ix(i+1, j+1)
        else
            @assert t == :lower
            p1 = linear_line_ix(i, j)
            p2 = linear_line_ix(i+1, j)
        end
        return (p1, p2, t)
    end

    function get_boundary_edge(self, i, j, t)
        return (column = self, pillars = get_edge(i, j, t))
    end

    function get_interior_edge(c1, c2, i, j, t)
        return (columns = (c1, c2), pillars = get_edge(i, j, t))
    end

    tmp = get_boundary_edge(1, 1, 1, :left)
    column_boundary = Vector{typeof(tmp)}()

    tmp = get_interior_edge(1, 1, 1, 1, :left)
    column_neighbors = Vector{typeof(tmp)}()

    for i in 1:nx
        for j in 1:ny
            if active_columns[i, j]
                self = column_indices[i, j]
                if i < nx && active_columns[i+1, j]
                    other = column_indices[i+1, j]
                    e = get_interior_edge(self, other, i, j, :right)
                    push!(column_neighbors, e)
                else
                    # Add right edge to boundary
                    e = get_boundary_edge(self, i, j, :right)
                    push!(column_boundary, e)
                end
                if i == 1
                    e = get_boundary_edge(column_indices[i, j], i, j, :left)
                    push!(column_boundary, e)
                end
                if j < ny && active_columns[i, j+1]
                    other = column_indices[i, j+1]
                    e = get_interior_edge(self, other, i, j, :upper)
                    push!(column_neighbors, e)
                else
                    e = get_boundary_edge(self, i, j, :upper)
                    push!(column_boundary, e)
                end
                if j == 1
                    e = get_boundary_edge(column_indices[i, j], i, j, :lower)
                    push!(column_boundary, e)
                end
            else
                if i < nx && active_columns[i+1, j]
                    e = get_boundary_edge(column_indices[i+1, j], i+1, j, :left)
                    push!(column_boundary, e)
                end
                if j < ny && active_columns[i, j+1]
                    e = get_boundary_edge(column_indices[i, j+1], i, j+1, :lower)
                    push!(column_boundary, e)
                end
            end
        end
    end
    # Get a normal vector to estimate the direction of the coordiante system
    x1_l, = get_line(coord, 2, 1, nlinex, nliney)
    x1_r, = get_line(coord, 1, 2, nlinex, nliney)
    coord_normal = cross(x1_l - x1, x1_r - x1)
    coord_normal = coord_normal./norm(coord_normal, 2)

    return (
        lines = lines,
        lines_active = lines_active,
        column_neighbors = column_neighbors,
        column_boundary = column_boundary,
        column_lines = column_lines,
        columns = columns,
        active = active_cell_indices,
        nodes = nodes,
        cartdims = cartdims,
        coord_normal = coord_normal
    )
end

function process_lines!(lines)
    if length(lines) > 0
        T = eltype(lines[1].z)
    else
        T = Float64
    end
    nodes = Vector{SVector{3, T}}()
    active_lines = BitVector(undef, length(lines))
    node_counter = 1
    for (line_ix, line) in enumerate(lines)
        z = line.z
        active = length(z) > 0 && !all(x -> x <= 0, line.cells)
        active_lines[line_ix] = active
        if active
            p = sortperm(z)
            @. line.z = z[p]
            @. line.cells = line.cells[p]
            pos = line.cellpos
            push!(pos, 1)

            counter = 1
            for i in 2:length(z)
                if z[i] ≈ z[i-1]
                    counter += 1
                else
                    push!(pos, pos[end] + counter)
                    counter = 1
                end
            end
            push!(pos, pos[end] + counter)
            # Sort each set of cells
            for i in 1:(length(pos)-1)
                ci = view(line.cells, pos[i]:(pos[i+1]-1))
                sort!(ci)
            end
            ix = pos[1:end-1]
            unique_z = line.z[ix]
            # Put back the unique points only
            resize!(line.z, 0)
            for z_i in unique_z
                push!(line.z, z_i)
                push!(line.nodes, node_counter)
                node_counter += 1
                new_node = interp_coord(line, z_i)
                push!(nodes, new_node)
            end
        end
    end

    return (nodes, active_lines)
end

function grid_from_primitives(primitives; nnc = missing, pinch = missing)
    (;
        lines,
        lines_active,
        # column_neighbors,
        column_lines,
        columns,
        active,
        nodes,
        cartdims,
        coord_normal
    ) = primitives
    if sum(active) == 0
        error("Grid has no active cells.")
    end

    Nx, Ny, Nz = coord_normal
    # A not very rigorous test for flipped coordinate systems.
    # The normal situation is Nx < 0, Ny > 0 and Nz > 0
    flipped = Nx < 0 && Ny > 0 && Nz < 0
    # Faces mapping to nodes
    faces = Vector{Int}()
    face_pos = [1]
    faceno = 1

    cell_is_boundary(x) = x < 1
    # Boundary faces mapping to nodes
    boundary_faces = Vector{Int}()
    boundary_face_pos = [1]
    boundary_faceno = 1

    # Mapping from cell to faces
    cell_faces = Vector{Vector{Int}}()
    # Mapping from cell to boundary faces
    cell_boundary_faces = Vector{Vector{Int}}()

    for c in eachindex(active)
        push!(cell_faces, Vector{Int}())
        push!(cell_boundary_faces, Vector{Int}())
    end
    face_neighbors = Vector{Tuple{Int, Int}}()
    boundary_cells = Vector{Int}()

    vertical_face_tag = Vector{Int}()
    horizontal_face_tag = Vector{Int}()
    i_face_tag = Vector{Int}()
    j_face_tag = Vector{Int}()
    k_face_tag = Vector{Int}()

    vertical_bnd_face_tag = Vector{Int}()
    horizontal_bnd_face_tag = Vector{Int}()
    i_bnd_face_tag = Vector{Int}()
    j_bnd_face_tag = Vector{Int}()
    k_bnd_face_tag = Vector{Int}()
    boundary_type = Dict{Int, Symbol}()

    nx, ny, nz = cartdims

    nlinex = nx+1
    nliney = ny+1

    # Lookup for extra nodes that are not in the pillars but are made due to intersections over faults.
    # The Float64 type is intentional.
    extra_node_lookup = Dict{SVector{3, Float64}, Int}()

    function add_face_from_nodes!(V, Vpos, nodes)
        n_global_nodes = length(primitives.nodes)
        n_local_nodes = length(nodes)
        @assert n_local_nodes > 2
        if flipped
            nodes = Base.Iterators.Reverse(nodes)
        end
        for n in nodes
            @assert n <= n_global_nodes
            @assert n > 0
            push!(V, n)
        end
        push!(Vpos, length(nodes) + Vpos[end])
    end

    function insert_boundary_face!(prev_cell, cell, nodes, is_vertical, is_idir, face_type)
        orient = cell_is_boundary(prev_cell) && !cell_is_boundary(cell)
        @assert orient || (cell_is_boundary(cell) && !cell_is_boundary(prev_cell)) "cell pair $((cell, prev_cell)) is not on boundary"
        if orient
            self = cell
        else
            self = prev_cell
            nodes = reverse(nodes)
        end
        add_face_from_nodes!(boundary_faces, boundary_face_pos, nodes)
        push!(cell_boundary_faces[self], boundary_faceno)
        push!(boundary_cells, self)
        if is_vertical
            push!(vertical_bnd_face_tag, boundary_faceno)
        else
            push!(horizontal_bnd_face_tag, boundary_faceno)
        end
        boundary_type[boundary_faceno] = face_type
        if is_idir
            push!(i_bnd_face_tag, boundary_faceno)
            @assert face_type in (:left, :right)
        elseif is_vertical
            @assert face_type in (:upper, :lower)
            push!(j_bnd_face_tag, boundary_faceno)
        else
            @assert face_type in (:top, :bottom)
            push!(k_bnd_face_tag, boundary_faceno)
        end
        boundary_faceno += 1
    end

    function insert_interior_face!(prev_cell, cell, nodes, is_vertical, is_idir, face_type)
        @assert cell > 0
        @assert prev_cell > 0
        @assert prev_cell != cell
        add_face_from_nodes!(faces, face_pos, nodes)
        # Note order here.
        push!(face_neighbors, (prev_cell, cell))
        push!(cell_faces[cell], faceno)
        push!(cell_faces[prev_cell], faceno)
        if is_vertical
            push!(vertical_face_tag, faceno)
        else
            push!(horizontal_face_tag, faceno)
        end
        if is_idir
            push!(i_face_tag, faceno)
        elseif is_vertical
            push!(j_face_tag, faceno)
        else
            push!(k_face_tag, faceno)
        end
        faceno += 1
    end

    function insert_face!(prev_cell, cell, nodes; is_boundary, is_vertical, is_idir, face_type)
        if is_boundary
            insert_boundary_face!(prev_cell, cell, nodes, is_vertical, is_idir, face_type)
        else
            insert_interior_face!(prev_cell, cell, nodes, is_vertical, is_idir, face_type)
        end
    end
    # Create pinch maps
    pinch_top_to_bottom, pinch_bottom_to_top = generate_pinch_map(pinch, primitives, lines, column_lines, columns)

    # Horizontal faces (top/bottom and faces along column)
    node_buffer = Int[]
    sizehint!(node_buffer, 10)
    for (cl, col) in zip(column_lines, columns)
        number_of_cells_in_column = length(col.cells)
        current_column_lines = map(l -> lines[l], cl)
        for (i, cell) in enumerate(col.cells)
            if cell_is_boundary(cell)
                continue
            end
            if i == 1
                prev = 0
            else
                prev = col.cells[i-1]
            end
            if i == number_of_cells_in_column
                next = 0
            else
                next = col.cells[i+1]
            end
            top_is_boundary = cell_is_boundary(prev)
            bottom_is_boundary = cell_is_boundary(next)
            cell_bnds = map(l -> find_cell_bounds(cell, l), current_column_lines)
            for is_top in (true, false)
                if is_top
                    if !top_is_boundary
                        # Avoid adding interior faces twice.
                        continue
                    end
                    is_bnd = top_is_boundary
                    F = first
                    c1 = prev
                    c2 = cell
                    ft = :top
                else
                    is_bnd = bottom_is_boundary
                    F = last
                    c1 = cell
                    c2 = next
                    ft = :bottom
                end
                # Pinch treatment
                if haskey(pinch_top_to_bottom, c1)
                    # If the there is a mapping (going down) from c1 to some
                    # other cell due to pinch we should not add anything.
                    @assert cell_is_boundary(c2)
                    continue
                end
                if haskey(pinch_bottom_to_top, c2)
                    # If the there is a mapping (going up) from c2 to some
                    # other cell due to pinch we should not add anything.
                    @assert cell_is_boundary(c1)
                    continue
                end
                # Index into pillars
                node_in_pillar_indices = map(F, cell_bnds)
                # Then find the global node indices
                node_indices = map((line, i) -> line.nodes[i], current_column_lines, node_in_pillar_indices)
                insert_face!(c1, c2, node_indices, is_vertical = false, is_boundary = is_bnd, is_idir = false, face_type = ft)
            end
        end
    end
    # We skipped a bunch faces that belonged to pinched layers. Time to add them
    # back in by systematically going through the pinch list.
    num_pinched = length(keys(pinch_top_to_bottom))
    pinched_faces = Int[]
    if num_pinched > 0
        pinch_count = 0
        for (cl, col) in zip(column_lines, columns)
            number_of_cells_in_column = length(col.cells)
            current_column_lines = map(l -> lines[l], cl)
            for top_cell in col.cells
                cell_bnds = map(l -> find_cell_bounds(top_cell, l), current_column_lines)
                bottom_cell = get(pinch_top_to_bottom, top_cell, nothing)
                if isnothing(bottom_cell)
                    continue
                end
                node_in_pillar_indices = map(last, cell_bnds)
                # Then find the global node indices
                node_indices = map((line, i) -> line.nodes[i], current_column_lines, node_in_pillar_indices)
                # faceno index maps to the next face inserted
                push!(pinched_faces, faceno)
                insert_face!(top_cell, bottom_cell, node_indices, is_vertical = false, is_boundary = false, is_idir = false, face_type = :bottom)
                pinch_count += 1
            end
        end
        @assert num_pinched == pinch_count
    end
    # Vertical faces
    for is_bnd in [true, false]
        if is_bnd
            col_neighbors = primitives.column_boundary
        else
            col_neighbors = primitives.column_neighbors
        end
        for (cols, pillars) in col_neighbors
            # Get the pair of lines we are processing
            p1, p2, conn_type = pillars
            l1 = lines[p1]
            l2 = lines[p2]
            if length(cols) == 1
                a = b = only(cols)
            else
                a, b = cols
            end
            is_idir = conn_type == :left || conn_type == :right

            col_a = columns[a]
            col_b = columns[b]

            cell_pairs, overlaps = traverse_column_pair(col_a, col_b, l1, l2)
            int_pairs, int_overlaps, bnd_pairs, bnd_overlaps = split_overlaps_into_interior_and_boundary(cell_pairs, overlaps)

            F_interior = (l, r, node_indices) -> insert_face!(l, r, node_indices, is_boundary = false, is_vertical = true, is_idir = is_idir, face_type = conn_type)
            F_bnd = (l, r, node_indices) -> insert_face!(l, r, node_indices, is_boundary = true, is_vertical = true, is_idir = is_idir, face_type = conn_type)

            if is_bnd
                # We are dealing with a boundary column, everything is boundary
                add_vertical_cells_from_overlaps!(extra_node_lookup, F_bnd, nodes, int_pairs, int_overlaps, l1, l2)
            else
                add_vertical_cells_from_overlaps!(extra_node_lookup, F_interior, nodes, int_pairs, int_overlaps, l1, l2)
                add_vertical_cells_from_overlaps!(extra_node_lookup, F_bnd, nodes, bnd_pairs, bnd_overlaps, l1, l2)
            end
        end
    end

    if !ismissing(nnc)
        to_active_ix = zeros(Int, nx*ny*nz)
        to_active_ix[active] = eachindex(active)
        function cell_index(i, j, k)
            ix = ijk_to_linear(i, j, k, cartdims)
            aix = to_active_ix[ix]
            return aix
        end

        for nnc_entry in nnc
            c1 = cell_index(nnc_entry[1], nnc_entry[2], nnc_entry[3])
            c2 = cell_index(nnc_entry[4], nnc_entry[5], nnc_entry[6])
            if c1 > 0 && c2 > 0
                @assert c1 != c2 "NNC cell pair must be distinct."
                push!(face_pos, face_pos[end])
                push!(face_neighbors, (c1, c2))
                push!(cell_faces[c1], faceno)
                push!(cell_faces[c2], faceno)
                faceno += 1
            else
                error("NNC connects inactive cells, cannot proceed: $(Tuple(nnc_entry[1:3])) -> $(Tuple(nnc_entry[4:6]))")
            end
        end
    end

    function convert_to_flat(v)
        flat_vals = Int[]
        flat_pos = Int[1]
        for cf in v
            for face in cf
                push!(flat_vals, face)
            end
            push!(flat_pos, flat_pos[end]+length(cf))
        end
        return (flat_vals, flat_pos)
    end

    c2f, c2f_pos = convert_to_flat(cell_faces)
    b2f, b2f_pos = convert_to_flat(cell_boundary_faces)

    g = UnstructuredMesh(
        c2f,
        c2f_pos,
        b2f,
        b2f_pos,
        faces,
        face_pos,
        boundary_faces,
        boundary_face_pos,
        primitives.nodes,
        face_neighbors,
        boundary_cells;
        structure = CartesianIndex(cartdims[1], cartdims[2], cartdims[3]),
        cell_map = primitives.active,
        z_is_depth = true
    )
    # Pinch
    if length(pinched_faces) > 0
        set_mesh_entity_tag!(g, Faces(), :cpgrid_connection_type, :pinched, pinched_faces)
    end
    # Orientation
    if length(horizontal_face_tag) > 0
        set_mesh_entity_tag!(g, Faces(), :orientation, :horizontal, horizontal_face_tag)
    end
    if length(vertical_face_tag) > 0
        set_mesh_entity_tag!(g, Faces(), :orientation, :vertical, vertical_face_tag)
    end
    if length(horizontal_bnd_face_tag) > 0
        set_mesh_entity_tag!(g, BoundaryFaces(), :orientation, :horizontal, horizontal_bnd_face_tag)
    end
    if length(vertical_bnd_face_tag) > 0
        set_mesh_entity_tag!(g, BoundaryFaces(), :orientation, :vertical, vertical_bnd_face_tag)
    end
    # Interior IJK
    if length(i_face_tag) > 0
        set_mesh_entity_tag!(g, Faces(), :ijk_orientation, :i, i_face_tag)
    end
    if length(j_face_tag) > 0
        set_mesh_entity_tag!(g, Faces(), :ijk_orientation, :j, j_face_tag)
    end
    if length(k_face_tag) > 0
        set_mesh_entity_tag!(g, Faces(), :ijk_orientation, :k, k_face_tag)
    end
    # Boundary IJK
    if length(i_bnd_face_tag) > 0
        set_mesh_entity_tag!(g, BoundaryFaces(), :ijk_orientation, :i, i_bnd_face_tag)
    end
    if length(j_bnd_face_tag) > 0
        set_mesh_entity_tag!(g, BoundaryFaces(), :ijk_orientation, :j, j_bnd_face_tag)
    end
    if length(k_bnd_face_tag) > 0
        set_mesh_entity_tag!(g, BoundaryFaces(), :ijk_orientation, :k, k_bnd_face_tag)
    end
    for k in (:left, :right, :upper, :lower, :top, :bottom)
        bnd_ix = Vector{Int}()
        for (f, btype) in pairs(boundary_type)
            if btype == k
                push!(bnd_ix, f)
            end
        end
        set_mesh_entity_tag!(g, BoundaryFaces(), :direction, k, bnd_ix)
    end
    return g
end

function generate_pinch_map(pinch, primitives, lines, column_lines, columns)
    pinch_top_to_bottom = Dict{Int, Int}()
    pinch_bottom_to_top = Dict{Int, Int}()

    if !ismissing(pinch)
        # Loop over columns, look for gaps
        (; pinch, minpv_removed) = pinch
        gap = uppercase(pinch[2]::AbstractString) == "GAP"
        @assert length(pinch) == 5
        thres = pinch[1]
        num_added = 0
        for (cl, col) in zip(column_lines, columns)
            number_of_cells_in_column = length(col.cells)
            current_column_lines = map(l -> lines[l], cl)

            start = 1
            while start < number_of_cells_in_column
                before_inactive, last_inactive, done = find_next_gap(col.cells, start)
                if done || before_inactive == last_inactive
                    break
                end
                top_cell = col.cells[before_inactive]
                bottom_cell = col.cells[last_inactive + 1]
                @assert top_cell != bottom_cell
                @assert top_cell > 0
                @assert bottom_cell > 0
                @assert col.cells[last_inactive] <= 0

                # Indices of face on the bottom of upper cell
                top_pos = map(l -> last(find_cell_bounds(top_cell, l)), current_column_lines)
                node_indices_top = map((line, i) -> line.nodes[i], current_column_lines, top_pos)

                bottom_pos = map(l -> first(find_cell_bounds(bottom_cell, l)), current_column_lines)
                node_indices_bottom = map((line, i) -> line.nodes[i], current_column_lines, bottom_pos)
                z(i) = primitives.nodes[i][3]
                z_face(ix) = (z(ix[1]) + z(ix[2]) + z(ix[3]) + z(ix[4]))/4.0
                depth_top = z_face(node_indices_top)
                depth_bottom = z_face(node_indices_bottom)
                start = last_inactive + 1
                inactive_cells = abs.(col.cells[(before_inactive+1):last_inactive])
                if depth_bottom - depth_top < thres || (gap && all(minpv_removed[inactive_cells]))
                    pinch_top_to_bottom[top_cell] = bottom_cell
                    pinch_bottom_to_top[bottom_cell] = top_cell
                    num_added += 1
                end
            end
        end
    end
    return (pinch_top_to_bottom, pinch_bottom_to_top)
end

function find_next_gap(cells, start)
    # For cells, starting at "start", find the next interval of negative values.
    # Function returns the position before the first negative value in the interval,
    # followed by the position of the next positive value, and a true/false
    # indicating if there are no more intervals.
    n = length(cells)
    if cells[start] <= 0
        rng = view(cells, (start+1):n)
        offset = findfirst(x -> x > 0, cells)
        if isnothing(offset)
            return (n, n, true)
        else
            start = start + offset - 1
        end
    end
    @assert cells[start] > 0
    stop = start + 1
    # Find next negative value
    rng = view(cells, (start+1):n)
    next_negative = findfirst(x -> x <= 0, rng)
    if isnothing(next_negative)
        return (n, n, true)
    else
        next_negative = next_negative + start - 1
    end

    rng = view(cells, (next_negative+1):n)
    next_positive = findfirst(x -> x > 0, rng)
    if isnothing(next_positive)
        return (n, n, true)
    else
        next_positive = next_positive + next_negative - 1
    end
    return (next_negative, next_positive, next_positive == n)
end
