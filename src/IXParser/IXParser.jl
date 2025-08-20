module IXParser
    import Lerche
    import Lerche: @inline_rule, @rule, Transformer
    import HDF5
    import ZipArchives
    import XML

    include("types.jl")
    include("grammar.jl")
    include("parser.jl")
end
