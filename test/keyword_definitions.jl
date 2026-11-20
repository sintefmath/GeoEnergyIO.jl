@testset "Deck keyword definitions" begin
    parser = GeoEnergyIO.InputParser

    flag = parser.keyword_definition(Val(:WATER))
    @test flag isa parser.NoRecordKeyword
    @test parser.keyword_layout(flag) == :none

    pinch = parser.keyword_definition(Val(:PINCH))
    @test pinch isa parser.SingleRecordKeyword
    @test parser.keyword_defaults(pinch) == [0.001, "GAP", Inf, "TOPBOT", "TOP"]
    @test parser.keyword_units(pinch) == (:length, :id, :length, :id, :id)
    parser.keyword_defaults(pinch)[1] = 99.0
    @test parser.keyword_defaults(parser.keyword_definition(Val(:PINCH)))[1] == 0.001

    tuning = parser.keyword_definition(Val(:TUNING))
    @test tuning isa parser.MultiRecordKeyword
    @test parser.keyword_layout(tuning) == 3

    swof = parser.keyword_definition(Val(:SWOF))
    @test swof isa parser.SaturationTableKeyword
    @test parser.keyword_units(swof) == (:identity, :identity, :identity, :pressure)
    @test parser.keyword_name(swof) == :SWOF

    data = Dict{String, Any}()
    outer_data = Dict("RUNSPEC" => Dict("TABDIMS" => [2, 1]))
    units = (from = parser.DeckUnitSystem(:field), to = parser.DeckUnitSystem(:si))
    cfg = parser.ParserVerbosityConfig(silent = true)
    parser.parse_keyword!(data, outer_data, units, cfg, IOBuffer("0.2 0.0 1.0 10.0 /\n/\n"), swof)
    @test length(data["SWOF"]) == 2
    @test data["SWOF"][2] == data["SWOF"][1]
    @test data["SWOF"][1][1, 4] ≈ parser.convert_between_unit_systems(10.0, :pressure; from = :field, to = :si)

    for name in keys(parser.KEYWORD_SECTIONS)
        @test parser.keyword_name(parser.keyword_definition(Val(name))) === name
    end
end
