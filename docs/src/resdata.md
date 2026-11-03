# resdata backend

## Input and output using resdata

The Python package [resdata](https://github.com/equinor/resdata) developed by
Equinor provides a backend for summary, EGRID, INIT and restart files.

!!! note "resdata is GPL-3.0 licensed"
    The resdata package is under a different license than GeoEnergyIO which uses MIT. The licenses are compatible, but a distributed product that contains resdata must comply with the terms of the GPL license.

Install `PythonCall` in your environment:

```julia
using Pkg
Pkg.add("PythonCall")
```

Load the extension and select `backend=:python`:

```julia
using GeoEnergyIO, PythonCall
```

### Reading output

```julia
grid = read_egrid("CASE"; backend = :python)
init = read_init("CASE"; backend = :python)
steps = read_restart("CASE"; backend = :python)
summary = read_summary("CASE"; backend = :python)
```

Values use file units. `extra_out=true` also returns the resdata objects.
INIT and restart readers accept an `actnum` mask. The restart reader also
accepts `steps` and an `egrid` object.

### Writing output

```julia
grid = read_egrid("CASE")
GeoEnergyIO.write_egrid(grid, "COPY"; backend = :python)
summary_data = read_summary("CASE"; format = :structured)
GeoEnergyIO.write_jutuldarcy_summary("COPY", summary_data; backend = :python)
```

The summary writer accepts the structured dictionary described in
[Industry standard format input and output](@ref). Summary units are not
written by this backend.
