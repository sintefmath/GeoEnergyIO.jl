module GeoEnergyIO
    export parse_data_file
    export parse_grdecl_file
    export mesh_from_grid_section

    include("InputParser/InputParser.jl")
    import .InputParser: parse_data_file, parse_grdecl_file

    include("CornerPointGrid/CornerPointGrid.jl")
    import .CornerPointGrid: mesh_from_grid_section
end
