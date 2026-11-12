using GeoEnergyIO, Test

@testset "WSEGVALV records and units" begin
    for units in ("METRIC", "FIELD")
        mktempdir() do dir
            path = joinpath(dir, "VALVE.DATA")
            write(path, """
RUNSPEC
$units
SCHEDULE
WELSPECS
 P G 1 1 1000 WATER /
/
WSEGVALV
 P 22 0.9 0.01 2 0.3 0.001 0.07 SHUT 0.08 /
 P 23 0.8 0.02 /
/
TSTEP
 1 /
END
""")
            data = parse_data_file(path; silent = true)
            first_record, defaulted = first(data["SCHEDULE"]["STEPS"])["WSEGVALV"]
            length_unit = units == "FIELD" ? 0.3048 : 1.0
            @test first_record[1:3] == ["P", 22, 0.9]
            @test first_record[4] ≈ 0.01*length_unit^2
            @test first_record[5:7] ≈ [2, 0.3, 0.001]*length_unit
            @test first_record[8] ≈ 0.07*length_unit^2
            @test first_record[9] == "SHUT"
            @test first_record[10] ≈ 0.08*length_unit^2
            @test defaulted[9] == "OPEN"
            @test all(<(0), defaulted[5:8])
            @test defaulted[10] < 0
        end
    end
end
