module IXParser
    import Lerche
    import Lerche: @inline_rule, @rule, Transformer
    import HDF5
    import ZipArchives
    import XML
    import OrderedCollections: OrderedDict

    """
    Well completion flags
    """
    @enum IX_WELLSTATUS IX_OPEN IX_CLOSED IX_HEAT
    @enum IX_IJK IX_I IX_J IX_K

    include("types.jl")
    include("grammar.jl")
    include("parser.jl")
end
