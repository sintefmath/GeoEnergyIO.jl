function summary_identity(keyword, name, num, dims; lgr = "", local_ijk = nothing)
    isempty(keyword) && return nothing
    if !isempty(lgr) && lgr != ":+:+:+:+"
        if startswith(keyword, "LW")
            return "$lgr:$name"
        elseif startswith(keyword, "LC")
            return "$lgr:$name:$(join(local_ijk, ','))"
        elseif startswith(keyword, "LB")
            return "$lgr:$(join(local_ijk, ','))"
        end
    end
    c = first(keyword)
    if c in ('W', 'G', 'N') && name != ":+:+:+:+" && !isempty(name)
        return name
    elseif c in ('C', 'S')
        return "$name:$num"
    elseif c == 'B'
        num > 0 || return string(num)
        ijk = Tuple(CartesianIndices(dims)[num])
        return join(ijk, ',')
    elseif c in ('R', 'A') && keyword != "RUNSUM"
        return string(num)
    end
    return nothing
end

function summary_category(key)
    startswith(key, "W") && return "WELLS"
    startswith(key, "G") && return "GROUP"
    startswith(key, "R") && return "REGIONS"
    startswith(key, "B") && return "BLOCKS"
    startswith(key, "C") && return "COMPLETIONS"
    startswith(key, "S") && return "SEGMENTS"
    startswith(key, "A") && return "AQUIFERS"
    return "MISC"
end

"""
    read_summary(path; format=:legacy, extra_out=false)

Read SMSPEC with unified UNSMRY or separate Snnnn data. The default dictionary
matches the existing reader (`s["WOPR"]["PROD"]`, `s["FOPT"]`, `START_DATE`).
`format=:jutuldarcy` returns JutulDarcy's `DIMENS`, `TIME`, `VALUES` and
`UNIT_SYSTEM` representation, with FIELD, WELLS and GROUP collections.
`extra_out` returns `(summary, (spec=KeywordFile, data=Vector{KeywordFile}))`.
Summary values retain the units declared by SMSPEC. Restart-chain history is
not merged automatically; each case's own data are read.
"""
function read_summary(path::AbstractString; extra_out = false, verbose = false, format = :legacy)
    format in (:legacy, :jutuldarcy) || throw(ArgumentError("format must be :legacy or :jutuldarcy"))
    base = case_base(path)
    spec = read_binary(file_path(base, "SMSPEC"))
    h = spec["DIMENS"]
    length(h) >= 4 || throw(ArgumentError("Truncated SMSPEC DIMENS"))
    ncol = Int(h[1])
    dims = Tuple(Int.(h[2:4]))
    keys = spec["KEYWORDS"]
    names = haskey(spec, "WGNAMES") ? spec["WGNAMES"] : spec["NAMES"]
    # Older writers omit NUMS when there are only field and well variables.
    nums = haskey(spec, "NUMS") ? spec["NUMS"] : zeros(Int32, ncol)
    units = spec["UNITS"]
    all(==(ncol), length.((keys, names, nums, units))) || throw(ArgumentError("SMSPEC column arrays have inconsistent lengths"))
    starts = spec["STARTDAT"]
    length(starts) >= 3 || throw(ArgumentError("Truncated STARTDAT"))
    start = DateTime(starts[3], starts[2], starts[1], length(starts) >= 4 ? starts[4] : 0,
        length(starts) >= 5 ? starts[5] : 0) + Millisecond(length(starts) >= 6 ? div(starts[6], 1000) : 0)
    unified = file_path(base, "UNSMRY")
    files = isfile(unified) ? [unified] : split_files(base, "S")
    isempty(files) && throw(ArgumentError("No summary data found for $base"))
    raw = read_binary.(files)
    rows = Vector{Float64}[]
    for data in raw, kw in data
        kw.name == "PARAMS" || continue
        length(kw.data) == ncol || throw(ArgumentError("PARAMS length $(length(kw.data)) differs from SMSPEC count $ncol"))
        push!(rows, Float64.(kw.data))
    end
    flat = Dict{String, Any}("START_DATE" => start)
    unitmap = Dict{String, Any}()
    # Preserve column identities and units for lossless high-level re-export.
    columns = NamedTuple[]
    for i in 1:ncol
        key = keys[i]
        isempty(key) && continue
        values = [r[i] for r in rows]
        lgr = haskey(spec, "LGRS") ? spec["LGRS"][i] : ""
        local_ijk = haskey(spec, "NUMLX") ? (spec["NUMLX"][i], spec["NUMLY"][i], spec["NUMLZ"][i]) : nothing
        identity = summary_identity(key, names[i], nums[i], dims; lgr, local_ijk)
        valid = !(first(key) in ('W', 'G', 'N', 'C', 'S') && names[i] in ("", ":+:+:+:+"))
        push!(columns, (keyword = key, name = names[i], number = Int(nums[i]), unit = units[i],
            values = values, lgr = lgr, local_ijk = local_ijk, identity = identity, valid = valid))
        valid || continue
        if isnothing(identity)
            flat[key] = values
            unitmap[key] = units[i]
        else
            get!(flat, key, Dict{String, Any}())[identity] = values
            get!(unitmap, key, Dict{String, Any}())[identity] = units[i]
        end
    end
    code = haskey(spec, "INTEHEAD") ? Int(first(spec["INTEHEAD"])) : 1
    label = get(Dict(1 => "METRIC", 2 => "FIELD", 3 => "LAB", 4 => "PVT-M"), code, "UNKNOWN")
    # Metadata are included in the canonical format; legacy arrays keep the
    # established flat structure used by existing plotting scripts.
    if format == :jutuldarcy
        vals = Dict{String, Any}("FIELD" => Dict{String, Any}(), "WELLS" => Dict{String, Any}(), "GROUP" => Dict{String, Any}())
        for col in columns
            col.valid || continue
            key = col.keyword
            if startswith(key, "F")
                vals["FIELD"][key] = col.values
            elseif first(key) in ('W', 'G')
                cat = summary_category(key)
                get!(vals[cat], col.name, Dict{String, Any}())[key] = col.values
            elseif key ∉ ("TIME", "YEARS", "DAY", "MONTH", "YEAR")
                cat = summary_category(key)
                dest = get!(vals, cat, Dict{String, Any}())
                id = col.identity
                isnothing(id) ? (dest[key] = col.values) : (get!(dest, id, Dict{String, Any}())[key] = col.values)
            end
        end
        timecol = findfirst(c -> c.keyword == "TIME", columns)
        if isnothing(timecol)
            years = get(flat, "YEARS", nothing)
            isnothing(years) && throw(ArgumentError("Summary has neither TIME nor YEARS"))
            seconds = years.*31557600.0
        else
            col = columns[timecol]
            timeunit = uppercase(col.unit)
            scale = timeunit in ("HOURS", "HR") ? 3600.0 : timeunit in ("SECONDS", "SEC", "S") ? 1.0 : 86400.0
            seconds = col.values.*scale
        end
        out = Dict{String, Any}("DIMENS" => dims, "UNIT_SYSTEM" => label,
            "TIME" => (start_date = start, seconds = seconds), "VALUES" => vals,
            "UNITS" => unitmap, "COLUMNS" => columns)
    else
        out = flat
    end
    verbose && println("Read $ncol summary columns at $(length(rows)) timesteps")
    return extra_out ? (out, (spec = spec, data = raw)) : out
end
