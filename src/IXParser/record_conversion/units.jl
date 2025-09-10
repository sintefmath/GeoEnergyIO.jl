
function conversion_ix_dict()
    u = Dict{String, Symbol}()

    # WellDef
    u["WellBoreRadius"] = :length
    u["Transmissibility"] = :transmissibility
    u["Cell"] = :id
    u["Completion"] = :id
    u["PenetrationDirection"] = :id
    u["PiMultiplier"] = :id
    u["Status"] = :id
    u["RockRegionName"] = :id
    u["SegmentNode"] = :id
    u["Status"] = :id
    # TODO: Check.
    u["Skin"] = :id
    # PVT
    u["Viscosity"] = :viscosity
    for k in ["Pressure", "BubblePointPressure", "RefPressure"]
        u[k] = :pressure
    end

    for k in ["OilSurfaceDensity", "GasSurfaceDensity", "WaterSurfaceDensity", "SurfaceDensity"]
        u[k] = :density
    end

    u["Compressibility"] = :compressibility
    u["ViscosityCompressibility"] = :compressibility
    u["ConstantSolutionGOR"] = :u_rs

    return u
end
