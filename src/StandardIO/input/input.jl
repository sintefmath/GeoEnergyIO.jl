module input
    using Dates
    using ..StandardIO: KeywordFile, BinaryKeyword, read_binary,
        file_path, case_base, split_files, file_units, convert_array, summary_group
    include("grid.jl")
    include("restart.jl")
    include("summary.jl")
    export read_egrid, read_init, read_restart, read_summary
end
