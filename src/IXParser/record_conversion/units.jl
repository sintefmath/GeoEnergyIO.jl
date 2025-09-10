
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
    u["ConstantSolutionGOR"] = :u_rs

    return u
end
