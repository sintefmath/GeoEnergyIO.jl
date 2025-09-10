
function conversion_ix_dict()
    u = Dict{String, Symbol}()

    # WellDef
    u["WellBoreRadius"] = :length
    u["Transmissibility"] = :transmissibility

    for k in [
        "Cell",
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
    ]
        u[k] = :pressure
    end

    for k in ["OilSurfaceDensity", "GasSurfaceDensity", "WaterSurfaceDensity", "SurfaceDensity"]
        u[k] = :density
    end

    for k in ["Compressibility", "ViscosityCompressibility", "PoreVolCompressibility"]
        u[k] = :compressibility
    end
    for k in ["DatumDepth", "WOCDepth", "GOCDepth", "Depth"]
        u[k] = :length
    end
    for k in ["Temperature"]
        # TODO: Check if there are Kelvin/Rankine instances marked as just
        # "Temperature".
        u[k] = :relative_temperature
    end
    u["ConstantSolutionGOR"] = :u_rs

    return u
end
