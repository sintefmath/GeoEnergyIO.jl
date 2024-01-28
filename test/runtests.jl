using GeoEnergyIO
using Test

import GeoEnergyIO: test_input_file_path
import Jutul: number_of_cells, number_of_boundary_faces, number_of_faces

@testset "GeoEnergyIO.jl" begin
    import GeoEnergyIO.InputParser: clean_include_path, parse_defaulted_line
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
    end
    @testset "SPE1" begin
        spe1_pth = test_input_file_path("spe1", "BENCH_SPE1.DATA")
        spe1 = parse_data_file(spe1_pth)
        @testset "RUNSPEC" begin
            rs = spe1["RUNSPEC"]
            @test haskey(rs, "DISGAS")
            @test !haskey(rs, "VAPOIL")
            @test haskey(rs, "OIL")
            @test haskey(rs, "WATER")
            @test haskey(rs, "GAS")
        end
        @test spe1["PROPS"]["PVTW"][1] == [2.768038210488301e7, 1.029, 4.539681190955549e-10, 0.00031, 0.0]
        g = mesh_from_grid_section(spe1)
        @test number_of_cells(g) == 300
        @test number_of_faces(g) == 740
        @test number_of_boundary_faces(g) == 320
    end
    @testset "SPE9" begin
        spe9_pth = test_input_file_path("spe9", "SPE9_CP.DATA", base = "opm-tests")
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
end
