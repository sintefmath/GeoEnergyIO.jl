function summary_quantity(key)
    suffix = length(key) > 1 ? key[2:end] : ""
    suffix in ("PR", "PRH", "PRP", "BHP", "THP") && return (:pressure, false)
    if occursin(r"^[OWGL][PI][RT]$", suffix)
        return (first(suffix) == 'G' ? :gas_volume_surface : :liquid_volume_surface, last(suffix) == 'R')
    elseif suffix in ("WIP", "OIP", "GIP")
        return (first(suffix) == 'G' ? :gas_volume_surface : :liquid_volume_surface, false)
    elseif suffix in ("WIPR", "OIPR", "GIPR")
        return (first(suffix) == 'G' ? :gas_volume_reservoir : :liquid_volume_reservoir, false)
    elseif suffix in ("GOR", "GLR")
        return (:u_rs, false)
    elseif suffix == "WGR"
        return (:u_rv, false)
    elseif suffix == "WCT" || key == "NONE"
        return (:id, false)
    end
    return (nothing, false)
end

function summary_factor(key, units)
    kind, rate = summary_quantity(key)
    isnothing(kind) && throw(ArgumentError("Cannot convert summary variable $key between unit systems; provide values in the declared output units"))
    kind == :id && return 1.0
    system = unit_system(units)
    return getproperty(system, kind)/(rate ? system.time : 1.0)
end

function summary_unit(key, units)
    field = Symbol(lowercase(string(units))) == :field
    lab = Symbol(lowercase(string(units))) == :lab
    time = lab ? "HR" : "DAY"
    liquid = field ? "STB" : lab ? "SCC" : "SM3"
    gas = field ? "MSCF" : lab ? "SCC" : "SM3"
    if key == "TIME"
        return lab ? "HOURS" : "DAYS"
    elseif key == "YEARS"
        return "YEARS"
    end
    kind, rate = summary_quantity(key)
    if kind == :pressure
        return field ? "PSIA" : lab ? "ATMA" : "BARSA"
    elseif kind in (:gas_volume_surface, :liquid_volume_surface)
        label = kind == :gas_volume_surface ? gas : liquid
        return rate ? "$label/$time" : label
    elseif kind in (:gas_volume_reservoir, :liquid_volume_reservoir)
        return field ? "RB" : lab ? "RCC" : "RM3"
    elseif kind == :u_rs
        return "$gas/$liquid"
    elseif kind == :u_rv
        return "$liquid/$gas"
    end
    return ""
end

function summary_columns(summary, units)
    # Readers preserve all column metadata, including uncommon summary types.
    vals = summary["VALUES"]
    if haskey(summary, "COLUMNS")
        return map(summary["COLUMNS"]) do col
            group = summary_group(col)
            isnothing(group) && return col
            category, identity = group
            dest = vals[category]
            isnothing(identity) || (dest = dest[identity])
            return merge(col, (values = dest[col.keyword],))
        end
    end
    cols = NamedTuple[]
    function add(key, values, name = ":+:+:+:+"; number = 0)
        key = uppercase(string(key))
        unit = summary_unit(key, units)
        umap = get(summary, "UNITS", Dict())
        if haskey(umap, key)
            u = umap[key]
            unit = u isa AbstractDict ? get(u, string(name), unit) : u
        end
        push!(cols, (keyword = key, name = string(name), number = number, unit = unit, values = values))
    end
    for key in sort!(collect(keys(get(vals, "FIELD", Dict()))))
        add(key, vals["FIELD"][key])
    end
    for cat in ("WELLS", "GROUP", "GROUPS")
        for name in sort!(collect(keys(get(vals, cat, Dict()))))
            for key in sort!(collect(keys(vals[cat][name])))
                add(key, vals[cat][name][key], name)
            end
        end
    end
    return cols
end

"""
    write_summary(summary, path; unified=true)

Write SMSPEC and UNSMRY (or separate Snnnn files) from a structured summary
dictionary, as returned by `read_summary(...; format=:structured)`. Required
entries are DIMENS, UNIT_SYSTEM, TIME (start_date and seconds), and VALUES
(FIELD, WELLS and GROUP collections). SI values are converted to metric by
default. Set `units` to choose another system for recognized quantities.
When COLUMNS metadata is present, values are taken from the VALUES dictionary
while preserving column order and identities.
Long well names use the Cnnn string format. Input arrays are not mutated.
"""
function write_summary(summary::AbstractDict, path::AbstractString; unified = true, endian = :big, units = nothing)
    base = case_base(path)
    dims = Tuple(Int.(summary["DIMENS"]))
    length(dims) == 3 && all(>(0), dims) || throw(ArgumentError("DIMENS must contain three positive dimensions"))
    source_units = Symbol(lowercase(string(get(summary, "UNIT_SYSTEM", "METRIC"))))
    units = isnothing(units) ? (source_units == :si ? :metric : source_units) : Symbol(lowercase(string(units)))
    code = unit_code(units)
    t = summary["TIME"].seconds
    isempty(t) && throw(ArgumentError("Summary must contain at least one timestep"))
    all(isfinite, t) && all(>=(0), t) && issorted(t) || throw(ArgumentError("Summary times must be finite, nonnegative and sorted"))
    start = summary["TIME"].start_date
    (ismissing(start) || isnothing(start)) && (start = DateTime(1970))
    start = DateTime(start)
    cols = summary_columns(summary, units)
    cols = NamedTuple[if col.keyword == "TIME"
            merge(col, (unit = summary_unit("TIME", units), values = t./unit_system(units).time))
        elseif col.keyword == "YEARS"
            merge(col, (unit = "YEARS", values = t./31557600.0))
        elseif source_units != units
            factor = summary_factor(col.keyword, source_units)/summary_factor(col.keyword, units)
            merge(col, (unit = summary_unit(col.keyword, units), values = col.values.*factor))
        else
            col
        end for col in cols]
    if !any(c -> c.keyword == "TIME", cols)
        pushfirst!(cols, (keyword = "TIME", name = ":+:+:+:+", number = 0, unit = summary_unit("TIME", units), values = t./unit_system(units).time))
    end
    if !any(c -> c.keyword == "YEARS", cols)
        push!(cols, (keyword = "YEARS", name = ":+:+:+:+", number = 0, unit = "YEARS", values = t./31557600.0))
    end
    all(c -> length(c.values) == length(t), cols) || throw(ArgumentError("All summary vectors must match TIME.seconds"))
    ncol = length(cols)
    spec = BinaryKeyword[
        BinaryKeyword("INTEHEAD", Int32[code, 100]),
        BinaryKeyword("RESTART", fill("", 9)),
        BinaryKeyword("DIMENS", Int32[ncol, dims..., 0, 0]),
        BinaryKeyword("KEYWORDS", [c.keyword for c in cols]),
        BinaryKeyword("WGNAMES", [c.name for c in cols]),
        BinaryKeyword("NUMS", Int32[c.number for c in cols]),
        BinaryKeyword("UNITS", [c.unit for c in cols]),
        BinaryKeyword("STARTDAT", Int32[day(start), month(start), year(start), hour(start), minute(start), second(start)*1000000 + millisecond(start)*1000])
    ]
    if any(c -> hasproperty(c, :lgr) && !isempty(c.lgr), cols)
        push!(spec, BinaryKeyword("LGRS", [hasproperty(c, :lgr) ? c.lgr : "" for c in cols]))
        for (axis, key) in enumerate(("NUMLX", "NUMLY", "NUMLZ"))
            push!(spec, BinaryKeyword(key, Int32[hasproperty(c, :local_ijk) && !isnothing(c.local_ijk) ? c.local_ijk[axis] : 0 for c in cols]))
        end
    end
    specpath = write_binary(output_path(base, "SMSPEC"), spec; endian)
    function write_step(io, i)
        write_keyword(io, BinaryKeyword("SEQHDR", Int32[0]), endian)
        write_keyword(io, BinaryKeyword("MINISTEP", Int32[i-1]), endian)
        write_keyword(io, BinaryKeyword("PARAMS", Float32[c.values[i] for c in cols]), endian)
    end
    if unified
        pth = output_path(base, "UNSMRY")
        open(pth, "w") do io
            for i in eachindex(t)
                write_step(io, i)
            end
        end
        return (spec = specpath, data = [abspath(pth)])
    else
        paths = String[]
        for i in eachindex(t)
            pth = output_path(base, "S$(lpad(i, 4, '0'))")
            open(io -> write_step(io, i), pth, "w")
            push!(paths, abspath(pth))
        end
        return (spec = specpath, data = paths)
    end
end
write_summary(path::AbstractString, summary::AbstractDict; kw...) = write_summary(summary, path; kw...)
