function unpack_val(::Val{X}) where X
    return X
end

const DECK_SPLIT_REGEX = r"[ \t,]+"

function read_record(f; fix = true)
    split_lines = Vector{String}()
    active = true
    while !eof(f) && active
        line = readline(f)
        cpos = findfirst("--", line)
        if !isnothing(cpos)
            line = line[1:(first(cpos)-1)]
        end
        line = strip(line)
        if !startswith(line, "--")
            line = String(line)
            if contains(line, '/')
                # TODO: Think this is OK for parsing ASCII.
                ix = findfirst('/', line)
                line = line[1:ix-1]
                active = false
            end
            line::String
            if length(line) > 0
                push!(split_lines, line)
            end
        end
    end
    return split_lines
end

function keyword_start(line)
    if isnothing(match(r"^\s*--", line))
        m = match(r"\w+", line)
        if m === nothing
            return nothing
        else
            return Symbol(uppercase(m.match))
        end
    else
        return nothing
    end
end

function parse_defaulted_group_well(f, defaults, wells, namepos = 1)
    out = []
    line = read_record(f)
    while length(line) > 0
        allow_wildcard = fill(true, length(defaults))
        allow_wildcard[1] = false
        parsed = parse_defaulted_line(line, defaults, allow_wildcard = allow_wildcard)
        name = parsed[namepos]
        if occursin('*', name) || occursin('?', name)
            re = Regex(replace(name, "*" => ".*", "?" => "."))
            for wname in keys(wells)
                if occursin(re, wname)
                    replaced_parsed = copy(parsed)
                    replaced_parsed[namepos] = wname
                    push!(out, replaced_parsed)
                end
            end
        else
            push!(out, parsed)
        end
        line = read_record(f)
    end
    return out
end

function parse_defaulted_group(f, defaults)
    out = []
    line = read_record(f)
    while length(line) > 0
        parsed = parse_defaulted_line(line, defaults)
        push!(out, parsed)
        line = read_record(f)
    end
    return out
end

function parse_defaulted_line(lines::String, defaults; kwarg...)
    return parse_defaulted_line([lines], defaults; kwarg...)
end

function parse_defaulted_line(lines, defaults; required_num = 0, keyword = "", allow_wildcard = missing)
    out = similar(defaults, 0)
    sizehint!(out, length(defaults))
    pos = 1
    for line in lines
        line = replace_quotes(line)
        lsplit = split(strip(line), DECK_SPLIT_REGEX)
        for s in lsplit
            if length(s) == 0
                continue
            end
            default = defaults[pos]
            if ismissing(allow_wildcard)
                allow_star = true
            else
                allow_star = allow_wildcard[pos]
            end
            if allow_star && occursin('*', s) && !startswith(s, '\'') # Could be inside a string for wildcard matching
                if s == "*"
                    num_defaulted = 1
                else
                    parse_wildcard = match(r"\d+\*", s)
                    if isnothing(parse_wildcard)
                        error("Unable to parse string for * expansion: $s")
                    end
                    num_defaulted = Parsers.parse(Int, parse_wildcard.match[1:end-1])
                end
                for i in 1:num_defaulted
                    push!(out, defaults[pos])
                    pos += 1
                end
            else
                if default isa String
                    converted = strip(s, [' ', '\''])
                else
                    T = typeof(default)
                    converted = Parsers.tryparse(T, s)
                    if isnothing(converted)
                        converted = T.(Parsers.tryparse(Float64, s))
                    end
                end
                push!(out, converted)
                pos += 1
            end
        end
    end
    n = length(defaults)
    n_out = length(out)
    if required_num > n
        error("Bad record: $required_num entries required for keyword $keyword, but only $n records were present.")
    end
    pos = n_out + 1
    if pos < n + 1
        for i in pos:n
            push!(out, defaults[i])
        end
    end
    return out
end

##

function parse_deck_matrix(f, T = Float64)
    # TODO: This is probably a bad way to do large numerical datasets.
    rec = read_record(f)
    split_lines = preprocess_delim_records(rec)
    data = Vector{T}()
    n = -1
    for seg in split_lines
        n = parse_deck_matrix_line!(data, seg, n)
    end
    if length(data) == 0
        out = missing
    else
        out = reshape(data, n, length(data) ÷ n)'
    end
    return out
end

function parse_deck_matrix_line!(data::Vector{T}, seg, n) where T
    m = length(seg)
    if m == 0
        return n
    elseif n == -1
        n = m
    else
        @assert m == n "Expected $n was $m"
    end
    for d in seg
        if d == raw"1*"
            # Defaulted...
            @assert T == Float64
            push!(data, NaN)
        else
            push!(data, Parsers.parse(T, d))
        end
    end
    return n
end

function preprocess_delim_records(split_lines)
    # Old slow code:
    # split_lines = map(strip, split_lines)
    # filter!(x -> !startswith(x, "--"), split_lines)
    # split_rec = map(x -> split(x, r"\s*,?\s+"), split_lines)
    split_rec = Vector{Vector{String}}()
    sizehint!(split_rec, length(split_lines))
    for line in split_lines
        # Strip end whitespace
        line = strip(line)
        # Remove comments
        if !startswith(line, "--")
            # Split into entries (could be whitespace + a comma anywhere in between)
            sub_rec = Vector{String}()
            sizehint!(sub_rec, 10)
            for rec in eachsplit(line, r"\s*,?\s+")
                push!(sub_rec, String(rec))
            end
            if length(sub_rec) > 0
                push!(split_rec, sub_rec)
            end
        end
    end
    return split_rec
end

function parse_deck_vector(f, T = Float64)
    # TODO: Speed up.
    rec = read_record(f)
    opts = Parsers.Options()
    record_lines = preprocess_delim_records(rec)
    n = length(record_lines)
    out = Vector{T}()
    Val_T = Val(T)
    sizehint!(out, n)
    return parse_records_with_repeats!(out, record_lines, Val_T, opts)
end

function parse_records_with_repeats!(out, record_lines, Val_T, opts)
    for split_rec in record_lines
        for el in split_rec
            parsed, n_rep = parse_and_handle_repeats(Val_T, el, opts)
            for i in 1:n_rep
                push!(out, parsed)
            end
        end
    end
    return out
end

function parse_and_handle_repeats(::Val{T}, el::String, opts) where T
    val = Parsers.tryparse(T, el)
    if isnothing(val)
        # String on the form "123*3.14" where the first number is repeat count
        # and the second will be parsable as type T
        wildcard = findfirst(isequal('*'), el)
        n_rep = Parsers.parse(Int, el, opts, 1, wildcard-1)
        val = Parsers.parse(T, el, opts, wildcard+1)
    else
        n_rep = 1
    end
    (val, n_rep)::Tuple{T, Int}
end

function skip_record(f)
    rec = read_record(f)
    while length(rec) > 0
        rec = read_record(f)
    end
end

function skip_records(f, n)
    for i = 1:n
        rec = read_record(f)
    end
end

function parse_grid_vector(f, dims, T = Float64)
    v = parse_deck_vector(f, T)
    return reshape(v, dims)
end

function parse_saturation_table(f, outer_data)
    ns = number_of_tables(outer_data, :satnum)
    return parse_region_matrix_table(f, ns)
end

function parse_dead_pvt_table(f, outer_data)
    np = number_of_tables(outer_data, :pvtnum)
    return parse_region_matrix_table(f, np)
end

function parse_live_pvt_table(f, outer_data)
    nreg = number_of_tables(outer_data, :pvtnum)
    out = []
    for i = 1:nreg
        current = Vector{Vector{Float64}}()
        while true
            next = parse_deck_vector(f)
            if length(next) == 0
                break
            end
            push!(current, next)
        end
        push!(out, restructure_pvt_table(current))
    end
    return out
end

function restructure_pvt_table(tab)
    nvals_per_rec = 3
    function record_length(x)
        # Actual number of records: 1 key value + nrec*N entries. Return N.
        return (length(x) - 1) ÷ nvals_per_rec
    end
    @assert record_length(last(tab)) > 1
    nrecords = length(tab)
    keys = map(first, tab)
    current = 1
    for tab_ix in eachindex(tab)
        rec = tab[tab_ix]
        interpolate_missing_usat!(tab, tab_ix, record_length, nvals_per_rec)
    end
    # Generate final table
    ntab = sum(record_length, tab)
    data = zeros(ntab, nvals_per_rec)
    for tab_ix in eachindex(tab)
        rec = tab[tab_ix]
        for i in 1:record_length(rec)
            for j in 1:nvals_per_rec
                linear_ix = (i-1)*nvals_per_rec + j + 1
                data[current, j] = rec[linear_ix]
            end
            current += 1
        end
    end

    # Generate pos
    pos = Int[1]
    sizehint!(pos, nrecords+1)
    for rec in tab
        push!(pos, pos[end] + record_length(rec))
    end
    return Dict("data" => data, "key" => keys, "pos" => pos)
end

function interpolate_missing_usat!(tab, tab_ix, record_length, nvals_per_rec)
    rec = tab[tab_ix]
    if record_length(rec) == 1
        @assert nvals_per_rec == 3
        next_rec = missing
        for j in (tab_ix):length(tab)
            if record_length(tab[j]) > 1
                next_rec = tab[j]
                break
            end
        end
        @assert record_length(rec) == 1
        next_rec_length = record_length(next_rec)
        sizehint!(rec, 1 + nvals_per_rec*next_rec_length)

        get_index(major, minor) = nvals_per_rec*(major-1) + minor + 1
        pressure(x, idx) = x[get_index(idx, 1)]
        B(x, idx) = x[get_index(idx, 2)]
        viscosity(x, idx) = x[get_index(idx, 3)]

        function constant_comp_interp(F, F_r, F_l)
            # So that dF/dp * F = constant over the pair of points extrapolated from F
            w = 2.0*(F_l - F_r)/(F_l + F_r)
            return F*(1.0 + w/2.0)/(1.0 - w/2.0)
        end
        @assert !ismissing(next_rec) "Final table must be saturated."

        for idx in 2:next_rec_length
            # Each of these gets added as new unsaturated points
            p_0 = pressure(rec, idx - 1)
            p_l = pressure(next_rec, idx - 1)
            p_r = pressure(next_rec, idx)

            mu_0 = viscosity(rec, idx - 1)
            mu_l = viscosity(next_rec, idx - 1)
            mu_r = viscosity(next_rec, idx)

            B_0 = B(rec, idx - 1)
            B_l = B(next_rec, idx - 1)
            B_r = B(next_rec, idx)

            p_next = p_0 + p_r - p_l
            B_next = constant_comp_interp(B_0, B_l, B_r)
            mu_next = constant_comp_interp(mu_0, mu_l, mu_r)

            push!(rec, p_next)
            push!(rec, B_next)
            push!(rec, mu_next)
        end
    end
    return tab
end

function parse_region_matrix_table(f, nreg)
    out = []
    for i = 1:nreg
        next = parse_deck_matrix(f)
        if ismissing(next)
            if length(out) == 0
                error("First region table cannot be defaulted.")
            end
            next = copy(out[end])
        end
        push!(out, next)
    end
    return out
end

function parse_keyword!(data, outer_data, units, cfg, f, v::Val{T}) where T
    # Keywords where we read a single record and don't do anything proper
    found = false
    kw_str = "$T"
    for (kw, num, msg) in KEYWORD_SKIP_LIST
        if kw != T
            continue
        end
        if !isnothing(msg)
            parser_message(cfg, outer_data, "$kw", msg)
        end
        if num == 0
            # Single word keywords are trivial to parse, just set a true flag.
            data[kw_str] = true
        elseif num == 1
            data[kw_str] = read_record(f)
        else
            skip_record(f)
        end
        found = true
        break
    end

    if !found
        section = outer_data["CURRENT_SECTION"]
        if startswith(kw_str, "TVDP")
            parser_message(cfg, outer_data, kw_str, PARSER_MISSING_SUPPORT)
            read_record(f)
        elseif section == :REGIONS
            data[kw_str] = parse_and_set_grid_data!(data, outer_data, units, cfg, f, T, T = Int)
        elseif section in (:GRID, :EDIT, :SOLUTION)
            data[kw_str] = parse_and_set_grid_data!(data, outer_data, units, cfg, f, T, T = Float64)
        else
            error("Unhandled keyword $T in $section encountered.")
        end
    end
    return data
end

function failure_print_line_context(f; kw = nothing)
    lno, line = failure_line_number(f)
    jutul_message("Parser", "Parsing halted at line $lno.\nContext: $(f.name):", color = :red)
    if !isnothing(kw)
        println("Parsing failure happened during keyword $kw")
    end
    println("L$lno: $line")
end

function failure_line_number(f)
    pos = mark(f)
    seek(f, 0)
    lno_prev = 0
    line_prev = ""
    for (lno, line) in enumerate(eachline(f))
        if position(f) > pos
            break
        end
        lno_prev = lno
        line_prev = line
    end
    reset(f)
    return (lno_prev, line_prev)
end

function next_keyword!(f)
    m = nothing
    while isnothing(m) && !eof(f)
        line = strip(readline(f))
        if line == "/"
            continue
        end
        m = keyword_start(line)
    end
    return m
end

"""
    number_of_tables(outer_data, t::Symbol)

Number of declared tables for given type `t`. Should be one of the following:
 - `:satnum` (saturation function region)
 - `:pvtnum` (PVT function region)
 - `:eqlnum` (equilibriation region)
 - `:eosnum` (equation-of-state region)
"""
function number_of_tables(outer_data, t::Symbol)
    rs = outer_data["RUNSPEC"]
    if haskey(rs, "TABDIMS")
        td = rs["TABDIMS"]
    else
        td = [1 1]
    end
    if t == :satnum
        return td[1]
    elseif t == :pvtnum
        return td[2]
    elseif t == :eqlnum
        if haskey(rs, "EQLDIMS")
            return rs["EQLDIMS"][1]
        else
            return 1
        end
    elseif t == :eosnum
        if haskey(rs, "TABDIMS")
            return rs["TABDIMS"][9]
        else
            return 1
        end
    elseif t == :nplmix
        if haskey(rs, "REGDIMS")
            return rs["REGDIMS"][10]
        else
            return 1
        end
    end
    error(":$t is not known")
end

function aquifer_dimensions(outer_data, t::Symbol)
    rs = outer_data["RUNSPEC"]
    aqudims = get(rs, "AQUDIMS", [1, 1, 1, 36, 1, 1, 0, 0])
    if t == :MXNAQN || t == :NANAQU
        return max(aqudims[1], aqudims[5])
    elseif t == :MXNAQC || t == :NCAMAX
        return max(aqudims[2], aqudims[6])
    elseif t == :NIFTBL
        return aqudims[3]
    elseif t == :NRIFTB
        return aquadims[4]
    elseif t == :MXNALI
        return aquadims[7]
    elseif t == :MXAAQL
        return aquadims[8]
    end
    error(":$t is not known")
end

function compositional_number_of_components(outer_data)
    return outer_data["RUNSPEC"]["COMPS"]
end

"""
    region = get_data_file_cell_region(data, t::Symbol; active = nothing)
    satnum = get_data_file_cell_region(data, :satnum)
    pvtnum = get_data_file_cell_region(data, :pvtnum, active = 1:10)

Get the region indicator of some type for each cell of the domain stored in
`data` (the output from [`parse_data_file`](@ref)). The optional keyword
argument `active` can be used to extract the values for a subset of cells.

`t` should be one of the following:
- `:satnum` (saturation function region)
- `:pvtnum` (PVT function region)
- `:eqlnum` (equilibriation region)
- `:eosnum` (equation-of-state region)
"""
function get_data_file_cell_region(outer_data, t::Symbol; active = nothing)
    num = number_of_tables(outer_data, t)
    if num == 1
        dim = outer_data["GRID"]["cartDims"]
        D = ones(Int, prod(dim))
    else
        reg = outer_data["REGIONS"]

        function get_or_default(k)
            if haskey(reg, k)
                tmp = vec(reg[k])
                if any(isnan, tmp)
                    # Hope these get removed by ACTNUM
                    @. tmp[isnan(tmp)] = 1
                end
                return Int.(tmp)
            else
                dim = outer_data["GRID"]["cartDims"]
                return ones(Int, prod(dim))
            end
        end

        if t == :satnum
            d = get_or_default("SATNUM")
        elseif t == :pvtnum
            d = get_or_default("PVTNUM")
        elseif t == :eqlnum
            d = get_or_default("EQLNUM")
        else
            error(":$t is not known")
        end
        D = vec(d)
    end
    if !isnothing(active)
        D = D[active]
    end
    return D
end

function clean_include_path(basedir, include_file_name)
    m = match(r"'[^']*'", include_file_name)
    if !isnothing(m)
        # Strip away anything that isn't '
        include_file_name = m.match[2:end-1]
    end
    include_file_name = strip(include_file_name)
    include_file_name = replace(include_file_name, '\\' => '/')
    if startswith(include_file_name, "./")
        include_file_name = include_file_name[3:end]
    end
    include_file_name = replace(include_file_name, "'" => "")
    # Do this one more time in case we have nested string and ./
    if startswith(include_file_name, "./")
        include_file_name = include_file_name[3:end]
    end
    pos = findlast(" /", include_file_name)
    if !isnothing(pos)
        include_file_name = include_file_name[1:pos[1]-1]
    end
    include_path = joinpath(basedir, include_file_name)
    return include_path
end

function get_section(outer_data, name::Symbol; set_current = true)
    s = "$name"
    is_sched = name == :SCHEDULE
    if set_current
        outer_data["CURRENT_SECTION"] = name
    end
    T = OrderedDict{String, Any}
    if is_sched
        if !haskey(outer_data, s)
            outer_data[s] = Dict(
                "STEPS" => [T()],
                "WELSPECS" => T(),
                "COMPORD" => T()
            )
        end
        out = outer_data[s]["STEPS"][end]
    else
        if !haskey(outer_data, s)
            outer_data[s] = T()
        end
        out = outer_data[s]
    end
    return out
end

function new_section(outer_data, name::Symbol)
    data = get_section(outer_data, name)
    return data
end

function replace_quotes(str::String)
    if '\'' in str
        v = collect(str)
        in_quote = false
        new_char = Char[]
        for i in eachindex(v)
            v_i = v[i]
            if v_i == '\''
                in_quote = !in_quote
            elseif in_quote && v_i == ' '
                # TODO: Is this a safe replacement?
                push!(new_char, '-')
            else
                push!(new_char, v_i)
            end
        end
        str = String(new_char)
    end
    return str
end

function push_and_create!(data, k, vals, T = Any)
    if !haskey(data, k)
        data[k] = T[]
    end
    out = data[k]
    for v in vals
        v::T
        push!(out, v)
    end
    return data
end

function unit_type(x)
    return unit_type(Symbol(x))
end

function unit_type(x::Symbol)
    return unit_type(Val(x))
end

function unit_type(::Val{k}) where k
    if !(k in (:FIPNUM, :EQLNUM, :ACTNUM, :PVTNUM, :EOSNUM, :SATNUM, :EQLNUM, :KRW, :KRO, :KRG))
        @warn "Unit type not defined for $k."
    end
    return :id
end

function defaults_for_unit(units::Symbol, unit_ids; kwarg...)
    return defaults_for_unit(DeckUnitSystem(units), unit_ids; kwarg...)
end

function defaults_for_unit(units::NamedTuple, unit_ids; kwarg...)
    return defaults_for_unit(units.from, unit_ids; kwarg...)
end

function defaults_for_unit(usys::DeckUnitSystem{S, T}, eachunit; kwarg...) where {S, T}
    defaults = Dict{Symbol, Any}(
        :metric => missing,
        :field => missing,
        :lab => missing,
        :si => missing
    )
    n = length(eachunit)
    previous_key = missing
    for (k, v) in kwarg
        haskey(defaults, k) || throw(ArgumentError("Key $k was not present in known set of unit systems $(keys(defaults))"))
        if ismissing(k)
            continue
        end
        m = length(v)
        m == n || throw(ArgumentError("$k had length $m but units ids $eachunit had $n entries"))
        if k == S
            # Early return
            return v
        end
        defaults[k] = v
        previous_key = k
    end
    !ismissing(previous_key) || throw(ArgumentError("At least one unit system must be specified."))
    # If our requested unit system was missing we convert the last one we
    # encountered and hope that entries were consistently defined if defaults
    # were provided for multiple unit systems.
    source_usys = DeckUnitSystem(previous_key)

    upair = (to = usys, from = source_usys)
    old = defaults[previous_key]
    out = similar(old)
    for i in eachindex(out)
        out[i] = swap_unit_system(old[i], upair, eachunit[i])
    end
    return out
end

"""
    keyword_default_value(x::AbstractString, T::Type)

Get the default value of a keyword (as `String` or `::Val{X}` where `X` is a
`Symbol`) when placed in a array with element type `T`. This is used to
initialize defaulted entries when using COPY, ADD, MULTIPLY and so on.
"""
function keyword_default_value(x::AbstractString, T::Type)
    return keyword_default_value(Val(Symbol(x)), T)
end

function keyword_default_value(x::Val{X}, T::Type) where X
    X::Symbol
    return zero(T)
end
