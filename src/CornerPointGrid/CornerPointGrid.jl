module CornerPointGrid
    import Jutul: UnstructuredMesh, CartesianMesh
    import Jutul: Cells, Faces, BoundaryFaces
    import Jutul: set_mesh_entity_tag!
    import StaticArrays: SVector
    import LinearAlgebra: cross, dot, norm
    export mesh_from_grid_section
    include("interface.jl")
    include("processing.jl")
    include("processing_utils.jl")
    include("faults.jl")
    include("utils.jl")
    include("pinch.jl")
end
