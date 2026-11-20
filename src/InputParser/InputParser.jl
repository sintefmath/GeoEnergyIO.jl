module InputParser
    using Parsers, DelimitedFiles, Jutul, OrderedCollections, Dates, LinearAlgebra
    export parse_data_file
    @enum PARSER_WARNING PARSER_MISSING_SUPPORT PARSER_JUTULDARCY_MISSING_SUPPORT PARSER_JUTULDARCY_PARTIAL_SUPPORT PARSER_PARTIAL_SUPPORT
    const KEYWORD_SKIP_LIST = Tuple{Symbol, Union{Float64, Int}, Union{PARSER_WARNING, Nothing}}[]

    include("parser.jl")
    include("units.jl")
    include("utils.jl")
    include("keywords/keywords.jl")
end
