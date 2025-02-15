module GeoEnergyIOPythonCallExt
    import GeoEnergyIO
    using PythonCall

    function GeoEnergyIO.read_summary_impl(pth; extra_out = false, verbose = false)
        summary_mod = pyimport("resdata.summary")
        smry = summary_mod.Summary(pth);
        smry_keys = to_julia_keys(smry)

        t_total = 0.0
        out = Dict{String, Any}()
        for k in smry_keys
            t_kw = @elapsed kw = pyconvert(Vector{Float64}, smry.numpy_vector(k))
            if ':' in k
                cat, name = split(k, ':')
                if haskey(out, cat)
                    out[cat][name] = kw
                else
                    out[cat] = Dict{String, Any}(name => kw)
                end
            else
                out[k] = kw
            end
            if verbose
                println("$k read in $t_kw s")
            end
            t_total += t_kw
        end
        if extra_out
            ret = (out, smry)
        else
            ret = out
        end
        if verbose
            println("resdata extension: Read $(length(smry_keys)) keywords in $t_total s")
        end
        return ret
    end

    function GeoEnergyIO.read_egrid_impl(pth; extra_out = false, verbose = false)
        grid_mod = pyimport("resdata.grid")
        epth = "$pth.EGRID"
        isfile(epth) || error("File not found: $epth")
        egrid = grid_mod.Grid(epth)

        nx, ny, nz, nact = pyconvert(Tuple, egrid.getDims())
        out = Dict{String, Any}()
        actnum = to_julia_array(egrid.export_actnum(), Int64)
        @assert length(actnum) == nx*ny*nz
        actnum_actual = Array{Bool, 3}(undef, nx, ny, nz)
        for i in eachindex(actnum, actnum_actual)
            actnum_actual[i] = actnum[i] > 0
        end
        out["ACTNUM"] = actnum_actual
        out["ZCORN"] = to_julia_array(egrid.export_zcorn())
        out["COORD"] = to_julia_array(egrid.export_coord())
        out["cartDims"] = [nx, ny, nz]

        if extra_out
            ret = (out, egrid)
        else
            ret = out
        end
        return ret
    end

    function GeoEnergyIO.read_restart_impl(pth; extra_out = false, actnum = missing, egrid = missing)
        resfile_mod = pyimport("resdata.resfile")
        grid_mod = pyimport("resdata.grid")
        np = pyimport("numpy")

        basepth, ext = splitext(pth)
        @info basepth
        if ismissing(egrid)
            egrid = grid_mod.Grid("$basepth.EGRID")
        end
        if ext == ""
            pth = "$pth.UNRST"
        end
        rstrt = resfile_mod.ResdataRestartFile(egrid, filename = pth)
        hkeys = to_julia_keys(rstrt)
        out = Dict{String, Any}[]
        for h in rstrt.headers()
            step = Dict{String, Any}()
            step["days"] = pyconvert(Float64, h.get_sim_days())
            step["date"] = pyconvert(String, h.get_sim_date().strftime("%Y-%m-%dT%H:%M:%S"))
            step["report_step"] = pyconvert(Int64, h.get_report_step())
            rst_block = rstrt.restart_view(report_step = h.get_report_step())
            for k in hkeys
                v = rst_block[k][0]
                dtype = v.dtype
                if pyconvert(Bool, dtype == np.int32)
                    T = Int64
                elseif pyconvert(Bool, dtype == np.float64) || pyconvert(Bool, dtype == np.float32)
                    T = Float64
                else
                    continue
                end
                v_array = to_julia_array(v)
                step[k] = map_to_active(v_array, actnum)
            end
            push!(out, step)
        end
        if extra_out
            ret = (out, rstrt)
        else
            ret = out
        end
        return ret
    end

    function GeoEnergyIO.read_init_impl(pth; extra_out = false, actnum = missing)
        np = pyimport("numpy")
        resfile_mod = pyimport("resdata.resfile")
        ipth = "$pth.INIT"
        isfile(ipth) || error("File not found: $ipth")
        init = resfile_mod.ResdataFile(ipth)
        out = Dict{String, Any}()
        for k in to_julia_keys(init)
            v = init[k][0]
            dtype = v.dtype
            if pyconvert(Bool, dtype == np.int32)
                T = Int64
            elseif pyconvert(Bool, dtype == np.float64) || pyconvert(Bool, dtype == np.float32)
                T = Float64
            else
                continue
            end
            ju_vec = to_julia_array(v, T)
            out[k] = map_to_active(ju_vec, actnum)
        end
        if extra_out
            ret = (out, init)
        else
            ret = out
        end
        return ret
    end

    function to_julia_array(pyarr, T = Float64)
        return pyconvert(Vector{T}, pyarr.numpy_copy())
    end

    function to_julia_keys(x)
        return pyconvert(Vector{String}, collect(x.keys()))
    end

    function map_to_active(ju_vec, actnum::AbstractArray)
        return map_to_active(ju_vec, vec(actnum))
    end

    function map_to_active(ju_vec, actnum::Vector)
        if length(ju_vec) == length(actnum)
            ju_vec = ju_vec[actnum]
        end
        return ju_vec
    end

    function map_to_active(ju_vec, ::Missing)
        return ju_vec
    end
end
