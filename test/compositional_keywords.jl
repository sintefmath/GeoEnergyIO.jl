using GeoEnergyIO, Test

@testset "Compositional keyword records" begin
    deck = """
RUNSPEC
FIELD
COMPS
2 /
TABDIMS
8* 2 1 /
EQLDIMS
2 /
PROPS
OMEGAA
0.45 0.46 /
2* /
OMEGAB
0.07 0.08 /
0.08 0.09 /
SSHIFT
0.1 0.2 /
0.3 0.4 /
SSHIFTS
0.5 0.6 /
LBCCOEF
0.11 4* /
COMPVD
1000 0.2 0.8 0 1000
2000 0.7 0.3 1 2000 /
3000 0.4 0.6 0 3000 /
SCHEDULE
WELSPECS
I G 1 1 1000 GAS /
/
GINJGAS
FIELD STREAM INJ /
'G*' /
/
TSTEP
1 /
END
"""
    mktempdir() do dir
        path = joinpath(dir, "KEYWORDS.DATA")
        write(path, deck)
        data = parse_data_file(path; silent = true)
        props = data["PROPS"]
        @test props["OMEGAA"][1] == [0.45, 0.46]
        @test all(isnan, props["OMEGAA"][2])
        @test props["OMEGAB"] == [[0.07, 0.08], [0.08, 0.09]]
        @test props["SSHIFTS"] == [[0.5, 0.6]]
        @test props["LBCCOEF"] == [0.11, 0.023364, 0.058533, -0.040758, 0.0093324]
        @test length(props["COMPVD"]) == 2
        @test props["COMPVD"][1][:, 1] ≈ [304.8, 609.6]
        @test props["COMPVD"][1][:, end] ≈ [1000, 2000].*6894.757293168
        @test props["COMPVD"][1][:, end-1] == [0.0, 1.0]
        schedule = data["SCHEDULE"]
        @test schedule["WELSPECS"]["I"].group == "G"
        @test schedule["STEPS"][1]["WELSPECS"][1][2] == "G"
        @test schedule["STEPS"][1]["GINJGAS"][1] == ["FIELD", "STREAM", "INJ", "Default", 0]
        @test schedule["STEPS"][1]["GINJGAS"][2] == ["G*", "GRUP", "Default", "Default", 0]

        inherited = replace(deck, "8* 2 1 /" => "8* 2 /",
            "SSHIFTS\n0.5 0.6 /" => "SSHIFTS\n0.5 0.6 /\n0.7 0.8 /")
        write(path, inherited)
        @test parse_data_file(path; silent = true)["PROPS"]["SSHIFTS"] == [[0.5, 0.6], [0.7, 0.8]]

        write(path, replace(deck, "0.45 0.46 /" => "0.45 /"))
        @test_throws AssertionError parse_data_file(path; silent = true)
    end
end
