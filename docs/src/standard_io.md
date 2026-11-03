# Industry standard format input and output

```@docs
GeoEnergyIO.StandardIO
```

## Reading output

Paths may include the file extension or specify the case basename. The default
backend is pure Julia. See [resdata backend](@ref) for `backend=:python`.

```julia
using GeoEnergyIO
grid = read_egrid("CASE")
mesh = mesh_from_grid_section(grid)
init = read_init("CASE"; units = :si, actnum = grid["ACTNUM"])
steps = read_restart("CASE"; units = :si, steps = [1, 3])
summary = read_summary("CASE"; format = :structured)
```

INIT and restart arrays use native units by default. `units=:si` converts
known physical quantities; unknown arrays keep their file values. EGRID
geometry defaults to metres. ACTNUM masks reduce full-grid cell arrays.

Summary values use the units declared in SMSPEC. The default layout is a flat
dictionary, for example `summary["WOPR"]["PRODUCER"]`. `format=:structured`
groups arrays in `VALUES` and includes dimensions, units, elapsed seconds,
start date and column metadata.

```@docs
read_restart
read_init
read_egrid
read_summary
GeoEnergyIO.StandardIO.input.read_restart
GeoEnergyIO.StandardIO.input.read_init
GeoEnergyIO.StandardIO.input.read_egrid
GeoEnergyIO.StandardIO.input.read_summary
```

## Writing output

```julia
write_egrid(grid, "COPY")
init, raw_init = read_init("CASE"; extra_out = true)
write_init(raw_init, "COPY")
steps, raw_steps = read_restart("CASE"; extra_out = true)
write_restart(raw_steps, "COPY")
write_summary(summary, "COPY"; unified = false)
```

Writers support metric, field and laboratory units. Summary arrays use
`UNIT_SYSTEM`; `TIME.seconds` uses seconds. SI summaries default to metric
output. Set `units=:field` or `units=:lab` to select another system.
With column metadata, `VALUES` supplies arrays and `COLUMNS` supplies their
order and identities. Input arrays are not modified.

```@docs
GeoEnergyIO.write_egrid
GeoEnergyIO.StandardIO.output.write_egrid
GeoEnergyIO.StandardIO.output.write_init
GeoEnergyIO.StandardIO.output.write_restart
GeoEnergyIO.StandardIO.output.write_summary
GeoEnergyIO.write_jutuldarcy_summary
```

## Keyword files

The ordered interface preserves numeric types, repeated keywords, local grids
and unknown arrays.

```julia
raw = read_binary("CASE.INIT")
porosity = raw["PORO"]
all_porosity = keyword_values(raw, "PORO")
write_binary("COPY.INIT", raw)
```

```@docs
GeoEnergyIO.StandardIO.read_binary
GeoEnergyIO.StandardIO.write_binary
GeoEnergyIO.StandardIO.BinaryKeyword
GeoEnergyIO.StandardIO.KeywordFile
```

INTE, REAL, DOUB, LOGI, CHAR, Cnnn and MESS records support both byte orders.
Output defaults to big endian. String padding and LOGI true values are
normalized on write. Formatted text, arrays above the signed 32-bit element
limit and PVT-M unit conversion are not supported.

EGRID dictionaries represent the main grid; raw records include local grids
and dual-grid metadata. Restart export contains reservoir solution arrays,
without the well, control and solver state needed to resume another simulator.
Summary history referenced through RESTART is not merged automatically.
