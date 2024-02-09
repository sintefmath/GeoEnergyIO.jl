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
using GeoEnergyIO, Jutul, CairoMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "1cell.txt", base = missing)
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
fig, ax, plt = plot_mesh(g, shading = false, rasterize = true)
Jutul.plot_mesh_edges!(ax, g)
fig
```

To understand a bit more of how this format behaves in practice, we can look at a faulted mesh:

```@example
using GeoEnergyIO, Jutul, CairoMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "raised_col_sloped.txt", base = missing)
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
fig, ax, plt = plot_mesh(g, shading = NoShading, rasterize = true)
Jutul.plot_mesh_edges!(ax, g)
fig
```

More complicated meshes include multiple faults. One synthetic test model is the `model3` case from [MRST](https://www.mrst.no):

```@example
using GeoEnergyIO, Jutul, CairoMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "model3_5_5_5.txt", base = missing)
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
ix = 1:number_of_cells(g)
fig = Figure()
ax = Axis3(fig[1,1], zreversed = true, azimuth = 2.0)
plot_cell_data!(ax, g, ix, shading = NoShading, rasterize = true, colormap = :seaborn_icefire_gradient)
fig
```

We can also parse a high-resolution version of the same case:

```@example
using GeoEnergyIO, Jutul, CairoMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "model3_20_20_50.txt", base = missing)
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

## Utilities

```@docs
get_data_file_cell_region
number_of_tables
```

## Index of functions

```@index
```
