function active_mask(actnum)
    if ismissing(actnum) || isnothing(actnum)
        return nothing
    end
    return vec(actnum) .!= 0
end

const NON_CELL_ARRAYS = Set([
    "INTEHEAD", "LOGIHEAD", "DOUBHEAD", "SEQNUM", "STARTSOL", "ENDSOL",
    "IWEL", "SWEL", "XWEL", "ZWEL", "ICON", "SCON", "XCON", "ISEG", "RSEG",
    "ILBS", "ILBR", "IGRP", "SGRP", "XGRP", "ZGRP", "IGRPH", "RGRP", "ZTRACER",
    "TAB", "TABDIMS", "NNCHEAD", "TRANNNC"
])

function array_dictionary(raw; actnum = missing, units = :native)
    units in (:native, :si) || throw(ArgumentError("units must be :native or :si"))
    mask = active_mask(actnum)
    out = Dict{String, Any}()
    for kw in raw
        haskey(out, kw.name) && continue
        v = kw.data
        if !(kw.name in NON_CELL_ARRAYS) && !isnothing(mask) && length(v) == length(mask)
            v = v[mask]
        end
        if eltype(v) <: AbstractFloat
            v = Float64.(v)
        elseif eltype(v) <: Signed
            v = Int64.(v)
        else
            v = copy(v)
        end
        if units == :si && eltype(v) <: AbstractFloat
            v = convert_array(kw.name, v, file_units(raw); to_si = true)
        end
        out[kw.name] = v
    end
    return out
end

"""
    read_init(path; actnum=missing, units=:native, extra_out=false)

Read INIT arrays into a dictionary. ACTNUM masks reduce full-grid cell arrays.
`units=:si` converts known physical quantities to SI. `extra_out=true` also
returns the ordered `KeywordFile`.
"""
function read_init(path::AbstractString; extra_out = false, actnum = missing, units = :native, verbose = false)
    raw = read_binary(file_path(path, "INIT"))
    out = array_dictionary(raw; actnum, units)
    verbose && println("Read $(length(raw)) INIT keywords")
    return ifelse(extra_out, (out, raw), out)
end

function restart_date(h)
    if length(h) < 67
        return missing
    end
    try
        hour = get(h, 207, 0)
        minute = get(h, 208, 0)
        micro = get(h, 411, 0)
        return DateTime(h[67], h[66], h[65], hour, minute) + Millisecond(div(micro, 1000))
    catch e
        e isa ArgumentError || rethrow()
        return missing
    end
end

function restart_blocks(raw)
    blocks = KeywordFile[]
    current = BinaryKeyword[]
    for kw in raw
        if kw.name == "SEQNUM" && !isempty(current)
            push!(blocks, KeywordFile(current; endian = raw.endian))
            current = BinaryKeyword[]
        end
        push!(current, kw)
    end
    !isempty(current) && push!(blocks, KeywordFile(current; endian = raw.endian))
    return blocks
end

"""
    read_restart(path; steps=missing, actnum=missing, egrid=missing,
                 units=:native, extra_out=false)

Read unified UNRST or separate Xnnnn restart files as a vector of dictionaries,
with `report_step`, `days`, and `date` metadata. `steps` selects report positions.
Gaps in separate file numbering are supported.
An EGRID is optional; pass `actnum` to reduce full-grid cell arrays explicitly.
"""
function read_restart(path::AbstractString; extra_out = false, actnum = missing,
        egrid = missing, verbose = false, steps = missing, units = :native)
    base = case_base(path)
    ext = uppercase(splitext(path)[2])
    if occursin(r"^\.X[0-9]+$", ext)
        files = [String(path)]
    elseif isfile(file_path(base, "UNRST"))
        files = [file_path(base, "UNRST")]
    else
        files = split_files(base, "X")
    end
    isempty(files) && throw(ArgumentError("No restart files found for $path"))
    if ismissing(actnum) && egrid isa AbstractDict
        actnum = egrid["ACTNUM"]
    elseif ismissing(actnum) && egrid isa AbstractString
        actnum = read_egrid(egrid)["ACTNUM"]
    end
    out = Dict{String, Any}[]
    rawout = KeywordFile[]
    pos = 0
    for file in files
        raw = read_binary(file)
        for block in restart_blocks(raw)
            pos += 1
            (ismissing(steps) || pos in steps) || continue
            step = array_dictionary(block; actnum, units)
            if haskey(block, "SEQNUM")
                step["report_step"] = Int(only(block["SEQNUM"]))
            else
                step["report_step"] = parse(Int, splitext(file)[2][3:end])
            end
            if haskey(block, "DOUBHEAD")
                elapsed = first(block["DOUBHEAD"])
                step["days"] = elapsed
            else
                step["days"] = missing
            end
            if haskey(block, "INTEHEAD")
                date = restart_date(block["INTEHEAD"])
            else
                date = missing
            end
            step["date"] = ifelse(ismissing(date), missing, string(date))
            push!(out, step)
            extra_out && push!(rawout, block)
            verbose && println("Read restart report $(step["report_step"])")
        end
    end
    return ifelse(extra_out, (out, rawout), out)
end
