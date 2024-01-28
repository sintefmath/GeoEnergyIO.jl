module GeoEnergyIO
    export parse_data_file
    export parse_grdecl_file
    export mesh_from_grid_section

    include("InputParser/InputParser.jl")
    import .InputParser: parse_data_file, parse_grdecl_file

    include("CornerPointGrid/CornerPointGrid.jl")
    import .CornerPointGrid: mesh_from_grid_section

    function test_input_file_path(folder, name = missing; base = "mrst")
        test_dir = joinpath(pathof(GeoEnergyIO), "..", "..", "test", "data")
        deck_dir = joinpath(test_dir, base)
        if ismissing(name)
            out = joinpath(deck_dir, folder)
        else
            out = joinpath(deck_dir, folder, name)
        end
        return out
    end
end
