# Industry standard format header unit codes.
const UNIT_LABELS = Dict(1 => :metric, 2 => :field, 3 => :lab, 4 => :pvt_m)
function unit_code(units)
    label = Symbol(lowercase(string(units)))
    for (code, name) in UNIT_LABELS
        if label == name && label != :pvt_m
            return code
        end
    end
    throw(ArgumentError("Unsupported industry standard format output unit system $units; use :metric, :field or :lab"))
end

function file_units(file)
    if haskey(file, "INTEHEAD")
        h = file["INTEHEAD"]
        if length(h) >= 3
            return get(UNIT_LABELS, Int(h[3]), :unknown)
        end
    end
    return :metric
end

function unit_system(label)
    label = Symbol(lowercase(string(label)))
    label == :pvt_m && throw(ArgumentError("PVT-M unit conversion is not supported; use native arrays from read_binary"))
    return DeckUnitSystem(label)
end

const ARRAY_UNITS = Dict(
    "PRESSURE" => :pressure, "PBUB" => :pressure, "PDEW" => :pressure,
    "DEPTH" => :length, "DX" => :length, "DY" => :length, "DZ" => :length,
    "PERMX" => :permeability, "PERMY" => :permeability, "PERMZ" => :permeability,
    "PORV" => :liquid_volume_reservoir, "TRANX" => :transmissibility, "TRANY" => :transmissibility,
    "TRANZ" => :transmissibility, "TRANNNC" => :transmissibility,
    "RS" => :u_rs, "RV" => :u_rv, "DENO" => :density, "DENW" => :density,
    "DENG" => :density, "VISO" => :viscosity, "VISW" => :viscosity, "VISG" => :viscosity
)
function convert_array(name, vals, units; to_si)
    if name in ("TEMP", "TEMPI")
        if units == :field
            offset = ifelse(to_si, 32, 273.15)
            scale = ifelse(to_si, 5/9, 9/5)
            shift = ifelse(to_si, 273.15, 32)
            return @. (vals - offset)*scale + shift
        end
        return vals .+ ifelse(to_si, 273.15, -273.15)
    end
    kind = get(ARRAY_UNITS, name, nothing)
    if isnothing(kind)
        return copy(vals)
    end
    factor = getproperty(unit_system(units), kind)
    return vals .* ifelse(to_si, factor, inv(factor))
end
