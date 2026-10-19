using Test, GeoEnergyIO, Jutul
import GeoEnergyIO.CornerPointGrid as CPG

@testset "Corner indexing and cell volumes" begin
    dims = (3, 2, 2)
    z = reshape(1:8prod(dims), (2 .* dims)...)
    for k in 1:dims[3], j in 1:dims[2], i in 1:dims[1], dk in 0:1, dj in 0:1, di in 0:1
        expected = z[2i-1+di, 2j-1+dj, 2k-1+dk]
        cell = CPG.ijk_to_linear(i, j, k, dims)
        @test CPG.get_corner_index(cell, (di,dj,dk), dims) == expected
        @test CPG.get_corner_index((i,j,k), (di,dj,dk), dims) == expected
    end
    @test_deprecated CPG.corner_index(1, (0,1,0), dims)
    @test CPG.corner_index(1, (0,1,0), dims) == CPG.get_corner_index(1, (1,0,0), dims)

    # Different slopes in i and j catch paired transpositions in generation.
    x, y = [0.0,100.0,200.0], [0.0,100.0]
    top = [1000 + 0.5xi + 0.1yj for xi in x, yj in y]
    grid = cpgrid_from_horizons(x, y, [top, top .+ 10])
    p = CPG.cell_corners(grid, (1,1,1))
    @test p[2][3] - p[1][3] ≈ 50
    @test p[3][3] - p[1][3] ≈ 10
    @test CPG.cell_volume(p) ≈ 100000
    coincident = deepcopy(grid)
    coord = reshape(coincident["COORD"],6,:)
    coord[4:6,:] .= coord[1:3,:]
    @test CPG.cell_corners(coincident,1) ≈ CPG.cell_corners(grid,1)
    grid["PORO"] = fill(0.0048, 2)
    grid["MINPV"] = 500.0
    @test !any(first(CPG.get_effective_actnum(grid)))
    grid["PORO"] .= 0.0052
    @test all(first(CPG.get_effective_actnum(grid)))
    grid["PORV"] = [480.0,520.0]
    @test vec(first(CPG.get_effective_actnum(grid))) == [false,true]

    # A trilinear map with analytic determinant 1 + 0.6w + 0.8uv.
    p = [Jutul.StaticArrays.SVector(u*(1+0.6w), v, w*(1+0.8u*v))
        for w in 0:1 for v in 0:1 for u in 0:1]
    @test CPG.cell_volume(p) ≈ 1 + 0.6/2 + 0.8/4
    @test CPG.cell_volume([q .+ 1e5 for q in p]) ≈ 1.5
end
