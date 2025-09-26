module GeoEnergyIO
    using Artifacts
    using LazyArtifacts
    export parse_data_file
    export parse_grdecl_file
    export mesh_from_grid_section
    export cpgrid_from_horizons
    export get_data_file_cell_region
    export number_of_tables

    include("types.jl")

    include("InputParser/InputParser.jl")
    import .InputParser: parse_data_file, parse_grdecl_file, get_data_file_cell_region, number_of_tables

    include("CornerPointGrid/CornerPointGrid.jl")
    import .CornerPointGrid: mesh_from_grid_section, cpgrid_from_horizons

    include("RESQML/RESQML.jl")
    include("IXParser/IXParser.jl")

    import Jutul: JutulCase, UnstructuredMesh, DataDomain, physical_representation
    export read_restart, read_init, read_egrid, read_summary
    include("ext.jl")

    function test_input_file_path(dataset::AbstractString, filename = missing)
        pth = @artifact_str(dataset)
        if !ismissing(filename)
            pth = joinpath(pth, filename)
        end
        return pth
    end

    using PrecompileTools
    @compile_workload begin
        try
            spe1_pth = test_input_file_path("SPE1", "SPE1.DATA")
            spe1 = parse_data_file(spe1_pth)
            mesh_from_grid_section(spe1)
            spe9_pth = test_input_file_path("SPE9", "SPE9.DATA")
            spe9 = parse_data_file(spe9_pth)
            mesh_from_grid_section(spe9)
            pth = test_input_file_path("grdecl", "raised_col_sloped.txt")
            grdecl = parse_grdecl_file(pth)
            mesh_from_grid_section(grdecl)
        catch e
            @warn "Precompilation failed with exception $e"
        end
        nothing
    end
end
