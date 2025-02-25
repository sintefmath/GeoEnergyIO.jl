function check_pythoncall(; throw = true)
    present = !isnothing(Base.get_extension(GeoEnergyIO, :GeoEnergyIOPythonCallExt))
    if throw
        if !present
            error("PythonCall is not loaded. This is needed for reading of output files via resdata.\nTo fix:\nusing Pkg; Pkg.add(\"PythonCall\"); using PythonCall")
        end
    end
    return present
end

"""
    restart = read_restart(fn)
    restart, raw_restart = read_restart(fn, extra_out = true)

Read a restart file from `fn`. This should be the base path (i.e. without the
`.RSRT` extension). The results are given as a Vector of Dicts.

# Keyword arguments

- `extra_out`: If true, return the raw Python object as well as the parsed
  data. Default is false.
- `actnum=missing`: ACTNUM array that can be used to reduce the outputs to the
  active cells.
- `egrid=missing`: EGRID object needed to read the restarts. Will be read from
  the same path as `fn` if not provided.

# Notes

This function requires the `resdata` Python package to be installed, which will
be automatically added to your environment if you first install PythonCall and
put `using PythonCall` in your script or REPL.

The main class to lookup on the Python side of things is `ResdataRestartFile`.
"""
function read_restart(arg...; kwarg...)
    check_pythoncall()
    return read_restart_impl(arg...; kwarg...)
end

function read_restart_impl

end

"""
    init = read_init(fn)
    init, raw_init = read_init(fn, extra_out = true)

Read a init file from `fn`. This should be the base path (i.e. without the
`.RSRT` extension). The results are given as a Dict.

# Keyword arguments

- `extra_out`: If true, return the raw Python object as well as the parsed
  data. Default is false.
- `actnum=missing`: ACTNUM array that can be used to reduce the outputs to the
  active cells.

# Notes

This function requires the `resdata` Python package to be installed, which will
be automatically added to your environment if you first install PythonCall and
put `using PythonCall` in your script or REPL.

The main class to lookup on the Python side of things is `ResdataFile`.
"""
function read_init(arg...; kwarg...)
    check_pythoncall()
    return read_init_impl(arg...; kwarg...)
end

function read_init_impl

end

"""
    egrid = read_egrid(pth)
    egrid, raw_egrid = read_egrid(pth, extra_out = true)

Read the EGRID file from `pth`. The results are given as a Dict and can be
passed further on to `mesh_from_grid_section` to construct a Jutul mesh.

# Notes

This function requires the `resdata` Python package to be installed, which will
be automatically added to your environment if you first install PythonCall and
put `using PythonCall` in your script or REPL.

Uses primarily `resdata.grid.Grid`.
"""
function read_egrid(arg...; kwarg...)
    check_pythoncall()
    return read_egrid_impl(arg...; kwarg...)
end

function read_egrid_impl

end

"""
    summary = read_summary(pth)
    summary, raw_summary = read_summary(pth, extra_out = true)

Read the SUMMARY file from `pth`. The results are given as a Dict.

# Notes

This function requires the `resdata` Python package to be installed, which will
be automatically added to your environment if you first install PythonCall and
put `using PythonCall` in your script or REPL.

Uses primarily `resdata.summary.Summary`.
"""
function read_summary(arg...; kwarg...)
    check_pythoncall()
    return read_summary_impl(arg...; kwarg...)
end

function read_summary_impl

end

"""
    write_jutuldarcy_summary(filename, smry_jutul; unified = true)

Experimental function to write a summary file from JutulDarcy results.
"""
function write_jutuldarcy_summary(filename, smry_jutul; unified = true)
    check_pythoncall()
    return write_jutuldarcy_summary_impl(filename, smry_jutul, unified = unified)
end

function write_jutuldarcy_summary_impl

end
