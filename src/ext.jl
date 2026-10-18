# Public compatibility entry points. The pure Julia implementation is the
# default; the optional Python backend remains available for comparison.
function check_pythoncall(; throw = true)
    present = !isnothing(Base.get_extension(GeoEnergyIO, :GeoEnergyIOPythonCallExt))
    throw && !present && error("The Python backend requires loading PythonCall and resdata. Use backend=:julia for the built-in reader.")
    return present
end

function io_backend(backend)
    backend in (:julia, :python) || throw(ArgumentError("backend must be :julia or :python"))
    backend == :python && check_pythoncall()
    return backend
end

"""
    read_restart(path; backend=:julia, kw...)

Read industry standard format restart files using the built-in Julia reader.
See [`StandardIO.input.read_restart`](@ref) for options and return values.
"""
function read_restart(args...; backend = :julia, kw...)
    io_backend(backend)
    return backend == :julia ? StandardIO.read_restart(args...; kw...) : read_restart_impl(args...; kw...)
end

"""
    read_init(path; backend=:julia, kw...)

Read industry standard format INIT arrays. See [`StandardIO.input.read_init`](@ref).
"""
function read_init(args...; backend = :julia, kw...)
    io_backend(backend)
    return backend == :julia ? StandardIO.read_init(args...; kw...) : read_init_impl(args...; kw...)
end

"""
    read_egrid(path; backend=:julia, kw...)

Read an industry standard format grid into a deck GRID dictionary.
See [`StandardIO.input.read_egrid`](@ref). The Julia reader returns SI geometry.
"""
function read_egrid(args...; backend = :julia, kw...)
    io_backend(backend)
    return backend == :julia ? StandardIO.read_egrid(args...; kw...) : read_egrid_impl(args...; kw...)
end

"""
    read_summary(path; backend=:julia, format=:legacy, kw...)

Read industry standard format summary files. Use `format=:jutuldarcy` for the
dictionary format used by JutulDarcy's `summary_result`.
See [`StandardIO.input.read_summary`](@ref).
"""
function read_summary(args...; backend = :julia, kw...)
    io_backend(backend)
    return backend == :julia ? StandardIO.read_summary(args...; kw...) : read_summary_impl(args...; kw...)
end

"Write a JutulDarcy summary dictionary as industry standard format files, using Julia by default."
function write_jutuldarcy_summary(args...; backend = :julia, kw...)
    io_backend(backend)
    return backend == :julia ? StandardIO.write_jutuldarcy_summary(args...; kw...) : write_jutuldarcy_summary_impl(args...; kw...)
end

# These hooks are implemented by the legacy Python extension only.
function read_restart_impl end
function read_init_impl end
function read_egrid_impl end
function read_summary_impl end
function write_egrid_impl end
function write_jutuldarcy_summary_impl end

"Read restart solution arrays as JutulDarcy state dictionaries using a case's phase ordering (requires JutulDarcy)."
function read_jutuldarcy_states end
