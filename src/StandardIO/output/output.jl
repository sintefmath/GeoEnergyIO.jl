module output
    using Dates
    using ..StandardIO: KeywordFile, BinaryKeyword, write_binary, write_keyword,
        output_path, case_base, unit_code, unit_system, convert_array
    import Jutul
    include("grid.jl")
    include("restart.jl")
    include("summary.jl")
    # Specialized methods for ReservoirSimResult live in the optional
    # JutulDarcy extension, avoiding a dependency cycle.
    function write_jutuldarcy_results end
    export write_egrid, write_init, write_restart, write_summary
    export write_jutuldarcy_summary, write_jutuldarcy_results
end
