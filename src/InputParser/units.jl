function current_unit_system(deck)
    rs = deck["RUNSPEC"]
    choices = ["METRIC", "SI", "LAB", "FIELD"]
    found = false
    sys = missing
    for choice in choices
        if haskey(rs, choice)
            @assert ismissing(sys) "Cannot have multiple unit keywords (encountered $choice and $sys)"
            sys = choice
        end
    end
    if ismissing(sys)
        @warn "Units not found. Assuming field units."
        out = :field
    else
        out = Symbol(lowercase(sys))
    end
    return out
end

Base.@kwdef struct DeckUnitSystem{S, T}
    length::T = 1.0
    area::T = 1.0
    time::T = 1.0
    density::T = 1.0
    pressure::T = 1.0
    mol::T = 1.0
    mass::T = 1.0
    u_rs::T = 1.0
    u_rv::T = 1.0
    concentration::T = 1.0
    compressibility::T = 1.0
    viscosity::T = 1.0
    surface_tension::T = 1.0
    jsurface_tension::T = 1.0
    permeability::T = 1.0
    liquid_volume_surface::T = 1.0
    liquid_volume_reservoir::T = 1.0
    liquid_formation_volume_factor::T = 1.0
    gas_volume_surface::T = 1.0
    gas_volume_reservoir::T = 1.0
    gas_formation_volume_factor::T = 1.0
    volume::T = 1.0
    transmissibility::T = 1.0
    rock_conductivity::T = 1.0
    volume_heat_capacity::T = 1.0
    mass_heat_capacity::T = 1.0
    molar_mass::T = 1.0
    relative_temperature::Symbol = :Celsius
    absolute_temperature::Symbol = :Kelvin
    absolute_temperature_numeric::T = 1.0
end

function DeckUnitSystem(sys::DeckUnitSystem)
    return sys
end

function DeckUnitSystem(sys::AbstractString, T = Float64)
    return DeckUnitSystem(Symbol(lowercase(sys)), T)
end

function DeckUnitSystem(sys::Symbol = :si, T = Float64)
    u = Jutul.all_units()
    m = u[:meter]
    K = u[:kelvin]
    day = u[:day]
    centi = u[:centi]
    kilogram = u[:kilogram]
    ft = u[:feet]
    psi = u[:psi]
    pound = u[:pound]
    kilo = u[:kilo]
    stb = u[:stb]
    rankine = u[:rankine]
    btu = u[:btu]
    J = u[:joule]
    kJ = u[:kilo]*J

    # Commons
    cP = u[:centi]*u[:poise]
    mD = u[:milli]*u[:darcy]
    if sys == :metric
        len = m
        volume = m^3
        time = day
        pressure = u[:bar]
        mol = u[:kilo]
        mass = kilogram
        viscosity = cP
        surface_tension = u[:newton]/m
        jsurface_tension = u[:dyne]/(centi*m)
        permeability = mD
        liquid_volume_surface = volume
        liquid_volume_reservoir = volume
        gas_volume_surface = volume
        gas_volume_reservoir = volume
        rock_conductivity = kJ/(m*day*K)
        volume_heat_capacity = kJ/(volume*K)
        mass_heat_capacity = kJ/(mass*K)
        relative_temperature = :Celsius
        absolute_temperature = :Kelvin
        absolute_temperature_numeric = K
    elseif sys == :field
        len = ft
        time = day
        pressure = psi
        mol = pound*kilo
        mass = pound
        viscosity = cP
        surface_tension = u[:lbf]/u[:inch]
        jsurface_tension = u[:dyne]/(centi*m)
        permeability = mD
        liquid_volume_surface = stb
        liquid_volume_reservoir = stb
        gas_volume_surface = kilo*ft^3
        gas_volume_reservoir = stb
        rock_conductivity = btu / (ft*day*rankine)
        volume_heat_capacity = btu / (ft^3*rankine)
        mass_heat_capacity = btu / (pound*rankine)
        relative_temperature = :Fahrenheit
        absolute_temperature = :Rankine
        absolute_temperature_numeric = rankine
    elseif sys == :lab
        hr = u[:hour]
        len = centi*m
        volume = len^3
        pressure = u[:atm]
        time = hr
        mol = u[:gram]
        molar_mass = 1/(mol)
        mass = u[:gram]
        viscosity = cP
        liquid_volume_surface = volume
        liquid_volume_reservoir = volume
        gas_volume_surface = volume
        gas_volume_reservoir = volume
        surface_tension = u[:dyne]/(centi*m)
        jsurface_tension = u[:dyne]/(centi*m)
        permeability = mD
        volume_heat_capacity = J/(volume*K)
        mass_heat_capacity = J/(mass*K)
        rock_conductivity = kJ/(centi*m*hr*K)
        relative_temperature = :Celsius
        absolute_temperature = :Kelvin
        absolute_temperature_numeric = K
    elseif sys == :si
        len = 1.0
        time = 1.0
        pressure = 1.0
        mol = 1.0
        mass = 1.0
        viscosity = 1.0
        surface_tension = 1.0
        jsurface_tension = 1.0
        permeability = 1.0
        liquid_volume_surface = 1.0
        liquid_volume_reservoir = 1.0
        gas_volume_surface = 1.0
        gas_volume_reservoir = 1.0
        rock_conductivity = 1.0
        volume_heat_capacity = 1.0
        mass_heat_capacity = 1.0
        relative_temperature = :Celsius
        absolute_temperature = :Kelvin
        absolute_temperature_numeric = K
    else
        error("Unknown unit system: $sys. Valid options are :si, :metric, :field, and :lab.")
    end
    molar_mass = 1/(mol)
    area = len^2
    volume = len^3
    density = mass/volume
    concentration = mass/volume
    compressibility = 1.0/pressure
    transmissibility = viscosity * liquid_volume_reservoir / (time * pressure)
    return DeckUnitSystem{sys, T}(
        length = len,
        area = area,
        time = time,
        u_rs = gas_volume_surface/liquid_volume_surface,
        u_rv = liquid_volume_surface/gas_volume_surface,
        density = density,
        pressure = pressure,
        mol = mol,
        mass = mass,
        concentration = concentration,
        compressibility = compressibility,
        viscosity = viscosity,
        surface_tension = surface_tension,
        jsurface_tension = jsurface_tension,
        permeability = permeability,
        liquid_volume_surface = liquid_volume_surface,
        liquid_volume_reservoir = liquid_volume_reservoir,
        liquid_formation_volume_factor = liquid_volume_reservoir/liquid_volume_surface,
        gas_volume_surface = gas_volume_surface,
        gas_volume_reservoir = gas_volume_reservoir,
        gas_formation_volume_factor = gas_volume_reservoir/gas_volume_surface,
        volume = volume,
        molar_mass = molar_mass,
        transmissibility = transmissibility,
        rock_conductivity = rock_conductivity,
        volume_heat_capacity = volume_heat_capacity,
        mass_heat_capacity = mass_heat_capacity,
        relative_temperature = relative_temperature,
        absolute_temperature = absolute_temperature,
        absolute_temperature_numeric = absolute_temperature_numeric
    )
end

function deck_unit_system_label(::DeckUnitSystem{S, T}) where {S, T}
    return S
end

function swap_unit_system_axes!(x::AbstractMatrix, systems, eachunit; dim = 2)
    @assert eltype(eachunit)<:Symbol
    @assert size(x, dim) == length(eachunit)
    if dim == 1
        x_t = x'
    else
        x_t = x
    end
    for i in axes(x_t, 2)
        x_i = view(x_t, :, i)
        swap_unit_system!(x_i, systems, eachunit[i])
    end
    return x
end

function swap_unit_system_axes!(x::AbstractVector, systems, eachunit)
    @assert eltype(eachunit)<:Symbol
    @assert length(x) == length(eachunit) "Recieved vector of length $(length(x)) but units were $(length(eachunit)) long."
    for i in eachindex(x)
        x[i] = swap_unit_system(x[i], systems, eachunit[i])
    end
    return x
end

function swap_unit_system!(x::AbstractArray, systems, k)
    return swap_unit_system!(x, systems, Val(k))
end

function swap_unit_system_fast!(v, systems::Union{Nothing, Missing}, k::Val)
    # No systems - trivial conversion
    return v
end

function swap_unit_system_fast!(x::AbstractArray, systems::NamedTuple, k::Val)
    (; to, from) = systems

    to_unit = deck_unit(to, k)
    from_unit = deck_unit(from, k)

    val_si = convert_to_si(1.0, from_unit)
    val_final = convert_from_si(val_si, to_unit)

    val_final::Float64
    for i in eachindex(x)
        x[i] *= val_final
    end
    return x
end

function swap_unit_system!(x::AbstractArray, systems, k::Val)
    for i in eachindex(x)
        x[i] = swap_unit_system(x[i], systems, k)
    end
    return x
end

function swap_unit_system(val, systems, k::Symbol)
    return swap_unit_system(val, systems, Val(k))
end

function swap_unit_system(v, systems::Union{Nothing, Missing}, k::Val)
    # No systems - trivial conversion
    return v
end

function swap_unit_system(v, systems::Union{Nothing, Missing}, k::Symbol)
    # No systems - trivial conversion
    return v
end

function swap_unit_system(val, systems::NamedTuple, ::Union{Val{:identity}, Val{:id}})
    # Identity specifically means no unit.
    return val
end

function identity_unit_vector(x)
    return identity_unit_vector(length(x))
end

function identity_unit_vector(n::Int)
    utypes = Vector{Symbol}(undef, n)
    fill!(utypes, :id)
    return utypes
end

function swap_unit_system(val, systems::NamedTuple, U::Val{k}; reverse = false) where k
    (; to, from) = systems
    if reverse
        to, from = from, to
    end
    to_unit = deck_unit(to, U)
    from_unit = deck_unit(from, U)

    val_si = convert_to_si(val, from_unit)
    val_final = convert_from_si(val_si, to_unit)
    return val_final
end

function deck_unit(sys::DeckUnitSystem, s::Symbol)
    return deck_unit(sys, Val(s))
end

function deck_unit(sys::DeckUnitSystem, ::Val{k}) where k
    return getproperty(sys, k)
end

# Magic type overloads

function deck_unit(sys::DeckUnitSystem, ::Val{:Kh})
    return deck_unit(sys, :permeability)*deck_unit(sys, :length)
end

function deck_unit(sys::DeckUnitSystem, ::Val{:gigapascal})
    return si_unit(:Pa)*si_unit(:giga)
end

function deck_unit(sys::DeckUnitSystem, ::Val{:time_over_volume})
    return deck_unit(sys, :time)/deck_unit(sys, :volume)
end

function deck_unit(sys::DeckUnitSystem, ::Val{:liquid_rate_surface})
    return deck_unit(sys, :liquid_volume_surface)/deck_unit(sys, :time)
end

function deck_unit(sys::DeckUnitSystem, ::Val{:gas_rate_surface})
    return deck_unit(sys, :gas_volume_surface)/deck_unit(sys, :time)
end

function deck_unit(sys::DeckUnitSystem, ::Val{:liquid_rate_reservoir})
    return deck_unit(sys, :liquid_volume_reservoir)/deck_unit(sys, :time)
end

function deck_unit(sys::DeckUnitSystem, ::Val{:gas_rate_reservoir})
    return deck_unit(sys, :gas_volume_reservoir)/deck_unit(sys, :time)
end

function deck_unit(sys::DeckUnitSystem, ::Val{:critical_volume})
    return deck_unit(sys, :volume)/deck_unit(sys, :mol)
end

function deck_unit(sys::DeckUnitSystem, ::Val{:thermal_expansion_c1})
    return 1.0/deck_unit(sys, :absolute_temperature_numeric)
end

function deck_unit(sys::DeckUnitSystem, ::Val{:thermal_expansion_c2})
    u = deck_unit(sys, :absolute_temperature_numeric)
    return 1.0/u^2
end

function deck_unit(sys::DeckUnitSystem, ::Val{:aquifer_transmissibility})
    return deck_unit(sys, :transmissibility)/deck_unit(sys, :viscosity)
end

# High level unit support - exposed to users

"""
    val = convert_between_unit_systems(val, value_type; from = :field, to = :si)
    val = convert_between_unit_systems(val, value_type, from, to)

Convert a value `val` interpreted as `value_type` from one unit system to
another. The unit systems are specified by the keyword arguments `from` and
`to`.

# Arguments
- `val`: The value to convert. Can be a scalar or an array. The function will
  copy the array and return a new array with the converted values.
- `value_type`: The type of value being converted. This can be a symbol or
  string that indicates what the unit is interpreted as (e.g. `:pressure` or
  `:permeability`). See the notes for all possible units.
- `from`: The unit system to convert from. See the notes for the list of
  possible unit systems.
- `to`: The unit system to convert to. See the notes for the list of possible
  unit systems. Defaults to `:si`.

Valid unit systems are `:si`, `:metric`, `:field`, and `:lab`. The
function returns the converted value in the target unit system.

# Notes
This function also supports `AbstractString` in place of symbols for the
`value_type`, `from`, and `to` arguments. For example, you can use
`"permeability"` instead of `:permeability`, or `"si"` instead of `:si`.

The function has both a keyword argument version `(val, value_type, from = :si,
to = :field)` and a positional argument version `(val, value_type, :si,
:kelvin)`. The keyword argument version is more explicit, but is a bit more
verbose.

## Possible value types

- `:length`: Length and depth measurements.
- `:area`: Area, typically length squared.
- `:time`: Unit of time.
- `:density`: Mass density, typically mass per unit volume.
- `:pressure`: Pressure, typically force per unit area.
- `:mol`: How moles are specified for amounts of species. Some unit systems use
  kilomoles, others use moles directly. The name is a bit misleading, but it is
  used to convert between the different types of molar representation.
- `:mass`
- `:u_rs`: Unit of surface volume per reservoir volume (used in rs calculations for dissolved gas).
- `:u_rv`: Unit of reservoir volume per surface volume (used in rv calculations for vaporized oil).
- `:concentration`: Mass concentration, typically mass per unit volume.
- `:compressibility`: Compressibility factors, typically in units of reciprocal pressure.
- `:viscosity`: Viscosity (centipoise in all unit systems except SI, which is Pa*s).
- `:surface_tension`: Surface tension used for compositional effects.
- `:jsurface_tension`: Surface tension used for surfacant effects.
- `:permeability`: Permeability, typically in millidarcies for all systems except SI.
- `:liquid_volume_surface`: Liquid volume at surface conditions.
- `:liquid_volume_reservoir`: Liquid volume at reservoir conditions.
- `:liquid_formation_volume_factor`: Ratio of liquid volume at reservoir
  conditions to liquid volume at surface conditions.
- `:gas_volume_surface`: Gas volume at surface conditions.
- `:gas_volume_reservoir`: Gas volume at reservoir conditions.
- `:gas_formation_volume_factor`: Ratio of gas volume at reservoir conditions to
  gas volume at surface conditions.
- `:volume`: Volume, typically length cubed.
- `:transmissibility`: Transmissibility and well connection factors.
- `:rock_conductivity`: Thermal conductivity of the rock.
- `:volume_heat_capacity`: Heat capacity per unit volume of the rock.
- `:mass_heat_capacity`: Heat capacity per unit mass of the rock.
- `:molar_mass`: Molar mass of a species.
- `:absolute_temperature_numeric`: The numeric value of absolute temperature in the unit system (Kelvin for SI, Rankine for field, etc.).
- `:Kh`: Permeability times length.
- `:time_over_volume`: Time divided by volume, used for certain rate calculations.
- `:liquid_rate_surface`: Liquid production rate at surface conditions.
- `:gas_rate_surface`: Gas production rate at surface conditions.
- `:liquid_rate_reservoir`: Liquid production rate at reservoir conditions.
- `:gas_rate_reservoir`: Gas production rate at reservoir conditions.
- `:critical_volume`: Critical volume, typically volume per some definition of .
- `:thermal_expansion_c1`: Thermal expansion coefficient of the first order, typically 1/temperature.
- `:thermal_expansion_c2`: Thermal expansion coefficient of the second order, typically 1/temperature^2.
- `:aquifer_transmissibility`: Transmissibility of an aquifer, typically
  transmissibility unit divided by viscosity unit.

# Examples
```jldoctest
# Convert 273.15 degrees Kelvin (freezing point of water) to field units (491.67 degrees Rankine)
convert_between_unit_systems(273.15, :absolute_temperature, from = :si, to = :field)

# output
491.66999999999996

```
```jldoctest
# Convert 100000 Pa to metric units (1.0 bar)
convert_between_unit_systems(1e5, "pressure", from = "si", to = "metric")

# output
1.0
```
"""
function convert_between_unit_systems

end

function convert_between_unit_systems(val, value_type::Union{Symbol, AbstractString}; from, to = :si)
    value_type = Symbol(value_type)
    systems = (from = DeckUnitSystem(from), to = DeckUnitSystem(to))
    return swap_unit_system(val, systems, value_type)
end

function convert_between_unit_systems(val, value_type, from, to)
    return convert_between_unit_systems(val, value_type; from = from, to = to)
end
