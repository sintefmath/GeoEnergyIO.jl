```@meta
CurrentModule = GeoEnergyIO
```

# GeoEnergyIO

Documentation for [GeoEnergyIO](https://github.com/sintefmath/GeoEnergyIO.jl).

## Parsing of simulation cases

The main feature of this module is at the time of writing a parser for .DATA reservoir simulation cases. The format originated with the Eclipse reservoir simulator produced by SLB and is now used by many reservoir simulators. The most useful publicly available description of one such dialect is found in the [OPM Flow manual](https://opm-project.org/?page_id=955).

```@docs
parse_data_file
```

Let us for example parse the SPE1 dataset, turning into a nested `Dict` containing all the entries of the data file. We use the unexported `test_input_file_path` utility to get the path of a test file.

```@example
using GeoEnergyIO
spe1_pth = GeoEnergyIO.test_input_file_path("SPE1", "SPE1.DATA")
spe1 = parse_data_file(spe1_pth)
```

### Handling unsupported keywords

Not all keywords are supported by the parser, but not all keywords are important. The input format is such that it is difficult to automatically skip keywords, but you an manually add keywords to the skip list:

```@docs
GeoEnergyIO.InputParser.skip_kw!
```

Adding keywords to the skip list is not persistent across Julia sessions and can be added to the top of your script. Contributions to the global skip list defined in the `__init__` function of the parser are welcome.

```@example
using GeoEnergyIO
# Skip keyword without data
GeoEnergyIO.InputParser.skip_kw!(:MY_KW, 0)
# Keyword with a single record of data, e.g.
# MY_DATA_KW
# "some data" 1 2 3 /
GeoEnergyIO.InputParser.skip_kw!(:MY_DATA_KW, 1)
# Keyword with many records, terminated by empty record:
# MY_LONG_DATA_KW
# "some data" 1 2 3 /
# "more data" 4 5 6 /
# "even more data" 1 9 /
# /
GeoEnergyIO.InputParser.skip_kw!(:MY_LONG_DATA_KW, Inf)
```

## Parsing and processing of corner-point grids

Corner-point meshes are the de-facto standard format for simulation of subsurface flow. These meshes are semi-structured, but can have quite complex structure in practice due to eroded and collapsed cells and the presence of faults. This module includes a processor to convert the input format into a mesh that can be used for simulation. Converting the corner-points into a mesh with a connected topology is non-trivial, but the included algorithm has been verified on a number of real-field assets.

There are two main functions to parse and process corner-point inputs:

```@docs
parse_grdecl_file
mesh_from_grid_section
```

### Example corner point meshes

The module ships with several corner point grids suitable for testing. These include partially collapsed cells, faults and other degenerate cases that the parser should be able to handle. We can make a few plots of such test grids. The first example is a single hexahedral cell:

```@example
using GeoEnergyIO, Jutul, GLMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "1cell.txt")
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
fig, ax, plt = plot_mesh(g, shading = false, rasterize = true)
Jutul.plot_mesh_edges!(ax, g)
fig
```

To understand a bit more of how this format behaves in practice, we can look at a faulted mesh:

```@example
using GeoEnergyIO, Jutul, GLMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "raised_col_sloped.txt")
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
fig, ax, plt = plot_mesh(g, shading = NoShading, rasterize = true)
Jutul.plot_mesh_edges!(ax, g)
fig
```

More complicated meshes include multiple faults. One synthetic test model is the `model3` case from [MRST](https://www.mrst.no):

```@example
using GeoEnergyIO, Jutul, GLMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "model3_5_5_5.txt")
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
ix = collect(1:number_of_cells(g))
fig = Figure()
ax = Axis3(fig[1,1], zreversed = true, azimuth = 2.0)
plot_cell_data!(ax, g, ix, shading = NoShading, rasterize = true, colormap = :seaborn_icefire_gradient)
fig
```

We can also parse a high-resolution version of the same case:

```@example
using GeoEnergyIO, Jutul, GLMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "model3_20_20_50.txt")
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
ix = collect(1:number_of_cells(g))
fig = Figure()
ax = Axis3(fig[1,1], zreversed = true, azimuth = 2.0)
plot_cell_data!(ax, g, ix, shading = NoShading, rasterize = true, colormap = :seaborn_icefire_gradient)
fig
```

The parser has been tested on many complex models. Here is an example mesh parsed from the [OLYMPUS Optimization Benchmark Challenge](https://doi.org/10.1007/s10596-020-10003-4) where the parsed porosity is plotted together with the wells:

![image](assets/olympus_small.gif)

We can parse this mesh in the same manner as before:

```@example
using GeoEnergyIO, Jutul, GLMakie
pth = GeoEnergyIO.test_input_file_path("OLYMPUS_1", "OLYMPUS_GRID.GRDECL")
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
ix = collect(1:number_of_cells(g))
fig = Figure()
ax = Axis3(fig[1,1], zreversed = true, azimuth = 2.0)
plot_cell_data!(ax, g, ix, shading = NoShading, rasterize = true, colormap = :seaborn_icefire_gradient)
fig
```

### Generation of corner-point meshes

The package also contains functionality for generating corner-point meshes.

```@docs
cpgrid_from_horizons
```

## Utilities

```@docs
get_data_file_cell_region
number_of_tables
```

## Internals

```@docs
GeoEnergyIO.InputParser.keyword_default_value
```

## Index of functions

```@index
```

# Extensions

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

```@docs
write_egrid
write_jutuldarcy_summary
```
