function standard_headers(dims, nactive; units = :metric, phases = 7, elapsed = 0.0,
        start_date = DateTime(1970), report_step = 0)
    h = zeros(Int32, 411)
    h[2:3] = [202600, unit_code(units)]
    h[9:12] = [dims..., nactive]
    h[15] = phases
    h[95] = 100 # Conventional simulator-family identifier for reservoir arrays.
    h[69] = report_step
    date = DateTime(start_date) + Millisecond(round(Int, elapsed*1000))
    h[65:67] = [day(date), month(date), year(date)]
    h[207:208] = [hour(date), minute(date)]
    h[411] = second(date)*1000000 + millisecond(date)*1000
    d = zeros(229)
    # Restart elapsed time is always in days, including laboratory files.
    d[1] = elapsed/86400.0
    return [BinaryKeyword("INTEHEAD", h), BinaryKeyword("LOGIHEAD", falses(121)),
        BinaryKeyword("DOUBHEAD", d)]
end

"Write INIT keyword arrays as an industry standard format file."
write_init(data::Union{AbstractDict, KeywordFile}, path::AbstractString; kw...) =
    write_binary(output_path(path, "INIT"), data; kw...)
write_init(path::AbstractString, data; kw...) = write_init(data, path; kw...)

function restart_block(header, solution; report_step)
    records = BinaryKeyword[BinaryKeyword("SEQNUM", Int32[report_step])]
    append!(records, header)
    push!(records, BinaryKeyword("STARTSOL", UInt8[]; type = "MESS"))
    append!(records, solution)
    push!(records, BinaryKeyword("ENDSOL", UInt8[]; type = "MESS"))
    return KeywordFile(records)
end

restart_block(step::KeywordFile, ix) = step
function restart_block(step::AbstractDict, ix)
    header_names = ("INTEHEAD", "LOGIHEAD", "DOUBHEAD")
    for name in ("INTEHEAD", "DOUBHEAD")
        haskey(step, name) || throw(ArgumentError("Restart dictionaries must include $name"))
    end
    header = (BinaryKeyword(name, step[name]) for name in header_names if haskey(step, name))
    reserved = (header_names..., "SEQNUM", "report_step", "date", "days", "STARTSOL", "ENDSOL")
    names = sort!([key for key in keys(step) if key ∉ reserved])
    solution = (BinaryKeyword(name, step[name]) for name in names)
    return restart_block(header, solution; report_step = get(step, "report_step", ix))
end

"""
    write_restart(steps, path; unified=true)

Write restart dictionaries (as returned by `read_restart`) or raw ordered
`KeywordFile` blocks. Separate files are named `.Xnnnn` using `report_step`.
These files contain reservoir solution arrays; they do not serialize a
simulator's complete well/control restart state.
"""
function write_restart(steps::AbstractVector, path::AbstractString; unified = true, endian = :big)
    base = case_base(path)
    if unified
        pth = output_path(base, "UNRST")
        open(pth, "w") do io
            for (ix, step) in enumerate(steps)
                write_binary(io, restart_block(step, ix); endian)
            end
        end
        return abspath(pth)
    end
    paths = String[]
    for (ix, step) in enumerate(steps)
        kws = restart_block(step, ix)
        seq = findfirst(k -> k.name == "SEQNUM", kws)
        report = isnothing(seq) ? ix : Int(only(kws[seq].data))
        pth = output_path(base, "X$(lpad(report, 4, '0'))")
        push!(paths, write_binary(pth, [kw for kw in kws if kw.name != "SEQNUM"]; endian))
    end
    return paths
end
write_restart(path::AbstractString, steps::AbstractVector; kw...) = write_restart(steps, path; kw...)
