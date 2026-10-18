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

"Write INIT keyword arrays, or derive static reservoir properties from a Jutul case."
write_init(data::Union{AbstractDict, KeywordFile}, path::AbstractString; kw...) =
    write_binary(output_path(path, "INIT"), data; kw...)
write_init(path::AbstractString, data; kw...) = write_init(data, path; kw...)

function reservoir_part(x)
    return haskey(x, :Reservoir) ? x[:Reservoir] : x
end

phase_mask(system) = 7

function write_init(case::Jutul.JutulCase, path::AbstractString; units = :metric, endian = :big,
        phases = phase_mask(reservoir_model(case).system))
    model = reservoir_model(case)
    domain = model.data_domain
    grid = case_grid(case)
    dims = grid_dims(grid)
    active = findall(!iszero, vec(grid["ACTNUM"]))
    nc = length(active)
    kws = standard_headers(dims, nc; units, phases, start_date = case_start_date(case))
    function add(name, vals; full = false)
        vals = vals isa Number ? fill(vals, nc) : vec(vals)
        length(vals) == nc || throw(ArgumentError("$name must have $nc cell values"))
        converted = convert_array(name, vals, Symbol(lowercase(string(units))); to_si = false)
        if full
            a = zeros(prod(dims))
            a[active] = converted
            converted = a
        end
        push!(kws, BinaryKeyword(name, Float32.(converted)))
    end
    poro = domain[:porosity]
    vols = domain[:volumes]
    ntg = haskey(domain, :net_to_gross) ? domain[:net_to_gross] : ones(nc)
    add("PORO", poro)
    add("NTG", ntg)
    params = reservoir_part(case.parameters)
    pv = get(params, :StaticFluidVolume, get(params, :FluidVolume, vols.*poro.*ntg))
    add("PORV", pv; full = true)
    centroids = domain[:cell_centroids]
    add("DEPTH", centroids[end, :])
    perm = domain[:permeability]
    if perm isa AbstractMatrix
        nr = size(perm, 1)
        rows = nr == 6 ? (1, 4, 6) : nr == 3 && Jutul.dim(Jutul.physical_representation(domain)) == 2 ? (1, 3, 3) : ntuple(i -> min(i, nr), 3)
        for (name, row) in zip(("PERMX", "PERMY", "PERMZ"), rows)
            add(name, perm[row, :])
        end
    else
        for name in ("PERMX", "PERMY", "PERMZ")
            add(name, perm)
        end
    end
    # Region arrays are already stored as integer cell arrays on the domain.
    for (name, key) in (("SATNUM", :satnum), ("PVTNUM", :pvtnum), ("EQLNUM", :eqlnum), ("FIPNUM", :fipnum))
        haskey(domain, key) && push!(kws, BinaryKeyword(name, Int32.(domain[key])))
    end
    return write_binary(output_path(path, "INIT"), kws; endian)
end

"""
    write_restart(steps, path; unified=true)

Write restart dictionaries (as returned by `read_restart`) or raw ordered
`KeywordFile` blocks. Separate files are named `.Xnnnn` using `report_step`.
JutulDarcy state dictionaries can be exported with `write_restart(case, result,
path)` when JutulDarcy is loaded. These files contain reservoir solution arrays;
they do not serialize a simulator's complete well/control restart state.
"""
function write_restart(steps::AbstractVector, path::AbstractString; unified = true, endian = :big)
    base = case_base(path)
    function records(step, ix)
        step isa KeywordFile && return step
        kws = BinaryKeyword[]
        report = get(step, "report_step", ix)
        push!(kws, BinaryKeyword("SEQNUM", Int32[report]))
        for key in ("INTEHEAD", "LOGIHEAD", "DOUBHEAD")
            haskey(step, key) && push!(kws, BinaryKeyword(key, step[key]))
        end
        haskey(step, "INTEHEAD") || throw(ArgumentError("Restart dictionaries must include INTEHEAD"))
        haskey(step, "DOUBHEAD") || throw(ArgumentError("Restart dictionaries must include DOUBHEAD"))
        reserved = Set(["SEQNUM", "INTEHEAD", "LOGIHEAD", "DOUBHEAD", "report_step", "date", "days", "STARTSOL", "ENDSOL"])
        push!(kws, BinaryKeyword("STARTSOL", UInt8[]; type = "MESS"))
        for key in sort!(collect(setdiff(keys(step), reserved)))
            push!(kws, BinaryKeyword(key, step[key]))
        end
        push!(kws, BinaryKeyword("ENDSOL", UInt8[]; type = "MESS"))
        return kws
    end
    if unified
        pth = output_path(base, "UNRST")
        open(pth, "w") do io
            for (ix, step) in enumerate(steps)
                write_binary(io, records(step, ix); endian)
            end
        end
        return abspath(pth)
    end
    paths = String[]
    for (ix, step) in enumerate(steps)
        kws = records(step, ix)
        seq = findfirst(k -> k.name == "SEQNUM", kws)
        report = isnothing(seq) ? ix : Int(only(kws[seq].data))
        pth = output_path(base, "X$(lpad(report, 4, '0'))")
        push!(paths, write_binary(pth, [kw for kw in kws if kw.name != "SEQNUM"]; endian))
    end
    return paths
end
write_restart(path::AbstractString, steps::AbstractVector; kw...) = write_restart(steps, path; kw...)

function state_keywords(state, phase_names; units = :metric)
    state = reservoir_part(state)
    kws = BinaryKeyword[]
    for (key, name) in ((:Pressure, "PRESSURE"), (:Temperature, "TEMP"), (:Rs, "RS"), (:Rv, "RV"))
        if haskey(state, key)
            vals = convert_array(name, vec(state[key]), Symbol(lowercase(string(units))); to_si = false)
            push!(kws, BinaryKeyword(name, Float32.(vals)))
        end
    end
    if haskey(state, :Saturations)
        sat = state[:Saturations]
        size(sat, 1) == length(phase_names) || throw(ArgumentError("Saturation rows do not match model phases"))
        for (ix, phase) in enumerate(phase_names)
            name = Dict(:water => "SWAT", :oil => "SOIL", :gas => "SGAS")[phase]
            push!(kws, BinaryKeyword(name, Float32.(sat[ix, :])))
        end
    end
    if haskey(state, :OverallMoleFractions)
        z = state[:OverallMoleFractions]
        for i in axes(z, 1)
            push!(kws, BinaryKeyword("ZMF$i", Float32.(z[i, :])))
        end
    end
    return kws
end
