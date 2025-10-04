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

    # Tag columns as active or inactive
    active_columns = Matrix{Bool}(undef, nx, ny)
    for i in 1:nx
        for j in 1:ny
            is_active = false
            for k in 1:nz
                is_active = is_active || actnum[i, j, k]
                if is_active
                    break
                end
            end
            active_columns[i, j] = is_active
        end
    end
    active_lines = BitArray(undef, nlinex, nliney)
    for i in 1:nlinex
        for j in 1:nliney
            is_active = false
            for j_offset in (-1, 0)
                for i_offset in (-1, 0)
                    I = i + i_offset
                    J = j + j_offset
                    if I <= nx && J <= ny && I > 0 && J > 0 && active_columns[I, J]
                        is_active = true
                        break
                    end
                end
                if is_active
                    break
                end
            end
            active_lines[i, j] = is_active
        end
    end

    function generate_line(p1, p2, is_active)
        T_coord = promote_type(eltype(p1), eltype(p2), typeof(z_mean))
        if is_active
            line_length_hint = 8*(nz + 1)
            cell_hint = 4*nz
        else
            line_length_hint = cell_hint = 0
        end
        cell_bounds = sizehint!(Dict{Int, Tuple{Int, Int}}(), cell_hint)
        z = sizehint!(Vector{T_coord}(), line_length_hint)
        cells = sizehint!(Vector{Int}(), line_length_hint)
        cellpos = sizehint!(Vector{Int}(), cell_hint)
        nodes = sizehint!(Vector{Int}(), line_length_hint)

        return (
            z = z,
            cells = cells,
            cellpos = cellpos,
            nodes = nodes,
            x1 = SVector{3, T_coord}(p1),
            x2 = SVector{3, T_coord}(p2),
            cell_bounds = cell_bounds,
            equal_points = p1 ≈ p2,
            is_active = is_active
        )
    end
    # active_lines = BitArray(undef, nlinex, nliney)
    x1, x2 = get_line(coord, 1, 1, nlinex, nliney)
    line0 = generate_line(x1, x2, false)
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
    lines = Matrix{L_t}(undef, nlinex, nliney)
    for i in 1:nlinex
        for j in 1:nliney
            p1, p2 = get_line(coord, i, j, nlinex, nliney)
            lines[i, j] = generate_line(p1, p2, active_lines[i, j])
        end
    end
    for i = 1:nx
        for j = 1:ny
            for I1 in (0, 1)
                for I2 in (0, 1)
                    @inbounds L = lines[i + I2, j + I1]
                    if !L.is_active
                        continue
                    end
                    for k = 1:nz
                        ix = ijk_to_linear(i, j, k, cartdims)
                        active_cell_index = cell_index(i, j, k, actnum)
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
            if !L.is_active
                continue
            end
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
    # if true
    #     for i in eachindex(lines)
    #         if !lines_active[i]
    #             lines[i] = missing
    #         end
    #     end
    # end
    # GC.gc()

    # The four lines making up each column
    column_lines = Vector{NTuple{4, Int64}}()

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

function process_lines!(lines; sort_alg = QuickSort)
    if length(lines) > 0
        T = eltype(lines[1].z)
    else
        T = Float64
    end
    nodes = Vector{SVector{3, T}}()
    active_lines = BitVector(undef, length(lines))
    node_counter = 1
    p = Vector{Int}()
    for (line_ix, line) in enumerate(lines)
        z = line.z
        cells = line.cells
        active = length(z) > 0 && !all(x -> x <= 0, cells)
        active_lines[line_ix] = active
        if active
            resize!(p, length(z))
            sortperm!(p, z, alg = sort_alg)
            @inbounds permute!(z, p)
            @inbounds permute!(cells, p)
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
                sort!(ci, alg = sort_alg)
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

    cell_is_boundary(x) = x < 1
    ncells = length(active)
    I_faces = setup_face_helper(ncells, flipped, is_bnd = false)
    B_faces = setup_face_helper(ncells, flipped, is_bnd = true)

    nx, ny, nz = cartdims

    nlinex = nx+1
    nliney = ny+1

    # Lookup for extra nodes that are not in the pillars but are made due to intersections over faults.
    # The Float64 type is intentional.
    extra_node_lookup = Dict{SVector{3, Float64}, Int}()

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
                insert_face!(I_faces, B_faces, c1, c2, node_indices, is_vertical = false, is_boundary = is_bnd, is_idir = false, face_type = ft)
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
            cl::Tuple{Int, Int, Int, Int}
            @assert length(current_column_lines) == 4
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
                push!(pinched_faces, length(I_faces.face_pos))
                insert_face!(I_faces, B_faces, top_cell, bottom_cell, node_indices, is_vertical = false, is_boundary = false, is_idir = false, face_type = :bottom)
                pinch_count += 1
            end
        end
        @assert num_pinched == pinch_count
    end
    # Vertical faces
    T = @NamedTuple{cell::Int, line1::Tuple{Int, Int}, line2::Tuple{Int, Int}}
    ord_a = T[]
    ord_b = T[]
    for col_is_bnd in [true, false]
        if col_is_bnd
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

            F_interior = (l, r, node_indices) -> insert_face!(I_faces, B_faces, l, r, node_indices, is_boundary = false, is_vertical = true, is_idir = is_idir, face_type = conn_type)
            F_bnd = (l, r, node_indices) -> insert_face!(I_faces, B_faces, l, r, node_indices, is_boundary = true, is_vertical = true, is_idir = is_idir, face_type = conn_type)

            cell_top_bottom!(ord_a, col_a.cells, l1, l2)
            cell_top_bottom!(ord_b, col_b.cells, l1, l2)
            for pos_a in ord_a
                for pos_b in ord_b
                    overlap = find_linepair_overlap(pos_a, pos_b)
                    if isnothing(overlap)
                        continue
                    end
                    cat1, cat2 = overlap
                    l = pos_a.cell
                    r = pos_b.cell
                    l_bnd = cell_is_boundary(l)
                    r_bnd = cell_is_boundary(r)
                    if l_bnd && r_bnd
                        # Two inactive cells, can be skipped.
                        continue
                    end
                    cell_pair = (l, r)
                    pair_is_bnd = l_bnd || r_bnd
                    if col_is_bnd && pair_is_bnd
                        # Skip boundary faces that are already added as part of the horizontal processing
                        continue
                    end
                    if col_is_bnd || pair_is_bnd
                        # Boundary if we are on a boundary column or one of the cells connected to the face is a boundary
                        add_function = F_bnd
                    else
                        add_function = F_interior
                    end
                    add_vertical_face_from_overlap!(extra_node_lookup, add_function, nodes, cell_pair, overlap, l1, l2, node_buffer)
                end
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

        fp = I_faces.face_pos
        for nnc_entry in nnc
            c1 = cell_index(nnc_entry[1], nnc_entry[2], nnc_entry[3])
            c2 = cell_index(nnc_entry[4], nnc_entry[5], nnc_entry[6])
            if c1 > 0 && c2 > 0
                faceno = length(fp)
                c1 != c2 || error("NNC cell pair must be distinct.")
                # NNC connections have no nodes
                push!(fp, fp[end])
                push!(I_faces.neighbors, (c1, c2))
                push!(I_faces.cell_faces[c1], faceno)
                push!(I_faces.cell_faces[c2], faceno)
            else
                error("NNC connects inactive cells, cannot proceed: $(Tuple(nnc_entry[1:3])) -> $(Tuple(nnc_entry[4:6]))")
            end
        end
    end

    function convert_to_flat(v)
        flat_vals = Int[]
        flat_pos = Int[1]
        sizehint!(flat_pos, length(v)+1)
        sizehint!(flat_vals, sum(length, v))
        for cf in v
            for face in cf
                push!(flat_vals, face)
            end
            push!(flat_pos, flat_pos[end]+length(cf))
        end
        return (flat_vals, flat_pos)
    end

    c2f, c2f_pos = convert_to_flat(I_faces.cell_faces)
    b2f, b2f_pos = convert_to_flat(B_faces.cell_faces)

    g = UnstructuredMesh(
        c2f,
        c2f_pos,
        b2f,
        b2f_pos,
        I_faces.faces,
        I_faces.face_pos,
        B_faces.faces,
        B_faces.face_pos,
        primitives.nodes,
        I_faces.neighbors,
        B_faces.neighbors,;
        structure = CartesianIndex(cartdims[1], cartdims[2], cartdims[3]),
        cell_map = primitives.active,
        z_is_depth = true
    )
    # Pinch
    if length(pinched_faces) > 0
        set_mesh_entity_tag!(g, Faces(), :cpgrid_connection_type, :pinched, pinched_faces)
    end
    set_face_tags!(g, I_faces, is_bnd = false)
    set_face_tags!(g, B_faces, is_bnd = true)

    return g
end

function set_face_tags!(g, I_faces; is_bnd::Bool)
    if is_bnd
        e = BoundaryFaces()
    else
        e = Faces()
    end
    # Orientation
    if length(I_faces.horizontal_tag) > 0
        set_mesh_entity_tag!(g, e, :orientation, :horizontal, I_faces.horizontal_tag)
    end
    if length(I_faces.vertical_tag) > 0
        set_mesh_entity_tag!(g, e, :orientation, :vertical, I_faces.vertical_tag)
    end
    # IJK
    if length(I_faces.i_tag) > 0
        set_mesh_entity_tag!(g, e, :ijk_orientation, :i, I_faces.i_tag)
    end
    if length(I_faces.j_tag) > 0
        set_mesh_entity_tag!(g, e, :ijk_orientation, :j, I_faces.j_tag)
    end
    if length(I_faces.k_tag) > 0
        set_mesh_entity_tag!(g, e, :ijk_orientation, :k, I_faces.k_tag)
    end
    if is_bnd
        # Extra tag for boundary orientation
        for k in (:left, :right, :upper, :lower, :top, :bottom)
            orientation_ix = Vector{Int}()
            for (f, btype) in pairs(I_faces.type)
                if btype == k
                    push!(orientation_ix, f)
                end
            end
            set_mesh_entity_tag!(g, e, :direction, k, orientation_ix)
        end
    end
    return g
end

function setup_face_helper(ncells, flipped; is_bnd::Bool)
    # Faces mapping to nodes
    faces = Vector{Int}()
    face_pos = [1]
    nf_est = 3 * ncells

    # Mapping from cell to faces
    cell_faces = Vector{Vector{Int}}()
    sizehint!(cell_faces, ncells)

    for c in 1:ncells
        cf = Vector{Int}()
        if !is_bnd
            sizehint!(cf, 6)
        end
        push!(cell_faces, cf)
    end
    if is_bnd
        face_neighbors = Vector{Int}()
    else
        face_neighbors = Vector{Tuple{Int, Int}}()
        sizehint!(face_neighbors, nf_est)
    end
    boundary_cells = Vector{Int}()

    vertical_face_tag = Vector{Int}()
    horizontal_face_tag = Vector{Int}()
    i_face_tag = Vector{Int}()
    j_face_tag = Vector{Int}()
    k_face_tag = Vector{Int}()

    if !is_bnd
        for ft in [vertical_face_tag, horizontal_face_tag, i_face_tag, j_face_tag, k_face_tag]
            sizehint!(ft, nf_est)
        end
    end

    I_faces = (
        faces = faces,
        face_pos = face_pos,
        cell_faces = cell_faces,
        neighbors = face_neighbors,
        vertical_tag = vertical_face_tag,
        horizontal_tag = horizontal_face_tag,
        i_tag = i_face_tag,
        j_tag = j_face_tag,
        k_tag = k_face_tag,
        type = Dict{Int, Symbol}(),
        flipped = flipped
    )
    return I_faces
end

function add_face_from_nodes!(V, Vpos, nodes, flipped)
    n_local_nodes = length(nodes)
    @assert n_local_nodes > 2
    if flipped
        nodes = Base.Iterators.Reverse(nodes)
    end
    for n in nodes
        @assert n > 0
        push!(V, n)
    end
    push!(Vpos, length(nodes) + Vpos[end])
end

function insert_boundary_face!(B_faces, prev_cell, cell, nodes, is_vertical, is_idir, face_type)
    cell_is_boundary(x) = x < 1
    orient = cell_is_boundary(prev_cell) && !cell_is_boundary(cell)
    @assert orient || (cell_is_boundary(cell) && !cell_is_boundary(prev_cell)) "cell pair $((cell, prev_cell)) is not on boundary"
    if orient
        self = cell
    else
        self = prev_cell
        nodes = reverse(nodes)
    end
    boundary_faceno = length(B_faces.face_pos)
    add_face_from_nodes!(B_faces.faces, B_faces.face_pos, nodes, B_faces.flipped)
    push!(B_faces.cell_faces[self], boundary_faceno)
    push!(B_faces.neighbors, self)
    if is_vertical
        push!(B_faces.vertical_tag, boundary_faceno)
    else
        push!(B_faces.horizontal_tag, boundary_faceno)
    end
    B_faces.type[boundary_faceno] = face_type
    if is_idir
        push!(B_faces.i_tag, boundary_faceno)
        @assert face_type in (:left, :right)
    elseif is_vertical
        @assert face_type in (:upper, :lower)
        push!(B_faces.j_tag, boundary_faceno)
    else
        @assert face_type in (:top, :bottom)
        push!(B_faces.k_tag, boundary_faceno)
    end
    return B_faces
end

function insert_interior_face!(I_faces, prev_cell, cell, nodes, is_vertical, is_idir, face_type)
    @assert cell > 0
    @assert prev_cell > 0
    @assert prev_cell != cell
    faceno = length(I_faces.face_pos)
    add_face_from_nodes!(I_faces.faces, I_faces.face_pos, nodes, I_faces.flipped)
    # Note order here.
    push!(I_faces.neighbors, (prev_cell, cell))
    push!(I_faces.cell_faces[cell], faceno)
    push!(I_faces.cell_faces[prev_cell], faceno)
    if is_vertical
        push!(I_faces.vertical_tag, faceno)
    else
        push!(I_faces.horizontal_tag, faceno)
    end
    if is_idir
        push!(I_faces.i_tag, faceno)
    elseif is_vertical
        push!(I_faces.j_tag, faceno)
    else
        push!(I_faces.k_tag, faceno)
    end
    return I_faces
end

function insert_face!(I_faces, B_faces, prev_cell, cell, nodes; is_boundary, is_vertical, is_idir, face_type)
    if is_boundary
        insert_boundary_face!(B_faces, prev_cell, cell, nodes, is_vertical, is_idir, face_type)
    else
        insert_interior_face!(I_faces, prev_cell, cell, nodes, is_vertical, is_idir, face_type)
    end
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
