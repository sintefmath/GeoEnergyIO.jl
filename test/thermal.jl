@testset "Thermal and passive tracer DATA keywords" begin
    path = joinpath(@__DIR__, "data", "thermal", "THERMAL_PARSER.DATA")
    data = parse_data_file(path, silent = true)
    raw = parse_data_file(path, units = nothing, silent = true)
    props = data["PROPS"]
    @test props["SPECROCK"][1][:, 2] ≈ [2.2e6, 2.3e6]
    @test props["SPECHEAT"][1][:, 3] ≈ [4000, 5000]
    @test props["WATVISCT"][1][:, 2] ≈ [1.2e-3, 0.4e-3]
    @test props["GASVISCT"][1][:, 2] ≈ [2e-5, 3e-5]
    @test vec(data["GRID"]["THCONR"]) ≈ [1, 1]
    @test vec(raw["GRID"]["THCONR"]) == [86.4, 86.4]
    @test data["RUNSPEC"]["TRACERS"][1:5] == [0, 1, 0, 0, "NODIFF"]
    @test only(props["TRACER"])[1:2] == ["INJ", "WAT"]
    @test vec(data["SOLUTION"]["TBLKFINJ"]) == [0.25, 0.5]
    @test data["SOLUTION"]["TVDPFINJ"] == [1000 0; 1100 1]
    step = first(data["SCHEDULE"]["STEPS"])
    @test only(step["WTRACER"])[1:3] == ["I", "INJ", 0.75]
    @test only(step["WTEMP"]) == ["I", 20.0]
    @test isnan(only(step["COMPDAT"])[8])
    @test GeoEnergyIO.InputParser.parse_defaulted_line("'I       ' 'G ' 3", ["", "", 0]) == ["I", "G", 3]
end
