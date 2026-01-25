function finish_current_section!(data, units, cfg, outer_data, ::Val{:EDIT})

end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:BOX})
    rec = read_record(f)
    tdims = [1];
    gdata = get_section(outer_data, :GRID, set_current = false)
    l, u = gdata["CURRENT_BOX"]
    il, jl, kl = l
    iu, ju, ku = u

    il, iu, jl, ju, kl, ku = parse_defaulted_line(rec, [il, iu, jl, ju, kl, ku])
    gdata["CURRENT_BOX"] = (lower = (il, jl, kl), upper = (iu, ju, ku))
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:ENDBOX})
    reset_current_box!(outer_data)
end

function parse_keyword!(data, outer_data, units, cfg, f, kval::Union{Val{:COPY}, Val{:ADD}, Val{:MULTIPLY}})
    k = unpack_val(kval)
    is_copy = k == :COPY
    rec = read_record(f)
    gdata = get_section(outer_data, :GRID, set_current = false)
    l, u = gdata["CURRENT_BOX"]
    dims = get_cartdims(outer_data)
    d = "Default"

    il = l[1]
    iu = u[1]
    jl = l[2]
    ju = u[2]
    kl = l[3]
    ku = u[3]
    if is_copy
        d_op = d
    else
        d_op = NaN
    end

    while length(rec) > 0
        parsed = parse_defaulted_line(rec, [d, d_op, il, iu, jl, ju, kl, ku])
        if is_copy
            dst = parsed[2]
            src = parsed[1]
            op = NaN
            @assert src != d "Source was defaulted for $k. rec = $rec"
        else
            dst = parsed[1]
            op = parsed[2]
            src = missing
            @assert op != d_op "Operator was defaulted for $k. rec = $rec"
        end
        @assert dst != d "Destination was defaulted for $k. rec = $rec"

        # Box can be kept.
        il = parsed[3]
        iu = parsed[4]
        jl = parsed[5]
        ju = parsed[6]
        kl = parsed[7]
        ku = parsed[8]
        IJK = get_box_indices(outer_data, il, iu, jl, ju, kl, ku)
        if is_copy
            if !haskey(data, dst)
                if !haskey(data, src)
                    parser_message(cfg, outer_data, "$k", "Cannot apply when source $src has not been defined. Skipping.")
                    return data
                end
                T = eltype(data[src])
                stdval = keyword_default_value(dst, T)
                data[dst] = fill(stdval, dims)
            end
            apply_copy!(data[dst], data[src], IJK, dims)
        else
            if !haskey(data, dst)
                stdval = keyword_default_value(dst, typeof(op))
                data[dst] = fill(stdval, dims)
            end
            if k == :ADD
                # add is a const
                u = unit_type(dst)
                op = swap_unit_system(op, units, u)
                apply_add!(data[dst], op, IJK, dims)
            else
                # multiply is a const
                apply_multiply!(data[dst], op, IJK, dims)
            end
        end
        rec = read_record(f)
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, kval::Val{:MULTIREG})
    k = unpack_val(kval)
    rec = read_record(f)
    gdata = get_section(outer_data, :GRID, set_current = false)
    dims = get_cartdims(outer_data)

    while length(rec) > 0
        dst, val, fluxreg, regtype = parse_defaulted_line(rec, ["Name", 0.0, -1, "M"])
        @assert dst != "Name" "Name cannot be defaulted for MULTIREG"
        if dst == "PORV"
            # We hack this in by setting PVMULT instead.
            dst = "PVMULT"
        end
        if !haskey(data, dst)
            stdval = keyword_default_value(dst, Float64)
            data[dst] = fill(stdval, dims)
        end
        destination_vals = data[dst]
        if regtype == "M"
            reg_key = "MULTNUM"
        elseif regtype == "F"
            reg_key = "FLUXNUM"
        else
            @assert regtype == "O"
            reg_key = "OPERNUM"
        end
        reg = gdata[reg_key]
        ix = findall(isequal(fluxreg), reg)
        @. destination_vals[ix] *= val
        rec = read_record(f)
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:OPERATE})
    rec = read_record(f)
    gdata = get_section(outer_data, :GRID, set_current = false)
    l, u = gdata["CURRENT_BOX"]
    dims = get_cartdims(outer_data)

    il = l[1]
    iu = u[1]
    jl = l[2]
    ju = u[2]
    kl = l[3]
    ku = u[3]

    while length(rec) > 0
        d = "Default"
        parsed = parse_defaulted_line(rec, [d, il, iu, jl, ju, kl, ku, d, d, NaN, NaN])
        target = parsed[1]
        op = parsed[8]
        source = parsed[9]
        @assert target != d "Target was defaulted? rec = $rec"
        @assert op != d "Operator was defaulted? rec = $rec"
        @assert source != d "Source was defaulted? rec = $rec"

        # Box can be kept.
        il = parsed[2]
        iu = parsed[3]
        jl = parsed[4]
        ju = parsed[5]
        kl = parsed[6]
        ku = parsed[7]

        op_prm1 = parsed[10]
        op_prm2 = parsed[11]

        IJK = get_box_indices(outer_data, il, iu, jl, ju, kl, ku)
        if target == source && op == "MULTX" && startswith(target, "TRAN")
            handle_multxyz_as_operate!(outer_data, target, IJK, op_prm1)
        else
            operation_target = get_operation_section(outer_data, target)
            operation_source = get_operation_section(outer_data, source)
            if ismissing(operation_target)
                data[target] = zeros(dims)
                operation_target = data[target]
            end
            apply_operate!(operation_target, operation_source, IJK, op, op_prm1, op_prm2)
        end
        # On to the next one.
        rec = read_record(f)
    end
end

function handle_multxyz_as_operate!(outer_data, target, IJK, val)
    # A special fix to handle the fact that we don't really initialize
    # TRANX/TRANY/TRANZ arrays and this special case operation can be
    # reformulated as MULTX/MULTY/MULTZ.
    # TODO: Make a bit more general.
    grid = outer_data["GRID"]
    dir = target[end]
    alternative_key = "MULT$dir"
    if !haskey(grid, alternative_key)
        grid[alternative_key] = ones(Float64, grid["cartDims"]...)
    end
    I, J, K = IJK
    vals = grid[alternative_key]
    for i in I
        for j in J
            for k in K
                vals[i, j, k] *= val
            end
        end
    end
end

function apply_operate!(target, source, IJK, op, prm1, prm2)
    I, J, K = IJK
    op = lowercase(op)
    if op == "multx"
        F = (t, s) -> prm1*s
    elseif op == "addx"
        F = (t, s) -> s + prm1
    elseif op == "multa"
        F = (t, s) -> prm1*s + prm2
    elseif op == "abs"
        F = (t, s) -> abs(s)
    elseif op ==  "loge"
        F = (t, s) -> ln(s)
    elseif op ==  "log10"
        F = (t, s) -> log10(s)
    elseif op ==  "slog"
        F = (t, s) -> 10^(prm1 + prm2*s)
    elseif op ==  "poly"
        F = (t, s) -> t + prm1*s^prm2
    elseif op ==  "inv"
        F = (t, s) -> 1.0/s
    elseif op == "multiply"
        F = (t, s) -> t*s
    elseif op == "multp"
        F = (t, s) -> prm1*s^prm2
    elseif op == "minlim"
        F = (t, s) -> max(prm1, s)
    elseif op == "maxlim"
        F = (t, s) -> min(prm1, s)
    elseif op == "copy"
        F = (t, s) -> s
    else
        error("OPERATE option $(uppercase(op)) is not implemented.")
    end
    for i in I
        for j in J
            for k in K
                target[i, j, k] = F(target[i, j, k], source[i, j, k])
            end
        end
    end
end

function apply_copy!(vals, src, IX, dims)
    I, J, K = IX
    vals[I, J, K] = src[I, J, K]
end

function apply_add!(vals, src, IX, dims)
    I, J, K = IX
    vals[I, J, K] .+= src
end

function apply_multiply!(vals, src, IX, dims)
    I, J, K = IX
    vals[I, J, K] .*= src
end

function get_operation_section(outer_data, kw)
    for (k, data) in pairs(outer_data)
        if data isa AbstractDict && haskey(data, kw)
            return data[kw]
        end
    end
    if kw in ("TRANX", "TRANY", "TRANZ")
        # These can safely be initialized as NaN arrays.
        data = outer_data["GRID"]
        dims = data["cartDims"]
        data[kw] = fill(NaN, dims)
        return data[kw]
    end
    return missing
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:MULTIPLY})
    # TODO: Merge shared code with COPY
    rec = read_record(f)
    grid = outer_data["GRID"]
    l, u = grid["CURRENT_BOX"]
    dims = grid["cartDims"]

    il = l[1]
    iu = u[1]
    jl = l[2]
    ju = u[2]
    kl = l[3]
    ku = u[3]

    while length(rec) > 0
        d = "Default"
        parsed = parse_defaulted_line(rec, [d, 1.0, il, iu, jl, ju, kl, ku])
        dst = parsed[1]
        factor = parsed[2]
        @assert dst != "Default"

        # Box can be kept.
        il = parsed[3]
        iu = parsed[4]
        jl = parsed[5]
        ju = parsed[6]
        kl = parsed[7]
        ku = parsed[8]
        Ibox, Jbox, Kbox = (il, iu), (jl, ju), (kl, ku)
        do_apply = true
        if dst == "PORV" && haskey(grid, "PORO")
            # TODO: Bit of a hack
            target = grid["PORO"]
        elseif dst in ("TRANX", "TRANY", "TRANZ")
            dir = dst[end]
            push_and_create!(data, "MULTRAN$dir", [(i = Ibox, j = Jbox, k = Kbox, factor = factor)])
            do_apply = false
        else
            target = get_operation_section(outer_data, dst)
            if ismissing(target)
                do_apply = false
                parser_message(cfg, outer_data, "MULTIPLY", "Unable to apply MULTIPLY to non-declared field $dst. Skipping.")
            end
        end
        if do_apply
            apply_multiply!(target, factor, Ibox, Jbox, Kbox, dims)
        end
        rec = read_record(f)
    end
end

function apply_multiply!(target::AbstractVector, factor, I, J, K, dims)
    apply_multiply!(reshape(target, dims), factor, I, J, K, dims)
end


function apply_multiply!(target, factor, I, J, K, dims)
    for i in I[1]:I[2]
        for j in J[1]:J[2]
            for k in K[1]:K[2]
                target[i, j, k] *= factor
            end
        end
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:EQUALS})
    # TODO: Merge shared code with COPY
    rec = read_record(f)
    l, u = outer_data["GRID"]["CURRENT_BOX"]
    dims = outer_data["GRID"]["cartDims"]

    il = l[1]
    iu = u[1]
    jl = l[2]
    ju = u[2]
    kl = l[3]
    ku = u[3]

    while length(rec) > 0
        d = "Default"
        parsed = parse_defaulted_line(rec, [d, 1.0, il, iu, jl, ju, kl, ku])
        dst = parsed[1]
        u = unit_type(dst)
        constval = swap_unit_system(parsed[2], units, u)
        @assert dst != "Default"
        target = get_operation_section(outer_data, dst)
        if ismissing(target)
            # TODO: Different keywords go in different spots...
            data[dst] = fill(NaN, dims...)
            target = data[dst]
        end
        # Box can be kept.
        il = parsed[3]
        iu = parsed[4]
        jl = parsed[5]
        ju = parsed[6]
        kl = parsed[7]
        ku = parsed[8]
        apply_equals!(target, constval, (il, iu), (jl, ju), (kl, ku), dims)
        rec = read_record(f)
    end
end

function apply_equals!(target, constval, I, J, K, dims)
    for i in I[1]:I[2]
        for j in J[1]:J[2]
            for k in K[1]:K[2]
                target[i, j, k] = constval
            end
        end
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:MAXVALUE})
    edit_apply_clamping!(f, outer_data, units, min)
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:MINVALUE})
    edit_apply_clamping!(f, outer_data, units, max)
end

function edit_apply_clamping!(f, outer_data, units, FUNCTION)
    rec = read_record(f)
    l, u = outer_data["GRID"]["CURRENT_BOX"]
    dims = outer_data["GRID"]["cartDims"]

    il = l[1]
    iu = u[1]
    jl = l[2]
    ju = u[2]
    kl = l[3]
    ku = u[3]

    while length(rec) > 0
        d = "Default"
        parsed = parse_defaulted_line(rec, [d, 1.0, il, iu, jl, ju, kl, ku])
        dst = parsed[1]
        u = unit_type(dst)
        lim = swap_unit_system(parsed[2], units, u)

        @assert dst != "Default"
        target = get_operation_section(outer_data, dst)
        # Box can be kept.
        il = parsed[3]
        iu = parsed[4]
        jl = parsed[5]
        ju = parsed[6]
        kl = parsed[7]
        ku = parsed[8]
        apply_equals!(target, lim, (il, iu), (jl, ju), (kl, ku), dims)
        rec = read_record(f)
    end
end

function apply_minmax!(target, lim, I, J, K, dims, F)
    for i in I[1]:I[2]
        for j in J[1]:J[2]
            for k in K[1]:K[2]
                target[i, j, k] = F(target[i, j, k], lim)
            end
        end
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, ::Val{:EDITNNC})
    rec = read_record(f)
    while length(rec) > 0
        parsed = parse_defaulted_line(rec, [-1, -1, -1, -1, -1, -1, 1.0, 0, 0, 0, 0, "X+", "X+", 0.0])
        # Box can be kept.
        il = parsed[1]
        iu = parsed[2]
        jl = parsed[3]
        ju = parsed[4]
        kl = parsed[5]
        ku = parsed[6]
        il > 0 || error("I lower was defaulted in EDITNNC.")
        iu > 0 || error("I upper was defaulted in EDITNNC.")
        jl > 0 || error("J lower was defaulted in EDITNNC.")
        ju > 0 || error("J upper was defaulted in EDITNNC.")
        kl > 0 || error("K lower was defaulted in EDITNNC.")
        ku > 0 || error("K upper was defaulted in EDITNNC.")
        Ibox, Jbox, Kbox = (il, iu), (jl, ju), (kl, ku)
        push_and_create!(data, "EDITNNC", [(i = Ibox, j = Jbox, k = Kbox, trans = parsed[7], diffuse = parsed[end])])
        rec = read_record(f)
    end
    return data
end
