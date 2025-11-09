
function conversion_ix_dict()
    u = Dict{String, Symbol}()

    for k in [
            "Transmissibility",
            "TRANSMISSIBILITY_I",
            "TRANSMISSIBILITY_J",
            "TRANSMISSIBILITY_K"
        ]
        u[k] = :transmissibility
    end

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
            "Exponent",
            "Name",
            "HonorInjectionStreamAvailability",
            "UseDefaultBHP",
            "POROSITY",
            "NET_TO_GROSS_RATIO",
            "PORE_VOLUME_MULTIPLIER",
            "Cell1",
            "Cell2",
            "ComponentName"
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
            "INJECTION_TUBING_HEAD_PRESSURE",
            "BHP"
        ]
        u[k] = :pressure
    end

    for k in ["PORE_VOLUME"]
        u[k] = :volume
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
            "PermeabilityThickness",
            "BottomHoleRefDepth",
            "MeasuredDepth",
            "TrueVerticalDepth",
            "WellBoreRadius",
            "CELL_BOTTOM_DEPTH",
            "CELL_TOP_DEPTH",
            "CELL_CENTER_DEPTH"
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

    for k in ["PERM_I", "PERM_J", "PERM_K", "PERM_X", "PERM_Y", "PERM_Z"]
        u[k] = :permeability
    end

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
    for k in ["MolecularWeight"]
        u[k] = :molar_mass
    end
    return u
end
