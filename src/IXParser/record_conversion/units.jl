
function conversion_ix_dict()
    u = Dict{String, Symbol}()

    # WellDef
    u["WellBoreRadius"] = :length
    u["Transmissibility"] = :transmissibility

    for k in [
        "Cell",
        "Completion",
        "PenetrationDirection",
        "PiMultiplier",
        "Status",
        "RockRegionName",
        "SegmentNode",
        "RelPerm",
        "WaterRelPermFunction",
        "Saturation",
    ]
        u[k] = :id
    end
    # TODO: Check.
    u["Skin"] = :id
    # PVT
    u["Viscosity"] = :viscosity
    for k in ["Pressure", "BubblePointPressure", "RefPressure", "CapPressure"]
        u[k] = :pressure
    end

    for k in ["OilSurfaceDensity", "GasSurfaceDensity", "WaterSurfaceDensity", "SurfaceDensity"]
        u[k] = :density
    end

    for k in ["Compressibility", "ViscosityCompressibility", "PoreVolCompressibility"]
        u[k] = :compressibility
    end
    u["ConstantSolutionGOR"] = :u_rs

    return u
end
