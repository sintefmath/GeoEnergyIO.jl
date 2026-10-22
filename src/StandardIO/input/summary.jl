function summary_identity(keyword, name, num, dims; lgr = "", local_ijk = nothing)
    if isempty(keyword)
        return nothing
    end
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
        if num <= 0
            return string(num)
        end
        ijk = Tuple(CartesianIndices(dims)[num])
        return join(ijk, ',')
    elseif c in ('R', 'A') && keyword != "RUNSUM"
        return string(num)
    end
    return nothing
end

"""
    read_summary(path; format=:legacy, extra_out=false)

Read SMSPEC with unified UNSMRY or separate Snnnn data. The default dictionary
contains arrays by keyword and identity (`s["WOPR"]["PROD"]`, `s["FOPT"]`).
`START_DATE` contains the start date.
`format=:structured` returns `DIMENS`, `TIME`, `VALUES` and `UNIT_SYSTEM`,
with FIELD, WELLS, GROUP and other collections. TIME contains a start date
and elapsed seconds; value arrays retain their declared units.
`extra_out` returns `(summary, (spec=KeywordFile, data=Vector{KeywordFile}))`.
Summary values retain the units declared by SMSPEC. Restart-chain history is
not merged automatically; each case's own data are read.
"""
function read_summary(path::AbstractString; extra_out = false, verbose = false, format = :legacy)
    format in (:legacy, :structured) || throw(ArgumentError("format must be :legacy or :structured"))
    base = case_base(path)
    spec = read_binary(file_path(base, "SMSPEC"))
    h = spec["DIMENS"]
    length(h) >= 4 || throw(ArgumentError("Truncated SMSPEC DIMENS"))
    ncol = Int(h[1])
    dims = Tuple(Int.(h[2:4]))
    keys = spec["KEYWORDS"]
    if haskey(spec, "WGNAMES")
        names = spec["WGNAMES"]
    else
        names = spec["NAMES"]
    end
    nums = get(spec, "NUMS", zeros(Int32, ncol))
    units = spec["UNITS"]
    all(==(ncol), length.((keys, names, nums, units))) || throw(ArgumentError("SMSPEC column arrays have inconsistent lengths"))
    starts = spec["STARTDAT"]
    length(starts) >= 3 || throw(ArgumentError("Truncated STARTDAT"))
    start = DateTime(starts[3], starts[2], starts[1], get(starts, 4, 0),
        get(starts, 5, 0)) + Millisecond(div(get(starts, 6, 0), 1000))
    unified = file_path(base, "UNSMRY")
    if isfile(unified)
        files = [unified]
    else
        files = split_files(base, "S")
    end
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
    # Preserve column identities and units for high-level re-export.
    columns = NamedTuple[]
    for i in 1:ncol
        key = keys[i]
        isempty(key) && continue
        values = [r[i] for r in rows]
        if haskey(spec, "LGRS")
            lgr = spec["LGRS"][i]
        else
            lgr = ""
        end
        if haskey(spec, "NUMLX")
            local_ijk = (spec["NUMLX"][i], spec["NUMLY"][i], spec["NUMLZ"][i])
        else
            local_ijk = nothing
        end
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
    code = Int(first(get(spec, "INTEHEAD", [1])))
    label = get(Dict(1 => "METRIC", 2 => "FIELD", 3 => "LAB", 4 => "PVT-M"), code, "UNKNOWN")
    if format == :structured
        vals = Dict{String, Any}("FIELD" => Dict{String, Any}(), "WELLS" => Dict{String, Any}(), "GROUP" => Dict{String, Any}())
        for col in columns
            group = summary_group(col)
            isnothing(group) && continue
            category, identity = group
            dest = get!(vals, category, Dict{String, Any}())
            isnothing(identity) || (dest = get!(dest, identity, Dict{String, Any}()))
            dest[col.keyword] = col.values
        end
        timecol = findfirst(c -> c.keyword == "TIME", columns)
        if isnothing(timecol)
            years = get(flat, "YEARS", nothing)
            isnothing(years) && throw(ArgumentError("Summary has neither TIME nor YEARS"))
            seconds = years.*31557600.0
        else
            col = columns[timecol]
            timeunit = uppercase(col.unit)
            scale = ifelse(timeunit in ("HOURS", "HR"), 3600.0,
                ifelse(timeunit in ("SECONDS", "SEC", "S"), 1.0, 86400.0))
            seconds = col.values.*scale
        end
        out = Dict{String, Any}("DIMENS" => dims, "UNIT_SYSTEM" => label,
            "TIME" => (start_date = start, seconds = seconds), "VALUES" => vals,
            "UNITS" => unitmap, "COLUMNS" => columns)
    else
        out = flat
    end
    verbose && println("Read $ncol summary columns at $(length(rows)) timesteps")
    return ifelse(extra_out, (out, (spec = spec, data = raw)), out)
end
