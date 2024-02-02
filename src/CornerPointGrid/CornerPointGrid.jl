module CornerPointGrid
    import Jutul: UnstructuredMesh, CartesianMesh
    import Jutul: Cells, Faces, BoundaryFaces
    import Jutul: number_of_cells, number_of_faces, number_of_boundary_faces
    import Jutul: cell_ijk
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
