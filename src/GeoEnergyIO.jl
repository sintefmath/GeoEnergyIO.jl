module GeoEnergyIO
    export parse_data_file
    export parse_grdecl_file
    export mesh_from_grid_section
    export get_data_file_cell_region
    export number_of_tables

    include("InputParser/InputParser.jl")
    import .InputParser: parse_data_file, parse_grdecl_file, get_data_file_cell_region, number_of_tables

    include("CornerPointGrid/CornerPointGrid.jl")
    import .CornerPointGrid: mesh_from_grid_section

    function test_input_file_path(folder, name = missing; base = "mrst")
        pth, = splitdir(pathof(GeoEnergyIO))
        test_dir = joinpath(pth, "..", "test", "data")
        if ismissing(base)
            input_file_dir = test_dir
        else
            input_file_dir = joinpath(test_dir, base)
        end
        if ismissing(name)
            out = joinpath(input_file_dir, folder)
        else
            out = joinpath(input_file_dir, folder, name)
        end
        return out
    end
end
