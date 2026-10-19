using Test, GeoEnergyIO
import GeoEnergyIO.InputParser as IP

@testset "TUNING timestep record" begin
    data = Dict{String,Any}()
    units = (from=IP.DeckUnitSystem(:metric),to=IP.DeckUnitSystem(:si))
    io = IOBuffer(" 2 30 0.2 1* 4 /\n /\n12 1* 150 /\nTSTEP\n1 /\n")
    cfg = IP.ParserVerbosityConfig(silent=true)
    IP.parse_keyword!(data,Dict(),units,cfg,io,Val(:TUNING))
    @test data["TUNING"][1:5] ≈ [2*86400,30*86400,0.2*86400,0.15*86400,4]
    @test IP.next_keyword!(io) == :TSTEP
    IP.parse_keyword!(data,Dict(),units,cfg,IOBuffer("/\n/\n/\n"),Val(:TUNING))
    @test data["TUNING"][1:5] ≈ [86400,365*86400,0.1*86400,0.15*86400,3]
end
