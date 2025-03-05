# Parsing and processing of corner-point grids

Corner-point meshes are the de-facto standard format for simulation of subsurface flow. These meshes are semi-structured, but can have quite complex structure in practice due to eroded and collapsed cells and the presence of faults. This module includes a processor to convert the input format into a mesh that can be used for simulation. Converting the corner-points into a mesh with a connected topology is non-trivial, but the included algorithm has been verified on a number of real-field assets.

There are two main functions to parse and process corner-point inputs:

```@docs
parse_grdecl_file
mesh_from_grid_section
```

## Example corner point meshes

The module ships with several corner point grids suitable for testing. These include partially collapsed cells, faults and other degenerate cases that the parser should be able to handle. We can make a few plots of such test grids. The first example is a single hexahedral cell:

```@example
using GeoEnergyIO, Jutul, GLMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "1cell.txt")
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
fig, ax, plt = plot_mesh(g)
Jutul.plot_mesh_edges!(ax, g)
fig
```

To understand a bit more of how this format behaves in practice, we can look at a faulted mesh:

```@example
using GeoEnergyIO, Jutul, GLMakie
pth = GeoEnergyIO.test_input_file_path("grdecl", "raised_col_sloped.txt")
grdecl = parse_grdecl_file(pth)
g = mesh_from_grid_section(grdecl)
fig, ax, plt = plot_mesh(g)
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
plot_cell_data!(ax, g, ix, colormap = :seaborn_icefire_gradient)
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
plot_cell_data!(ax, g, ix, colormap = :seaborn_icefire_gradient)
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
plot_cell_data!(ax, g, ix, colormap = :seaborn_icefire_gradient)
fig
```

## Generation of corner-point meshes

The package also contains functionality for generating corner-point meshes.

```@docs
cpgrid_from_horizons
```

### Example of mesh generation

Let us look at how the corner-point generator can be used in practice. A common concept of horizons, a more or less continious surface where the litography changes significantly. Typically these horizons would come from data, but for the purpose of this example we will generate some noisy surfaces with different averages and trends. One matrix for the top surface, one for the middle and one for the bottom of our domain.

```@example cpgrid_gen
using GeoEnergyIO, Jutul, GLMakie
nx = ny = 25
Lx = 1000.0
Ly = 800.0
xrng = range(0.0, Lx, nx)
yrng = range(0.0, Ly, ny)
depths = [
    5 .*rand(nx, ny),
    5 .*rand(nx, ny) .+ 30.0,
    5 .*rand(nx, ny) .+ 100.0 .- xrng/Lx*40.0
]
fig = Figure()
ax = Axis3(fig[1, 1], zreversed = true)
colors = Makie.wong_colors()
for (c, layer) in enumerate(depths)
    surface!(ax, xrng, yrng, layer, color = fill(colors[c], nx, ny), shading = NoShading)
end
fig

```

We generate a mesh based on these depth matrices for each horizon, creating two layers with three cells each, and turn the keyword `Dict` into a mesh:

```@example cpgrid_gen
grd = cpgrid_from_horizons(xrng, yrng, depths, layer_width = 3)
mesh = mesh_from_grid_section(grd)
fig, ax, plt = plot_cell_data(mesh, grd["LAYERNUM"][mesh.cell_map], colormap = :winter)
Jutul.plot_mesh_edges!(ax, mesh)
fig
```

Let us say that the data was at a different resolution than what we want for our simulation mesh. We can increase or decrease the resolution by a third keyword argument, which will use linear interpolation to add additional points:

```@example cpgrid_gen
grd = cpgrid_from_horizons(xrng, yrng, depths, (100, 100), layer_width = [20, 25])
mesh2 = mesh_from_grid_section(grd)
fig, ax, plt = plot_cell_data(mesh2, grd["LAYERNUM"][mesh2.cell_map], colormap = :winter)
Jutul.plot_mesh_edges!(ax, mesh2)
fig
```

We can also add various transforms to make the model complex. There are two types of supported transforms:

1. Vertical transforms, which can be multiple transforms that change the depths of corner points based on the cell centroid and original corner points. These are typically used to create faults.
2. Pillar transforms, which can alter the top and bottom points of the pillars that define the corner point mesh. A single transform is supported at the time.

We will now do the following:

1. Introduce two faults, one sloping and one with fixed throw.
2. Add a pillar transform that makes the mesh smaller for increasing depth.

```@example cpgrid_gen
fault1 = (x, y, z, x_c, y_c, i, j, k) -> ifelse(x_c/Lx + 0.25*y_c/Ly > 0.5, z + 50.0.*(y/Ly) + 15.0, z)
fault2 = (x, y, z, x_c, y_c, i, j, k) -> ifelse(y_c/Ly > 0.5, z + 25.0, z)
transforms = [fault1, fault2]
xy_transform = (x, y, i, j, zt, zb) -> (x, y, 0.9*x, 0.8*y)
grd = cpgrid_from_horizons(xrng, yrng, depths,
    layer_width = 3,
    transforms = transforms,
    xy_transform = xy_transform
)
mesh3 = mesh_from_grid_section(grd)
fig, ax, plt = plot_cell_data(mesh3, grd["LAYERNUM"][mesh3.cell_map], colormap = :winter)
ax.azimuth[] = 5.44
Jutul.plot_mesh_edges!(ax, mesh3)
fig
```

We can also make cells inactive by setting `NaN` values in the depths. Note that as each entry in `depths` corresponds to the intersection between two layers, we set `NaN` in the top and bottom depths to impact the two layers separately. For more fine grained control, the `"ACTNUM"` array is also present and can be altered before `mesh_from_grid_section` is called.

```@example cpgrid_gen
for i in 1:nx
    for j in 1:ny
        center_dist = sqrt((xrng[i] - 500)^2 + (yrng[j] - 400)^2)
        if center_dist > 400
            depths[1][i, j] = NaN
        end
        if center_dist > 500
            depths[3][i, j] = NaN
        end
    end
end
grd = cpgrid_from_horizons(xrng, yrng, depths, layer_width = [20, 25])
mesh4 = mesh_from_grid_section(grd)
fig, ax, plt = plot_cell_data(mesh4, grd["LAYERNUM"][mesh4.cell_map], colormap = :winter)
Jutul.plot_mesh_edges!(ax, mesh4)
fig
```

## Utilities

```@docs
get_data_file_cell_region
number_of_tables
```
