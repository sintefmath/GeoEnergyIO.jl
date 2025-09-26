module IXParser
    import Lerche
    import Lerche: @inline_rule, @rule, Transformer
    import HDF5
    import ZipArchives
    import XML: children, Node, tag, attributes, value
    import OrderedCollections: OrderedDict
    import DelimitedFiles: readdlm
    import Dates: DateTime
    import Jutul: si_unit
    import GeoEnergyIO.RESQML: convert_to_grid_section
    import GeoEnergyIO: AbstractInputFile
    using GeoEnergyIO

    # Well completion flags
    @enum IX_WELLSTATUS IX_OPEN IX_CLOSED IX_HEAT
    # IJK indices
    @enum IX_IJK IX_I IX_J IX_K

    include("types.jl")
    include("grammar.jl")
    include("parser.jl")
    include("conversion.jl")
    include("resqml.jl")
    include("utils.jl")
end
