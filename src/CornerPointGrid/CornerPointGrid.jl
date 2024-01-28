module CornerPointGrid
    import Jutul: UnstructuredMesh
    import StaticArrays: SVector
    export mesh_from_grid_section
    include("interface.jl")
    include("processing.jl")
    include("processing_utils.jl")
    include("faults.jl")
    include("utils.jl")
    include("pinch.jl")
end
