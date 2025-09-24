
function conversion_ix_dict()
    u = Dict{String, Symbol}()

    # WellDef
    u["WellBoreRadius"] = :length
    u["Transmissibility"] = :transmissibility

    for k in [
        "Cell",
        "SubTableIndex",
        "DataType",
        "Completion",
        "PenetrationDirection",
        "PiMultiplier",
        "Status",
        "RockRegionName",
        "SegmentNode",
        "RelPerm",
        "WaterRelPermFunction",
        "NumberOfPressureDepthTableNodes",
        "Saturation",
        "TargetFractionToDestination",
        "Destination",
        "StageOutlet",
        "MaximumSaturation",
        "EndPointRelPerm",
        "ConnateSaturation",
        "RelPermAtAssociatedCriticalSaturation",
        "ResidualSaturation",
        "Exponent"
    ]
        u[k] = :id
    end
    # TODO: Check.
    u["Skin"] = :id
    # PVT
    u["Viscosity"] = :viscosity
    for k in [
        "Pressure",
        "BubblePointPressure",
        "RefPressure",
        "CapPressure",
        "WOCCapPressure",
        "GOCCapPressure",
        "DatumPressure",
        "BOTTOM_HOLE_PRESSURE",
        "BHP"
    ]
        u[k] = :pressure
    end

    for k in ["OilSurfaceDensity", "GasSurfaceDensity", "WaterSurfaceDensity", "SurfaceDensity"]
        u[k] = :density
    end

    for k in ["Compressibility", "ViscosityCompressibility", "PoreVolCompressibility"]
        u[k] = :compressibility
    end
    for k in [
            "DatumDepth",
            "WOCDepth",
            "GOCDepth",
            "Depth",
            "PressureEquivalentRadius",
            "PermeabilityThickness"
        ]
        u[k] = :length
    end
    for k in ["Temperature"]
        # TODO: Check if there are Kelvin/Rankine instances marked as just
        # "Temperature".
        u[k] = :relative_temperature
    end
    u["ConstantSolutionGOR"] = :u_rs
    u["SolutionGOR"] = :u_rs

    for k in [
        "OIL_PRODUCTION_RATE",
        "WATER_PRODUCTION_RATE",
        "LIQUID_PRODUCTION_RATE",
        "WATER_INJECTION_RATE"
    ]
        u[k] = :liquid_rate_surface
    end
    for k in ["GAS_PRODUCTION_RATE", "GAS_INJECTION_RATE"]
        u[k] = :gas_rate_surface
    end
    return u
end
