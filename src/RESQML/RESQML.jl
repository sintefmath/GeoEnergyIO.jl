module RESQML
    using GeoEnergyIO, HDF5
    corner_index = GeoEnergyIO.CornerPointGrid.corner_index
    ijk_to_linear = GeoEnergyIO.CornerPointGrid.ijk_to_linear

    function linear_index(i, j, nx, ny)
        return (j - 1) * nx + i
    end

    function setup_column_pillar_mapping(gdata, pillar_dims)
        mapping = Dict{Tuple{Int, Int}, Int}()
        nxpillars, nypillars = pillar_dims
        nxcols = nxpillars - 1
        nycols = nypillars - 1
        # Handle standard part
        for col_i in 1:nxcols
            for col_j in 1:nycols
                col = linear_index(col_i, col_j, nxcols, nycols)
                for i_offset in (0, 1)
                    for j_offset in (0, 1)
                        pillar = linear_index(col_i + i_offset, col_j + j_offset, nxpillars, nypillars)
                        mapping[(col, pillar)] = pillar
                    end
                end
            end
        end

        # Handle split part by overwriting mapping
        pillar_ind = gdata["PillarIndices"]
        cpsl = get(gdata, "ColumnsPerSplitCoordinateLine", missing)
        if !ismissing(cpsl)
            cl = cpsl["cumulativeLength"]
            nsplitcols = length(cl)
            @assert length(pillar_ind) == nsplitcols
            num_normal_pillars = nxpillars * nypillars
            for splitcol in 1:nsplitcols
                if splitcol == 1
                    start = 1
                else
                    start = Int(cl[splitcol - 1]) + 1
                end
                pillar_index = Int(pillar_ind[splitcol]) + 1
                stop = Int(cl[splitcol])
                for ix in start:stop
                    col = Int(cpsl["elements"][ix]) + 1
                    # COMMENTED OUT FOR TESTING
                    mapping[(col, pillar_index)] = splitcol + num_normal_pillars
                end
            end
        end
        return mapping
    end

    function build_coord(coord)
        # coord is a 4D array with shape (3, nx, ny, 2)
        nx, ny = size(coord)[2:3]
        @assert size(coord, 1) == 3 "Expected coordinate array to have first dimension of size 3"
        out = Float64[]
        sizehint!(out, nx * ny * 6)
        for j in 1:ny
            for i in 1:nx
                for k in 1:2
                    x = coord[1, i, j, k]
                    y = coord[2, i, j, k]
                    z = coord[3, i, j, k]
                    push!(out, x, y, z)
                end
            end
        end
        return out
    end

    function build_zcorn(mapping, cartDims, pillar_depths)
        nx, ny, nz = cartDims
        zcorn = zeros(Float64, prod(cartDims) * 8)
        for cell_i in 1:nx
            for cell_j in 1:ny
                column = linear_index(cell_i, cell_j, nx, ny)
                for i_offset in (0, 1)
                    for j_offset in (0, 1)
                        pillar = linear_index(cell_i + i_offset, cell_j + j_offset, nx+1, ny+1)
                        pillar_depths_ix = mapping[(column, pillar)]
                        for cell_k in 1:nz
                            cell = ijk_to_linear(cell_i, cell_j, cell_k, cartDims)
                            for k_offset in (0, 1)
                                corner = (j_offset, i_offset, k_offset)
                                zcorn_ix = corner_index(cell, corner, cartDims)
                                zcorn[zcorn_ix] = pillar_depths[pillar_depths_ix, cell_k + k_offset]
                            end
                        end
                    end
                end
            end
        end
        return zcorn
    end

    function convert_to_grid_section(gdata::AbstractDict; actnum = missing, net_to_gross = missing, porosity = missing)
        out = Dict{String, Any}()
        # Coordinates of pillars
        coord = gdata["ControlPoints"]
        size(coord, 4) == 2 || error("Expected 4D coordinate array with last dimension of size 2")
        size(coord, 1) == 3 || error("Expected 4D coordinate array with first dimension of size 3")
        pillar_dims = size(coord)[2:3]
        # Corner point depths
        pillar_depths = gdata["PointParameters"]
        num_pillars, num_depths = size(pillar_depths)
        cartDims = (pillar_dims[1] - 1, pillar_dims[2] - 1, num_depths - 1)
        @assert num_pillars == prod(pillar_dims) + length(gdata["PillarIndices"])
        out["cartDims"] = cartDims
        # COORD is a vector
        out["COORD"] = build_coord(coord)
        mm = setup_column_pillar_mapping(gdata, pillar_dims)
        # ZCORN is a vector
        out["ZCORN"] = build_zcorn(mm, cartDims, pillar_depths)
        if !ismissing(net_to_gross)
            out["NTG"] = convert_grid_entry(net_to_gross, cartDims, "NET_TO_GROSS_RATIO", Float64)
        end
        if !ismissing(porosity)
            out["PORO"] = convert_grid_entry(porosity, cartDims, "POROSITY", Float64)
        end
        if !ismissing(actnum)
            out["ACTNUM"] = convert_grid_entry(actnum, cartDims, "ACTIVE_CELL_FLAG", Bool)
        end
        return out
    end

    function convert_grid_entry(x, cartDims, name, T = Float64)
        if x isa AbstractDict
            x = x["values"]
        end
        if eltype(x) != T
            x = T.(x)
        end
        if x isa AbstractVector && length(x) == prod(cartDims)
            x = reshape(x, cartDims)
        end
        size(x) == cartDims || error("Malformed $name array, expected size $(cartDims), got $(size(actnum))")
        return x
    end
end
