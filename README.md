# GeoEnergyIO

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://sintefmath.github.io/GeoEnergyIO.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://sintefmath.github.io/GeoEnergyIO.jl/dev/)
[![Build Status](https://github.com/sintefmath/GeoEnergyIO.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/sintefmath/GeoEnergyIO.jl/actions/workflows/CI.yml?query=branch%3Amain)

Module for parsing and processing various types of input files used in geo-energy reservoir simulation (geothermal, carbon storage, gas storage, oil and gas recovery).

Currently contains several features:

- Parser for .DATA reservoir simulation cases. The format originated with the Eclipse reservoir simulator produced by SLB and is now used by many reservoir simulators. The most useful publicly available description of one such dialect is found in the [OPM Flow manual](https://opm-project.org/?page_id=955).
- A corner-point grid processor that converts parsed GRDECL files into unstructured meshes that handles general faults through the unstructured mesh from [Jutul.jl](https://github.com/sintefmath/Jutul.jl).
- Support for reading and writing output files from Eclipse-type output (summary, EGRID, restarts) via the [resdata Python library](https://github.com/equinor/resdata).
- A corner-point generator with support for faults and pinch that makes `GRID` sections from geological horizons and transformations.

Here is an example mesh parsed from the [OLYMPUS Optimization Benchmark Challenge](https://doi.org/10.1007/s10596-020-10003-4):

![image](docs/src/assets/olympus_small.gif)

The supported file formats contain a great number of possible keywords. Not all keywords are supported. For keywords with limited support, a warning will be emitted. Contributions for additional keywords or other relevant input formats are welcome. If you have an example that you'd like to get working, please post it under the [issues tab](https://github.com/sintefmath/GeoEnergyIO.jl/issues). GeoEnergyIO.jl originated as a part of the Julia reservoir simulation package [JutulDarcy.jl](https://github.com/sintefmath/JutulDarcy.jl) where it enables reservoir simulation of simulation cases read from input files.

## Installation

The package is registered in the official Julia registry. Install [Julia](https://julialang.org/) and install using the package manager:

```julia
using Pkg;
Pkg.add("GeoEnergyIO")
```

## Usage

Once the module is installed you can read a `.DATA` file with all include files:

```julia
using GeoEnergyIO
data = parse_data_file("MY_MODEL.DATA")
```

Units will automatically be converted to strict SI by default. If you want 

You can also read `.GRDECL` files that contain a specification of a corner point grid:

```julia
grdecl = parse_grdecl_file("MY_GRID.GRDECL")
```

This can then be processed and converted into a volumetric grid suitable for visualization or simulation:

```julia
g = mesh_from_grid_section(grdecl)
```

For more information and a description of different options, see the [latest documentation](https://sintefmath.github.io/GeoEnergyIO.jl/dev/).

## License and acknowledgements

The code is provided under the MIT license, allowing for commercial usage provided that sufficient attribution is provided. The test data sets come in part from the [opm-tests](https://github.com/opm/opm-tests) repository. These files are licensed under the [Open Database License](http://opendatacommons.org/licenses/odbl/1.0/). For more details, see the headers of those files. Other files are taken from or generated by [MRST](https://mrst.no/). Optional support for the [resdata Python library](https://github.com/equinor/resdata) is included as a package extension, but note that resdata is, at the time of writing, licensed as GPL-3.0.
