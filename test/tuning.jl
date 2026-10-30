using Test, GeoEnergyIO
import GeoEnergyIO.InputParser as IP

@testset "TUNING timestep and convergence records" begin
    data = Dict{String, Any}()
    units = (from = IP.DeckUnitSystem(:metric), to = IP.DeckUnitSystem(:si))
    io = IOBuffer(" 2 30 0.2 1* 4 0.4 0.2 /\n 1* 0.002 3e-7 /\n12 1* 150 /\nTSTEP\n1 /\n")
    cfg = IP.ParserVerbosityConfig(silent = true)
    IP.parse_keyword!(data, Dict(), units, cfg, io, Val(:TUNING))
    @test data["TUNING"][1][1:7] ≈ [2*86400, 30*86400, 0.2*86400, 0.15*86400, 4, 0.4, 0.2]
    @test data["TUNING"][2][1:4] ≈ [0.1, 0.002, 3e-7, 1e-4]
    @test IP.next_keyword!(io) == :TSTEP
    IP.parse_keyword!(data, Dict(), units, cfg, IOBuffer("/\n/\n/\n"), Val(:TUNING))
    @test data["TUNING"][1][1:7] ≈ [86400, 365*86400, 0.1*86400, 0.15*86400, 3, 0.3, 0.1]
    @test data["TUNING"][2][1:4] ≈ [0.1, 1e-3, 1e-7, 1e-4]

    # Convergence tolerances are dimensionless in every deck unit system.
    for system in (:field, :si)
        units = (from = IP.DeckUnitSystem(system), to = IP.DeckUnitSystem(:si))
        IP.parse_keyword!(data, Dict(), units, cfg,
            IOBuffer("/\n 1* 0.002 3e-7 /\n/\n"), Val(:TUNING))
        @test data["TUNING"][2][2:3] == [0.002, 3e-7]
    end
end
