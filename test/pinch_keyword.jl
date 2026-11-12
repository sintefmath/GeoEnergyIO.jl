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

@testset "PINCH sealing layers and gap limits" begin
    function pinch_grid(; thickness = 0.0005, mode = "TOPBOT", gap = "GAP", max_gap = Inf, permz = 1e-13, multz = 1.0)
        xy = [0.0, 100.0]
        depths = [fill(z, 2, 2) for z in (1000.0, 1010.0, 1010.0+thickness, 1020.0+thickness)]
        grid = cpgrid_from_horizons(xy, xy, depths)
        grid["PORO"] = [0.2, 0.01, 0.2]
        grid["MINPV"] = 500.0
        grid["PERMZ"] = [1e-13, permz, 1e-13]
        grid["MULTZ"] = [1.0, multz, 1.0]
        grid["PINCH"] = [0.001, gap, max_gap, mode, "TOP"]
        return grid
    end
    connected(; kw...) = number_of_faces(mesh_from_grid_section(pinch_grid(; kw...))) == 1
    @test connected(mode = "TOPBOT", permz = 0.0)
    @test !connected(mode = "ALL", permz = 0.0)
    @test !connected(mode = "ALL", multz = 0.0)
    @test connected(mode = "ALL")
    @test !connected(max_gap = 0.0001)
    @test connected(max_gap = 0.001)
    @test connected(thickness = 1.0, gap = "GAP")
    @test !connected(thickness = 1.0, gap = "NOGAP")
    @test !connected(thickness = 1.0, max_gap = 0.5)
    for field in ("PORO", "PORV")
        grid = pinch_grid(thickness = 1.0)
        grid[field] = field == "PORO" ? [0.2, 0.0, 0.2] : [20000.0, 0.0, 20000.0]
        @test number_of_faces(mesh_from_grid_section(grid)) == 0
    end
    grid = pinch_grid(thickness = 1.0)
    delete!(grid, "MINPV")
    grid["MINPVV"] = [1e-6, 500.0, 1e-6]
    @test number_of_faces(mesh_from_grid_section(grid)) == 1

    # NOGAP tests individual cells, not the thickness of the whole interval.
    depths = [fill(z, 2, 2) for z in (1000, 1010, 1010.0006, 1010.0012, 1020.0012)]
    grid = cpgrid_from_horizons([0.0, 100.0], [0.0, 100.0], depths)
    grid["PORO"] = [0.2, 0.0, 0.0, 0.2]
    grid["PINCH"] = [0.001, "NOGAP", Inf, "TOPBOT", "TOP"]
    @test number_of_faces(mesh_from_grid_section(grid)) == 1
    # An ACTNUM gap that is too thick remains a barrier even in GAP mode.
    grid = pinch_grid(thickness = 1.0)
    grid["ACTNUM"] = reshape([true, false, true], 1, 1, 3)
    @test number_of_faces(mesh_from_grid_section(grid)) == 0
end

@testset "PINCH length units" begin
    for units in ("METRIC", "FIELD")
        mktemp() do path, io
            write(io, "RUNSPEC\n$units\nGRID\nPINCH\n 0.1 GAP 2 ALL TOP /\nEND\n")
            close(io)
            data = parse_data_file(path; silent = true)
            length_unit = units == "FIELD" ? 0.3048 : 1.0
            @test data["GRID"]["PINCH"][1] ≈ 0.1*length_unit
            @test data["GRID"]["PINCH"][3] ≈ 2*length_unit
        end
    end
end
