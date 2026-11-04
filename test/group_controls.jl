using GeoEnergyIO, Test

@testset "Group control keyword records" begin
    for (units, liquid, gas) in (("METRIC", 1.0, 1.0),
            ("FIELD", 0.158987294928, 1000*0.3048^3))
        deck = """
RUNSPEC
$units
SCHEDULE
WELSPECS
P1 G 1 1 1000 OIL /
P2 G 2 1 1000 OIL /
/
GCONPROD
G LRAT 100 200 300 400 RATE 9* /
/
GCONINJE
G GAS RATE 100 200 0.5 0.8 /
G WATER RATE 200 /
/
WGRUPCON
'P*' NO /
P1 YES 10 OIL 0.5 /
/
TSTEP
1 /
GCONPROD
G ORAT 50 /
/
TSTEP
1 /
END
"""
        mktempdir() do dir
            path = joinpath(dir, "GROUPS.DATA")
            write(path, deck)
            steps = parse_data_file(path; silent = true)["SCHEDULE"]["STEPS"]
            rec = only(steps[1]["GCONPROD"])
            @test length(rec) == 21
            @test rec[3:6] ≈ [100liquid, 200liquid, 300gas, 400liquid]./86400
            @test rec[7:8] == ["RATE", "YES"]
            @test isnan(rec[9])
            @test isinf(rec[14])
            inj = steps[1]["GCONINJE"]
            @test inj[1][4:7] ≈ [100gas/86400, 200liquid/86400, 0.5, 0.8]
            @test inj[2][4] ≈ 200liquid/86400
            @test isinf(inj[2][5])
            @test isnan(inj[2][6])
            @test inj[2][8:10] == ["YES", 0.0, ""]
            guide = steps[1]["WGRUPCON"]
            @test Set(first.(guide[1:2])) == Set(["P1", "P2"])
            @test all(rec -> rec[2:5] == ["NO", -1.0, "", 1.0], guide[1:2])
            @test guide[3][3] ≈ 10liquid/86400
            @test guide[3][5] == 0.5
            @test only(steps[2]["GCONPROD"])[3] ≈ 50liquid/86400
        end
    end
end
