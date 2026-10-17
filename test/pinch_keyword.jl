using Test, GeoEnergyIO, Jutul

@testset "PINCH requires the keyword" begin
    xy = [0.0,100.0]
    depths = [fill(z,2,2) for z in (1000.0,1010.0,1010.0005,1020.0005)]
    for present in (false,true), enabled in (false,true)
        grid = cpgrid_from_horizons(xy,xy,depths)
        grid["PORO"] = fill(0.2,3)
        grid["MINPV"] = 500.0
        present && (grid["PINCH"] = [0.001,"GAP",Inf,"TOPBOT","TOP"])
        mesh = mesh_from_grid_section(grid;process_pinch=enabled)
        @test number_of_cells(mesh) == 2
        @test number_of_faces(mesh) == Int(present && enabled)
    end
end
