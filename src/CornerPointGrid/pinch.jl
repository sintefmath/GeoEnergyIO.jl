function handle_pinch!(actnum, zcorn, cartdims, pinch)
    if ismissing(pinch)
        pinch = 0.001
    end
    nx, ny, nz = cartdims
    # Note: Remapped is from and to logical indices since this can potentially
    # modify ACTNUM.
    remapped = Dict{Int, Int}()
    pinched = fill(false, nz)
    pinch_count = 0
    for i in 1:nx
        for j in 1:ny
            pinched .= false
            prev_active = 0
            pinch_found_in_col = false
            for k in 1:nz
                linear_ix = ijk_to_linear(i, j, k, cartdims)
                active = actnum[i, j, k]
                if active
                    get_zcorn(I1, I2, I3) = zcorn[corner_index(linear_ix, (I1, I2, I3), cartdims)]
                    get_pair(I, J) = (get_zcorn(I, J, 0), get_zcorn(I, J, 1))

                    # Check if cross part is small
                    # Check if maximum width is small
                    l_11, t_11 = get_pair(0, 0)
                    l_12, t_12 = get_pair(0, 1)
                    l_21, t_21 = get_pair(1, 0)
                    l_22, t_22 = get_pair(1, 1)

                    d_11 = t_11 - l_11
                    d_12 = t_12 - l_12
                    d_21 = t_21 - l_21
                    d_22 = t_22 - l_22

                    pinched_simple = max(d_11, d_12, d_21, d_22) <= pinch
                    cell_is_pinched = pinched_simple

                    pinched[k] = cell_is_pinched
                    pinch_count += cell_is_pinched

                    pinch_found_in_col = pinch_found_in_col || cell_is_pinched
                end
            end
            if !pinch_found_in_col
                continue
            end

            for k in 1:nz
                if !pinched[k]
                    continue
                end
                actnum[i, j, k] = false

                if k > 1
                    prev_ix = ijk_to_linear(i, j, k-1, cartdims)
                    linear_ix = ijk_to_linear(i, j, k, cartdims)
                    # Could have a section of inactive cells, so look up just in case.
                    if haskey(remapped, prev_ix)
                        new_index = remapped[prev_ix]
                    else
                        if !actnum[i, j, k-1]
                            continue
                        end
                        new_index = prev_ix
                    end
                    remapped[linear_ix] = prev_ix
                end
            end
        end
    end
    return (actnum, remapped)
end
