using Test, GeoEnergyIO

@testset "Injection units follow the injected phase" begin
    for keyword in ("WCONINJE","WCONINJH")
        rates = Dict{String,Vector{Float64}}()
        for preferred in ("OIL","GAS","WATER")
            mktempdir() do dir
                path = joinpath(dir,"CASE.DATA")
                records = if keyword == "WCONINJE"
                    " 'I' GAS OPEN RATE 100 /\n 'I' WATER OPEN RATE 100 /\n 'I' OIL OPEN RATE 100 /\n 'I' GAS OPEN RATE 0 /\n 'I' GAS OPEN RATE 1* /\n"
                else
                    " 'I' GAS OPEN 100 /\n 'I' WATER OPEN 100 /\n 'I' OIL OPEN 100 /\n"
                end
                write(path,"RUNSPEC\nFIELD\nSCHEDULE\nWELSPECS\n 'I' 'G' 1 1 1 '$preferred' /\n/\n$keyword\n$records/\nTSTEP\n1 /\nEND\n")
                d = parse_data_file(path;silent=true)
                values = first(d["SCHEDULE"]["STEPS"])[keyword]
                if keyword == "WCONINJE"
                    col = 5
                else
                    col = 4
                end
                rates[preferred] = [r[col] for r in values]
            end
        end
        @test rates["OIL"] == rates["GAS"] == rates["WATER"]
        rate = rates["OIL"]
        @test rate[1] ≈ 100*28.316846592/86400
        @test rate[2] ≈ 100*0.158987294928/86400
        @test rate[3] ≈ rate[2]
        if keyword == "WCONINJE"
            @test rate[4] == 0.0
            @test rate[5] == Inf
        end
    end
end
