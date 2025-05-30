module GeoEnergyIOPythonCallExt
    import GeoEnergyIO
    using PythonCall
    import Dates
    import Jutul: si_units

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
        basename, ext = splitext(pth)
        if ext == ""
            epth = "$pth.EGRID"
        else
            epth = pth
        end
        if !isfile(epth)
            epth = "$(epth)_GRID.EGRID"
            isfile("$epth") || error("File not found: $epth")
            if verbose
                println("EGRID file not at $basename, but found _GRID.EGRID instead.")
            end
        end
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

    function GeoEnergyIO.read_restart_impl(pth;
            extra_out = false,
            actnum = missing,
            egrid = missing,
            verbose = false,
            steps = missing
        )
        resfile_mod = pyimport("resdata.resfile")
        grid_mod = pyimport("resdata.grid")
        np = pyimport("numpy")

        basepth, ext = splitext(pth)
        basedir, basename = splitdir(basepth)
        if ismissing(egrid)
            egrid_1 = "$basepth.EGRID"
            # Sometimes the EGRID file has _GRID appended.
            egrid_2 = "$(basepth)_GRID.EGRID"
            if isfile(egrid_1)
                egrid = grid_mod.Grid(egrid_1)
            elseif isfile(egrid_2)
                egrid = grid_mod.Grid(egrid_2)
            end
        end
        if ext == ""
            pth = "$pth.UNRST"
            is_unified = isfile(pth)
        else
            is_unified = ext == ".UNRST"
        end
        out = Dict{String, Any}[]
        warned = Dict{String, Bool}()

        if is_unified
            if ismissing(egrid)
                error("EGRID required for unified restart file, not found in keyword argument or as either $basepth.EGRID or $(basename)_GRID.EGRID")
            end
            rstrt = resfile_mod.ResdataRestartFile(egrid, filename = pth)
            hkeys = to_julia_keys(rstrt)
            for (stepno, h) in enumerate(rstrt.headers())
                if ismissing(steps)
                    in_list = true
                else
                    in_list = stepno in steps
                end
                if verbose
                    if in_list
                        println("Parsing step $stepno")
                    else
                        println("Skipping step $stepno")
                    end
                end
                if !in_list
                    continue
                end
                step = Dict{String, Any}()
                step["days"] = pyconvert(Float64, h.get_sim_days())
                try
                    step["date"] = pyconvert(String, h.get_sim_date().strftime("%Y-%m-%dT%H:%M:%S"))
                catch
                    println("Reading date failed for step $stepno")
                    step["date"] = missing
                end
                step["report_step"] = pyconvert(Int64, h.get_report_step())
                rst_block = rstrt.restart_view(report_step = h.get_report_step())
                for k in hkeys
                    v = missing
                    try
                        v = rst_block[k][0]
                    catch excpt
                        if !haskey(warned, k)
                            println("Skipping $k due to exception in reading $excpt")
                            warned[k] = true
                        end
                    end
                    if ismissing(v)
                        continue
                    end
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
        else
            if ismissing(actnum) && !ismissing(egrid)
                actnum = to_julia_array(egrid.export_actnum(), Int64)
                actnum = map(x -> x > 0, actnum)
            end
            if ext == "" || ext == ".RSSPEC"
                files = String[]
                ix = 1
                while true
                    pth = "$basepth.X$(string(ix, pad = 4))"
                    if ismissing(steps)
                        in_list = true
                    else
                        in_list = ix in steps
                    end
                    if isfile(pth)
                        if in_list
                            push!(files, pth)
                        end
                    else
                        break
                    end
                    ix += 1
                end
            else
                startswith(ext, ".X") || error("Unknown restart file extension: $ext")
                files = [pth]
            end
            for (stepno, file) in enumerate(files)
                if verbose
                    println("Parsing step $stepno")
                end
                result = resfile_mod.ResdataFile(file)
                step = Dict{String, Any}()
                for k in to_julia_keys(result)
                    v = missing
                    try
                        v = result[k][0]
                    catch excpt
                        if !haskey(warned, k)
                            println("Skipping $k due to exception in reading $excpt")
                            warned[k] = true
                        end
                    end
                    if ismissing(v)
                        continue
                    end
                    dtype = v.dtype
                    if pyconvert(Bool, dtype == np.int32)
                        T = Int64
                    elseif pyconvert(Bool, dtype == np.float64) || pyconvert(Bool, dtype == np.float32)
                        T = Float64
                    else
                        continue
                    end
                    ju_vec = to_julia_array(v, T)
                    step[k] = map_to_active(ju_vec, actnum)
                end
                push!(out, step)
            end
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

    function GeoEnergyIO.write_jutuldarcy_summary_impl(output_path, smry_jutul; unified = true)
        dirpath, filename = splitdir(output_path)
        dirpath = abspath(dirpath)
        output_path = joinpath(dirpath, filename)
        summary_mod = pyimport("resdata.summary")
        haskey(smry_jutul, "DIMENS") || error("No dimensions found")
        haskey(smry_jutul, "TIME") || error("No time found")
        haskey(smry_jutul, "VALUES") || error("No values found")

        function map_variables(source::AbstractDict; arg...)
            dest = Dict()
            for (k, v) in pairs(source)
                # TODO: Unit
                varkey = rs_sum.add_variable(k; num = 0, unit = "None", arg...)
                dest[k] = varkey.get_key1()
            end
            return dest
        end
        function write_variable(t_step, varmap, vals, step_ix)
            for (k, v) in pairs(vals)
                t_step[varmap[k]] = v[step_ix]
            end
        end
        # Set up destination
        if ismissing(smry_jutul["TIME"].start_date)
            yr = 1970
            mnth = 1
            day = 1
        else
            start = smry_jutul["TIME"].start_date
            yr = Dates.year(start)
            mnth = Dates.month(start)
            day = Dates.day(start)
        end
        date0 = pyimport("datetime").date(yr, mnth, day)
        dims = smry_jutul["DIMENS"]
        t_jutul = smry_jutul["TIME"].seconds
        rs_sum = summary_mod.Summary.writer(
            output_path, date0, dims[1], dims[2], dims[3],
            unified = unified
        );
        # Mapping of variables
        vals_jutul = smry_jutul["VALUES"]
        varmap = Dict()
        varmap["FIELD"] = map_variables(vals_jutul["FIELD"])
        for (wlabel, wvals) in pairs(vals_jutul["WELLS"])
            varmap[wlabel] = map_variables(wvals, wgname = wlabel)
        end
        k_years = rs_sum.add_variable("YEARS", num = 0, unit = "None").get_key1()
        uday, uyear = si_units(:day, :year)
        for (report_step, elapsed_in_seconds) in enumerate(t_jutul)
            current_t_in_years = elapsed_in_seconds/uyear
            current_t_in_days = elapsed_in_seconds/uday
            t_step = rs_sum.add_t_step(report_step, sim_days = current_t_in_days)
            t_step[k_years] = current_t_in_years
            write_variable(t_step, varmap["FIELD"], vals_jutul["FIELD"], report_step)
            for (wlabel, wvals) in pairs(vals_jutul["WELLS"])
                write_variable(t_step, varmap[wlabel], wvals, report_step)
            end
        end
        rs_sum.fwrite()
        if unified
            ext = ".UNSMRY"
        else
            ext = ".X0001"
        end
        return (dirpath, filename, ext)
    end

    function GeoEnergyIO.write_egrid_impl(data::AbstractDict, pth)
        if haskey(data, "GRID")
            data = data["GRID"]
        end
        fname, ext = splitext(pth)
        if ext == ""
            ext = ".EGRID"
        end
        pth = "$fname$ext"
        gridmod = pyimport("resdata.grid")
        resdatamod = pyimport("resdata")
        resfilemod = pyimport("resdata.resfile")

        specgrid = data["SPECGRID"]
        coord = data["COORD"]
        zcorn = data["ZCORN"]
        actnum = data["ACTNUM"]

        zcorn_py = gridmod.rd_grid_generator.construct_floatKW("ZCORN", zcorn)
        coord_py = gridmod.rd_grid_generator.construct_floatKW("COORD", coord)
        actnum_py = resfilemod.ResdataKW("ACTNUM", length(actnum), resdatamod.ResDataType.RD_INT)
        for (i, v) in enumerate(actnum)
            actnum_py[i-1] = v
        end
        egrid = gridmod.Grid.create(PyArray(specgrid), zcorn_py, coord_py, actnum_py)
        egrid.save_EGRID(pth)
        return abspath(pth)
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
