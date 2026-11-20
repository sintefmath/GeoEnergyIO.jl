
# Parsing of simulation cases

## Parsing of .DATA files

The most significant feature of this module is a parser for .DATA reservoir
simulation cases. The format originated with the Eclipse reservoir simulator
produced by SLB and is now used by many reservoir simulators. The most useful
publicly available description of one such dialect is found in the [OPM Flow
manual](https://opm-project.org/?page_id=955).

```@docs
parse_data_file
```

Let us for example parse the SPE1 dataset, turning into a nested `Dict` containing all the entries of the data file. We use the unexported `test_input_file_path` utility to get the path of a test file.

```@example
using GeoEnergyIO
spe1_pth = GeoEnergyIO.test_input_file_path("SPE1", "SPE1.DATA")
spe1 = parse_data_file(spe1_pth)
```

See the [deck keyword reference](keywords.md) for supported keywords and
their record layouts.

### Handling unsupported keywords

Use the skip list to tell the parser how to consume an unsupported keyword.

```@docs
GeoEnergyIO.InputParser.skip_kw!
```

The parser ships with definitions for common skipped keywords. Add your own skip rules at the top of your script to register them in each Julia session.

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

## Parsing of .afi files and RESQML

The package includes experimental support for reading the .afi file format used by IX, as well as RESQML files for the dense data. Files that make use of .gsg files for input is not yet supported, but will parse the remainder of the .afi/ixf files.

```@docs
GeoEnergyIO.IXParser.read_afi_file
```

This function is currently unexported and subject to change. To import:

```julia
import GeoEnergyIO.IXParser: read_afi_file
afi = read_afi_file("path/to/file.afi")
```

### Example

As an example, we can parse and convert the a OLYMPUS realization from the test suite, process it as a corner-point mesh, and plot the porosity.

```@example afi_olympus
using Jutul, GeoEnergyIO, GLMakie
import GeoEnergyIO.IXParser: read_afi_file
fn = GeoEnergyIO.test_input_file_path("OLYMPUS_25_AFI_RESQML", "OLYMPUS_25.afi")
# Set the convert flag to convert data into "processed" format with converted units and keywords that can more easily be fed to other functions:
setup = read_afi_file(fn, convert = true)
```

```@example afi_olympus
grid_sec = setup["IX"]["RESQML"]["GRID"]
g = mesh_from_grid_section(grid_sec)
poro = vec(setup["IX"]["RESQML"]["POROSITY"]["values"])
actnum = vec(grid_sec["ACTNUM"])
fig, ax, plt = plot_cell_data(g, poro[actnum])
fig
```

## Other parsers

### OBSH

There is an experimental parser for the observed well data format. This is unexported and subject to change:

```@docs
GeoEnergyIO.IXParser.read_obsh_file
```

To make use of it, it must be explicitly imported:

```julia
import GeoEnergyIO.IXParser: read_obsh_file
obsh = read_obsh_file("path/to/FILE.OBSH")
```
