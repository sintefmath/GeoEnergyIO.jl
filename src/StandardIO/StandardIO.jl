"""
Pure Julia readers and writers for unformatted industry standard format keyword files.

`input` and `output` provide the file-specific interfaces. `read_binary` and
`write_binary` also handle arbitrary keyword files (INIT, UNRST, RFT, etc.)
without discarding repeated keywords or unknown simulator-specific arrays.
"""
module StandardIO
    using Dates
    import ..InputParser: DeckUnitSystem
    include("binary.jl")
    include("units.jl")
    include("input/input.jl")
    include("output/output.jl")
    using .input: read_init, read_egrid, read_restart, read_summary
    using .output: write_init, write_egrid, write_restart, write_summary,
        write_jutuldarcy_summary, write_jutuldarcy_results
    export BinaryKeyword, KeywordFile, read_binary, write_binary, keyword_values
    export read_init, read_egrid, read_restart, read_summary
    export write_init, write_egrid, write_restart, write_summary
    export write_jutuldarcy_summary, write_jutuldarcy_results
end
