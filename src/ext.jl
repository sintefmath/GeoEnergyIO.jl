function check_pythoncall(; throw = true)
    present = !isnothing(Base.get_extension(GeoEnergyIO, :GeoEnergyIOPythonCallExt))
    throw && !present && error("The Python backend requires loading PythonCall and resdata. Use backend=:julia for the built-in reader.")
    return present
end

function call_io_backend(julia_impl, python_impl, args...; backend = :julia, kw...)
    backend in (:julia, :python) || throw(ArgumentError("backend must be :julia or :python"))
    backend == :python && check_pythoncall()
    impl = ifelse(backend == :julia, julia_impl, python_impl)
    return impl(args...; kw...)
end

"""
    read_restart(path; backend=:julia, kw...)

Read restart files. See [`StandardIO.input.read_restart`](@ref) for options.
"""
read_restart(args...; kw...) = call_io_backend(StandardIO.read_restart, read_restart_impl, args...; kw...)

"""
    read_init(path; backend=:julia, kw...)

Read INIT arrays. See [`StandardIO.input.read_init`](@ref) for options.
"""
read_init(args...; kw...) = call_io_backend(StandardIO.read_init, read_init_impl, args...; kw...)

"""
    read_egrid(path; backend=:julia, kw...)

Read grid geometry. See [`StandardIO.input.read_egrid`](@ref) for options.
"""
read_egrid(args...; kw...) = call_io_backend(StandardIO.read_egrid, read_egrid_impl, args...; kw...)

"""
    write_egrid(data, path; backend=:julia, kw...)

Write grid geometry. See [`StandardIO.output.write_egrid`](@ref) for options.
"""
write_egrid(args...; kw...) = call_io_backend(StandardIO.write_egrid, write_egrid_impl, args...; kw...)

"""
    read_summary(path; backend=:julia, kw...)

Read summary files. See [`StandardIO.input.read_summary`](@ref) for options.
"""
read_summary(args...; kw...) = call_io_backend(StandardIO.read_summary, read_summary_impl, args...; kw...)

"""
    write_jutuldarcy_summary(path, summary; backend=:julia, kw...)

Write summary files and return `(directory, basename, data_extension)`.
"""
function write_jutuldarcy_summary(path::AbstractString, summary::AbstractDict; backend = :julia, kw...)
    return call_io_backend(write_summary_paths, write_jutuldarcy_summary_impl, path, summary; backend, kw...)
end

function write_summary_paths(path, summary; kw...)
    written = StandardIO.write_summary(summary, path; kw...)
    dir, name = splitdir(abspath(StandardIO.case_base(path)))
    return (dir, name, splitext(first(written.data))[2])
end

# Python backend methods are defined by GeoEnergyIOPythonCallExt.
function read_restart_impl end
function read_init_impl end
function read_egrid_impl end
function read_summary_impl end
function write_egrid_impl end
function write_jutuldarcy_summary_impl end
