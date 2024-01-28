using GeoEnergyIO
using Test

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

end
##
test_dir = joinpath(pathof(GeoEnergyIO), "..", "..", "test", "data")
deck_dir = joinpath(test_dir, "decks", "opm-tests")
spe1_pth = joinpath(deck_dir, "spe1", "SPE1CASE2.DATA")
spe1 = parse_data_file(spe1_pth)
@test haskey(spe1["RUNSPEC"], "DISGAS")
@test !haskey(spe1["RUNSPEC"], "VAPOIL")
@test haskey(spe1["RUNSPEC"], "OIL")
@test haskey(spe1["RUNSPEC"], "WATER")
@test haskey(spe1["RUNSPEC"], "GAS")
@test spe1["PROPS"]["PVTW"][1] == [2.7700032163168546e7, 1.038, 4.670215154912738e-10, 0.00031800000000000003, 0.0]


##
spe3_pth = joinpath(deck_dir, "spe3", "SPE3CASE1.DATA")
spe3 = parse_data_file(spe3_pth)
@test haskey(spe3["RUNSPEC"], "DISGAS")
@test haskey(spe3["RUNSPEC"], "VAPOIL")
@test haskey(spe3["RUNSPEC"], "OIL")
@test haskey(spe3["RUNSPEC"], "WATER")
@test haskey(spe3["RUNSPEC"], "GAS")


##
@testset "SPE9" begin
    spe9_pth = joinpath(deck_dir, "spe9", "SPE9_CP.DATA")
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
end

##

