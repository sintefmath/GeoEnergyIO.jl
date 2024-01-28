# GeoEnergyIO

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://sintefmath.github.io/GeoEnergyIO.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://sintefmath.github.io/GeoEnergyIO.jl/dev/)
[![Build Status](https://github.com/sintefmath/GeoEnergyIO.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/sintefmath/GeoEnergyIO.jl/actions/workflows/CI.yml?query=branch%3Amain)

Module for parsing and processing various types of input files used in geo-energy reservoir simulation (geothermal, carbon storage, gas storage, oil and gas recovery).

Currently contains two main features:

- Parser for .DATA files used by many reservoir simulators.
- A corner-point grid processor that converts parsed GRDECL files into unstructured meshes that handles general faults.

This module is unregistered and work-in-progress. It is extracted from the Julia reservoir simulation package [JutulDarcy.jl](https://github.com/sintefmath/JutulDarcy.jl) and will eventually replace the parser in JutulDarcy.
