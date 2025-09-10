
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
    u["Pressure"] = :pressure
    u["BubblePointPressure"] = :pressure
    u["OilSurfaceDensity"] = :density
    u["GasSurfaceDensity"] = :density
    u["WaterSurfaceDensity"] = :density
    u["ConstantSolutionGOR"] = :u_rs

    return u
end
