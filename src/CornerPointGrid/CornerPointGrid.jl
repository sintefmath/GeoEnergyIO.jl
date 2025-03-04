module CornerPointGrid
    import Jutul: UnstructuredMesh, CartesianMesh
    import Jutul: Cells, Faces, BoundaryFaces
    import Jutul: number_of_cells, number_of_faces, number_of_boundary_faces
    import Jutul: cell_ijk
    import Jutul: set_mesh_entity_tag!
    import Jutul: mesh_entity_has_tag
    import Jutul: LinearInterpolant, get_1d_interpolator
    import Jutul: BilinearInterpolant, get_2d_interpolator
    import Jutul: extract_submesh
    import Jutul: cell_index
    import Jutul: jutul_message
    import StaticArrays: SVector
    import LinearAlgebra: cross, dot, norm
    export mesh_from_grid_section
    include("interface.jl")
    include("processing.jl")
    include("processing_utils.jl")
    include("faults.jl")
    include("nnc_and_aquifers.jl")
    include("utils.jl")
    include("pinch.jl")
    include("generation.jl")
end
