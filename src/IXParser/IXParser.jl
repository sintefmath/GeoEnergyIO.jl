module IXParser
    import Lerche
    import Lerche: @inline_rule, @rule, Transformer
    import HDF5
    import ZipArchives
    import XML: children
    import OrderedCollections: OrderedDict
    import Dates: DateTime
    using GeoEnergyIO

    """
    Well completion flags
    """
    @enum IX_WELLSTATUS IX_OPEN IX_CLOSED IX_HEAT
    @enum IX_IJK IX_I IX_J IX_K

    include("types.jl")
    include("grammar.jl")
    include("parser.jl")
    include("conversion.jl")
    include("resqml.jl")
end
