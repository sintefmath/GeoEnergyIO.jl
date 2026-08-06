```@meta
CurrentModule = GeoEnergyIO
```

# GeoEnergyIO

Documentation for [GeoEnergyIO](https://github.com/sintefmath/GeoEnergyIO.jl). See the subpages on the left for more details on functionality.

## Unit conversion

The package includes utilities for converting between different unit systems (SI units, oil field units, lab units and metric units). The convention is to convert all read data into strict SI units unless otherwise requested and this is normally handled automatically by the parser. A convenience utility is included to convert numerical values between different unit systems, provided that the meaning of the quantity is supported:

```@docs
convert_between_unit_systems
```

## Internals

```@docs
GeoEnergyIO.InputParser.keyword_default_value
```

## Index of functions

```@index
```
