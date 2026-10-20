# Industry standard format input and output

```@docs
GeoEnergyIO.StandardIO
```

Python and external runtime libraries are not required for these readers and
writers.

## Reading files

Paths may be case basenames or include the relevant file extension.

```julia
using GeoEnergyIO
grid = read_egrid("CASE")                # SI geometry; accepted by mesh_from_grid_section
mesh = mesh_from_grid_section(grid)
init = read_init("CASE"; units = :si, actnum = grid["ACTNUM"])
steps = read_restart("CASE"; units = :si, steps = [1, 3])
summary = read_summary("CASE"; format = :structured)
```

INIT and restart readers retain native output units by default, matching the
existing API. Set `units=:si` to convert known pressure, temperature,
permeability, geometry, volume, ratio, density, viscosity and transmissibility
arrays to SI units. Unknown arrays retain their file values.
The EGRID reader defaults to metres; use `units=:native` for original geometry.
ACTNUM masks reduce full-grid cell arrays and leave already-active arrays alone.

Summary values retain the unit system in SMSPEC. The default summary layout is
the existing flat dictionary, for example `summary["WOPR"]["PRODUCER"]`.
`format=:structured` returns `DIMENS`, `UNIT_SYSTEM`, `TIME` (seconds and start
date), and `VALUES` with FIELD, WELLS, GROUP and other categories. `UNITS` and
`COLUMNS` retain the original column metadata.

Unified UNRST/UNSMRY and separate Xnnnn/Snnnn files are supported, including gaps
in separate file numbering. The restart `steps` argument selects report
positions, retaining the actual report number in `report_step`.
Writers use lowercase extensions for lowercase case names, following the file
discovery convention used by existing readers.

```@docs
read_restart
read_init
read_egrid
read_summary
```

The file-specific interfaces provide these options:

```@docs
GeoEnergyIO.StandardIO.input.read_restart
GeoEnergyIO.StandardIO.input.read_init
GeoEnergyIO.StandardIO.input.read_egrid
GeoEnergyIO.StandardIO.input.read_summary
```

## Writing dictionaries and keyword files

The file writers accept grid and summary dictionaries, INIT arrays, and restart
dictionaries or ordered keyword blocks:

```julia
grid = read_egrid("CASE")
write_egrid(grid, "COPY")
init, raw_init = read_init("CASE"; extra_out = true)
write_init(raw_init, "COPY")
steps, raw_steps = read_restart("CASE"; extra_out = true)
write_restart(raw_steps, "COPY")
summary = read_summary("CASE"; format = :structured)
write_summary(summary, "COPY"; unified = false)
```

Writers support metric, field and laboratory units. Summary arrays use their
declared `UNIT_SYSTEM`; `TIME.seconds` always uses seconds. Dictionaries with
`UNIT_SYSTEM="SI"` are converted to metric by default. Set `units=:field` (or
another output system) to convert recognized summary quantities.
When re-exporting a structured summary, `VALUES` supplies the current arrays;
`COLUMNS` preserves their original ordering and identities.
Long well names use Cnnn strings. Writers do not modify input arrays.

```@docs
GeoEnergyIO.StandardIO.output.write_egrid
GeoEnergyIO.StandardIO.output.write_init
GeoEnergyIO.StandardIO.output.write_restart
GeoEnergyIO.StandardIO.output.write_summary
```

## Generic keyword files

For arbitrary INIT, restart, RFT and other keyword files, the ordered interface
preserves numeric types, repeated keywords, local grid records and unknown
simulator-specific arrays:

```julia
raw = read_binary("CASE.INIT")
porosity = raw["PORO"]                     # first occurrence
all_porosity = keyword_values(raw, "PORO") # every occurrence
write_binary("COPY.INIT", raw)
```

```@docs
GeoEnergyIO.StandardIO.read_binary
GeoEnergyIO.StandardIO.write_binary
GeoEnergyIO.StandardIO.BinaryKeyword
GeoEnergyIO.StandardIO.KeywordFile
```

The generic layer supports INTE, REAL, DOUB, LOGI, CHAR, Cnnn and empty MESS
keywords, both byte orders, and validates all Fortran record markers. Outputs
default to big endian. Use `extra_out=true` on a reader for its ordered raw
records. String padding and LOGI true encodings are normalized when rewritten.

## Scope

The file-specific EGRID interface represents the main corner-point grid. Raw
records preserve local grids and dual-grid metadata. Restart export contains
reservoir solution arrays suitable for visualization and state initialization;
it does not contain the full well, control and solver state required to resume
another simulator. Summary history referenced through RESTART is not merged
automatically. Formatted text output, arrays larger than the signed 32-bit
element-count limit, and PVT-M physical unit conversion are not supported.

The optional legacy Python/resdata readers remain available with
`backend=:python` after loading PythonCall. The public readers use
`backend=:julia` by default and accept the options documented above:

```julia
using PythonCall
legacy_summary = read_summary("CASE"; backend = :python)
```

The existing summary compatibility entry point is also retained:

```@docs
GeoEnergyIO.write_jutuldarcy_summary
```
