# resdata extension: Dealing with summary, restart and egrid files

## Input and output using resdata package

The Python package [resdata](https://github.com/equinor/resdata) developed by Equinor can be loaded to add support for reading summary files (sparse data), egrid (processed grid), init (initial conditions) and restart (cell-wise results).

!!! note "resdata is GPL-3.0 licensed"
    The resdata package is under a different license than GeoEnergyIO which uses MIT. The licenses are compatible, but a distributed product that contains resdata must comply with the terms of the GPL license.

To add support for this extension, you have to add `PythonCall` to your environment (one-time operation):

```julia
using Pkg
Pkg.add("PythonCall")
```

Afterwards, you can then load the package to get access to the new functions:

```julia
using PythonCall
```

### Reading output

```@docs
read_restart
read_init
read_egrid
read_summary
```

### Writing output

!!! warning "Experimental features"
    Writing files is currently highly experimental. Not all fields are properly set in summary files (e.g. units).

```@docs
GeoEnergyIO.write_egrid
GeoEnergyIO.write_jutuldarcy_summary
```
