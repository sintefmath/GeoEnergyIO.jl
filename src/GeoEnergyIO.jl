module GeoEnergyIO
    export parse_data_file, parse_grdecl_file

    include("InputParser/InputParser.jl")
    import .InputParser: parse_data_file, parse_grdecl_file
end
