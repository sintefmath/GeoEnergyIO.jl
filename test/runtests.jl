using GeoEnergyIO
using Test

import GeoEnergyIO: test_input_file_path
import Jutul: number_of_cells, number_of_boundary_faces, number_of_faces, convert_from_si

@testset "GeoEnergyIO.jl" begin
    import GeoEnergyIO.InputParser: clean_include_path, parse_defaulted_line
    import GeoEnergyIO.InputParser: parse_defaulted_group_well
    @testset "InputParser" begin
        @test clean_include_path("", " MYFILE") == "MYFILE"
        @test clean_include_path("/some/path", " MYFILE") == joinpath("/some/path", "MYFILE")
        @test clean_include_path("/some/path", " 'MYFILE'") == joinpath("/some/path", "MYFILE")
        @test clean_include_path("/some/path", " ./MYFILE") == joinpath("/some/path", "MYFILE")
        @test clean_include_path("/some/path", " './MYFILE'") == joinpath("/some/path", "MYFILE")
        @test clean_include_path("/some/path", " 'file.txt' /  (Some comment)") == joinpath("/some/path", "file.txt")
        @test clean_include_path("/some/path", " 'file.txt'/(Some comment)") == joinpath("/some/path", "file.txt")

        @test parse_defaulted_line("3.0 2* 7", [1.0, 2, 3, 4]) == [3.0, 2, 3, 7]
        @test parse_defaulted_line("2.0", [1.0, 2, 3, 4]) == [2.0, 2, 3, 4]
        @test parse_defaulted_line("5 *", [1, 2]) == [5, 2]
        @test parse_defaulted_line("5  2*", [1, 2, 3]) == [5, 2, 3]
        @test parse_defaulted_line("5, 2", [1, 2]) == [5, 2]
        @test parse_defaulted_line("5   HEI", [1, "Hallo"]) == [5, "HEI"]
        @test parse_defaulted_line("2*", [1, "Hallo"]) == [1, "Hallo"]

        @testset "well_parsing" begin
            wells = Dict("WELLA" => 3, "WELLB" => 4)
            d = ["WELLNAME", 1]
            f = IOBuffer("WELLA 5 /\n");
            @test only(parse_defaulted_group_well(f, d, wells)) == ["WELLA", 5]
            f = IOBuffer("WELLB /\n");
            @test only(parse_defaulted_group_well(f, d, wells)) == ["WELLB", 1]
            f = IOBuffer("WELL* 10 /\n")
            parsed = parse_defaulted_group_well(f, d, wells)
            @test length(parsed) == 2
            @test parsed[1] == ["WELLA", 10]
            @test parsed[2] == ["WELLB", 10]
            f = IOBuffer("'4WELL_A' 10 /\n")
            parsed = parse_defaulted_group_well(f, d, wells)
            @test only(parsed) == ["4WELL_A", 10]
        end
    end
    @testset "SPE1" begin
        spe1_pth = test_input_file_path("SPE1", "SPE1.DATA")
        spe1 = parse_data_file(spe1_pth)
        @testset "RUNSPEC" begin
            rs = spe1["RUNSPEC"]
            @test haskey(rs, "DISGAS")
            @test !haskey(rs, "VAPOIL")
            @test haskey(rs, "OIL")
            @test haskey(rs, "WATER")
            @test haskey(rs, "GAS")
        end
        @test spe1["PROPS"]["PVTW"][1] ≈ [2.7700032163168546e7, 1.038, 4.670215154912738e-10, 0.00031800000000000003, 0.0]
        g = mesh_from_grid_section(spe1)
        @test number_of_cells(g) == 300
        @test number_of_faces(g) == 740
        @test number_of_boundary_faces(g) == 320
    end
    @testset "SPE9" begin
        spe9_pth = test_input_file_path("SPE9", "SPE9.DATA")
        spe9 = parse_data_file(spe9_pth)
        @testset "RUNSPEC" begin
            rs = spe9["RUNSPEC"]
            @test haskey(rs, "DISGAS")
            @test !haskey(rs, "VAPOIL")
            @test haskey(rs, "OIL")
            @test haskey(rs, "WATER")
            @test haskey(rs, "GAS")
            @test rs["TITLE"] == "SPE 9"
            @test rs["DIMENS"] == [24, 25, 15]
        end
        g = mesh_from_grid_section(spe9)
        @test number_of_cells(g) == 9000
        @test number_of_faces(g) == 25665
        @test number_of_boundary_faces(g) == 2670
    end
    @testset "Basic GRDECL parsing" begin
        pth = test_input_file_path("grdecl", "1cell.txt")
        grdecl = parse_grdecl_file(pth)
        @test grdecl["SPECGRID"] == [1, 1, 1, 1, "F"]
        @test grdecl["cartDims"] == (1, 1, 1)
        @test grdecl["ZCORN"] == [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0]
        @test sum(grdecl["COORD"]) == 12.0
        @test only(grdecl["ACTNUM"]) == true
    end

    grdecl_cases = [
        (name="1_1_node_pinch.txt", nf=2, nc=3, bnf=14)
        (name="2_1_node_pinch.txt", nf=2, nc=3, bnf=13)
        (name="3_1_node_pinch.txt", nf=2, nc=3, bnf=12)
        (name="model3_5_5_5.txt", nf=189, nc=70, bnf=131)
        (name="1_2_node_pinch.txt", nf=2, nc=3, bnf=14)
        (name="2_2_node_pinch.txt", nf=2, nc=3, bnf=13)
        (name="3_2_node_pinch.txt", nf=2, nc=3, bnf=12)
        (name="model3_abc.txt", nf=15, nc=10, bnf=38)
        (name="1_3_node_pinch.txt", nf=2, nc=3, bnf=14)
        (name="2_3_node_pinch.txt", nf=2, nc=3, bnf=14)
        (name="3_3_node_pinch.txt", nf=2, nc=3, bnf=12)
        (name="pinched_layers_5_5_5.txt", nf=134, nc=64, bnf=128)
        (name="1_4_node_pinch.txt", nf=2, nc=3, bnf=14)
        (name="2_4_node_pinch.txt", nf=2, nc=3, bnf=14)
        (name="3_4_node_pinch.txt", nf=2, nc=3, bnf=12)
        (name="raised_col_sloped.txt", nf=5, nc=4, bnf=18)
        (name="1cell.txt", nf=0, nc=1, bnf=6)
        (name="2_5_node_pinch.txt", nf=2, nc=3, bnf=13)
        (name="4_1_node_pinch.txt", nf=2, nc=3, bnf=10)
        (name="raised_col.txt", nf=5, nc=4, bnf=17)
        (name="1col.txt", nf=2, nc=3, bnf=14)
        (name="2_6_node_pinch.txt", nf=2, nc=3, bnf=13)
        (name="sloped.txt", nf=14, nc=8, bnf=28)
        (name="2col.txt", nf=7, nc=6, bnf=22)
        (name="model3_20_20_50.txt", nf=43743, nc=15250, bnf=4890)
    ]
    for (name, nf_ref, nc_ref, nbf_ref) in grdecl_cases
        @testset "$name" begin
            pth = test_input_file_path("grdecl", name)
            grdecl = parse_grdecl_file(pth)
            g = mesh_from_grid_section(grdecl)
            nc = number_of_cells(g)
            nf = number_of_faces(g)
            nbf = number_of_boundary_faces(g)
            @test nc == nc_ref
            @test nbf == nbf_ref
            @test nf == nf_ref
        end
    end
    import GeoEnergyIO.CornerPointGrid: determine_cell_overlap_inside_line
    @testset "corner point pillar point overlap" begin
        for start in -10:25
            for increment in 1:25
                top = start
                mid = start + increment
                bottom = mid + increment
                far = bottom + increment
                # A_CONTAINS_B and B_CONTAINS_A
                # A B
                # | |   |
                # | | = |
                # | |   |
                @test determine_cell_overlap_inside_line(top, bottom, top, bottom) == (GeoEnergyIO.CornerPointGrid.AB_RANGES_MATCH, top:bottom, top:bottom, top:bottom)
                # AB_OVERLAP_A_FIRST and AB_OVERLAP_B_FIRST
                # A B
                #   |   x
                # | | = |
                # | |   x
                @test determine_cell_overlap_inside_line(mid, bottom, top, mid) == (GeoEnergyIO.CornerPointGrid.AB_OVERLAP_B_FIRST, mid:mid, mid:bottom, top:mid)
                # Reversed case.
                @test determine_cell_overlap_inside_line(top, mid, mid, bottom) == (GeoEnergyIO.CornerPointGrid.AB_OVERLAP_A_FIRST, mid:mid, top:mid, mid:bottom)
                # TOP_MATCHES_A_LONG and TOP_MATCHES_B_LONG
                # A B
                # | |   |
                # | | = |
                # |     x
                @test determine_cell_overlap_inside_line(top, bottom, top, mid) == (GeoEnergyIO.CornerPointGrid.TOP_MATCHES_A_LONG, top:mid, top:bottom, top:mid)
                # Reversed case.
                @test determine_cell_overlap_inside_line(top, mid, top, bottom) == (GeoEnergyIO.CornerPointGrid.TOP_MATCHES_B_LONG, top:mid, top:mid, top:bottom)
                # BOTTOM_MATCHES_A_LONG and BOTTOM_MATCHES_B_LONG
                # A B
                # | x   x
                # | | = |
                # | |   |
                @test determine_cell_overlap_inside_line(top, bottom, mid, bottom) == (GeoEnergyIO.CornerPointGrid.BOTTOM_MATCHES_A_LONG, mid:bottom, top:bottom, mid:bottom)
                # Reversed case.
                @test determine_cell_overlap_inside_line(mid, bottom, top, bottom) == (GeoEnergyIO.CornerPointGrid.BOTTOM_MATCHES_B_LONG, mid:bottom, mid:bottom, top:bottom)
                # DISTINCT_A_ABOVE and DISTINCT_B_ABOVE
                # A B
                # |     x
                # |     x
                #   | = x
                #   |   x
                @test determine_cell_overlap_inside_line(top, mid, bottom, far) == (GeoEnergyIO.CornerPointGrid.DISTINCT_A_ABOVE, 0:-1, top:mid, bottom:far)
                # Reversed case.
                @test determine_cell_overlap_inside_line(bottom, far, top, mid) == (GeoEnergyIO.CornerPointGrid.DISTINCT_B_ABOVE, 0:-1, bottom:far, top:mid)
            end
        end
    end
    @testset "defaults_for_unit" begin
        import GeoEnergyIO.InputParser: defaults_for_unit
        ft = convert_from_si(1.0, :feet)
        @test defaults_for_unit(:si, (:length, :volume), si = [1.0, 2.0]) ≈ [1.0, 2.0]
        @test defaults_for_unit(:field, (:length, :volume), si = [1.0, 2.0]) ≈ [ft, 2.0*ft^3]
        @test defaults_for_unit(:field, (:length, :volume), si = [1.0, 2.0], field = [200.0, 500.0]) ≈ [200.0, 500.0]
    end

    @testset "find_next_gap" begin
        for (interval, start, ref) in [
                ([1, 2, 3, 0, 0, 1], 1, (3, 5, false)),
                ([0, 0, 1, 2, 3, 0, 0, 1], 1, (5, 7, false)),
                ([0, 0, 1, 2, 3, 0, 0, 1], 4, (5, 7, false)),
                ([1, 0, 0], 1,  (3, 3, true)),
            ]
            v = GeoEnergyIO.CornerPointGrid.find_next_gap(interval, start)
            @test v == ref
            interval = interval[(ref[1]+1):ref[2]]
            @test all(iszero, interval)
        end
        ##
        @test GeoEnergyIO.CornerPointGrid.find_next_gap([1, 2, 3, 0, 0, 1], 1) == (3, 5, false)
        @test GeoEnergyIO.CornerPointGrid.find_next_gap([0, 0, 1, 2, 3, 0, 0, 1], 1) == (5, 7, false)
        @test GeoEnergyIO.CornerPointGrid.find_next_gap([0, 0, 1, 2, 3, 0, 0, 1], 4) == (5, 7, false)
        @test GeoEnergyIO.CornerPointGrid.find_next_gap([1, 0, 0], 1) == (3, 3, true)
    end

    @testset "cpgrid_generation" begin
        nx = 10
        ny = 5
        l1 = 3
        l2 = 2
        xrng = range(0.0, 1.0, nx)
        yrng = range(0.0, 1.0, ny)
        depths = [
            zeros(nx, ny),
            zeros(nx, ny) .+ 5.0,
            zeros(nx, ny) .+ 10.0
        ]
        # Check base case
        gs = cpgrid_from_horizons(xrng, yrng, depths, layer_width = [l1, l2])
        m = mesh_from_grid_section(gs)
        @test number_of_cells(m) == (nx-1)*(ny-1)*(l1 + l2)
        # Check interpolation to finer mesh
        Nx = 30
        Ny = 40
        gs = cpgrid_from_horizons(xrng, yrng, depths, (Nx, Ny), layer_width = [l1, l2])
        m = mesh_from_grid_section(gs)
        @test number_of_cells(m) == (Nx-1)*(Ny-1)*(l1 + l2)
        # Check NaN in single layer
        depths[1][1, 1] = NaN
        gs = cpgrid_from_horizons(xrng, yrng, depths, layer_width = [l1, l2])
        m = mesh_from_grid_section(gs)
        @test number_of_cells(m) == (nx-1)*(ny-1)*(l1 + l2) - l1
        # Check NaN in multiple layers
        depths[2][1, 1] = NaN
        depths[3][1, 1] = NaN
        gs = cpgrid_from_horizons(xrng, yrng, depths, layer_width = [l1, l2])
        m = mesh_from_grid_section(gs)
        @test number_of_cells(m) == (nx-1)*(ny-1)*(l1 + l2) - l1 - l2
    end
end
