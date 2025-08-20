function get_extension(fn)
    e = fn |> splitext |> last |> lowercase
    return lstrip(e, '.')
end

function check_extension(fname, ext)
    @assert !startswith(ext, ".") "Extension should not start with a dot."
    e = get_extension(fname)
    e == lowercase(ext) || error("File $fname does not have the expected extension $ext, got $e")
end

function read_ix_include_file(fname, options; verbose = true)
    return read_ix_include_file!(Dict{String, Any}(), fname, options; verbose = true)
end

function read_ix_include_file!(dest, include_pth, options; verbose = true)
    ext = get_extension(include_pth)
    if ext == "ixf"
        read_ixf_file!(dest, include_pth, options; verbose = verbose)
    elseif ext == "epc"
        read_epc_file!(dest, include_pth, options; verbose = verbose)
    else
        println("Unsupported file extension $ext for include file $include_pth - will be ignored.")
    end
end

function read_ixf_file!(dest, include_pth, options; verbose = verbose)
    parsed = parse_ix_file(include_pth)
    sect_vec = dest["MODEL_DEFINITION"]
    for rec in parsed.children
        push!(sect_vec, rec)
    end
    return dest
end

function parse_epc_info(epc_pth)
    epc_data = ZipArchives.read(epc_pth)
    zipfile = ZipArchives.ZipReader(epc_data)
    out = Dict{String, Any}()
    for (i, glob_path) in enumerate(ZipArchives.zip_names(zipfile))
        dir, name = splitdir(glob_path)
        f, ext = splitext(name)
        if lowercase(ext) == ".xml"
            raw = ZipArchives.zip_readentry(zipfile, glob_path, String)
            out[glob_path] = parse(XML.Node, raw)
        end
    end
    return out
end

function read_epc_file!(dest, include_pth, options; verbose = verbose)
    function unpack_resqml(x)
        resqml = x["RESQML"]
        k = only(keys(resqml))
        return resqml[k]
    end

    t = get(options, "type", "epc")
    t == "epc" || error("EPC type must be 'epc', got $t")
    epc_type = get(options, "epc_type", "props")

    prop_info = parse_epc_info(include_pth)
    basename, ext = splitext(include_pth)

    h5 = HDF5.h5open("$basename.h5", "r")
    data = unpack_resqml(h5)
    if !haskey(dest, "RESQML")
        dest["RESQML"] = Dict{String, Any}()
    end
    epc_dest = dest["RESQML"]
    if !haskey(epc_dest, epc_type)
        epc_dest[epc_type] = []
    end
    push!(epc_dest[epc_type], (epc = prop_info, h5 = data))
    return dest
end

function read_afi_file(fpath; verbose = true)
    DTYPE = Dict{String, Any}
    msg(x) = verbose && println(x)
    warn(x) = println("WARNING: $x")
    unsupported(x) = println("UNSUPPORTED KEYWORD: $x")
    # Starting to read the file...
    basepath, fname = splitdir(fpath)
    check_extension(fname, "afi")
    parsed = parse_ix_file(fpath)
    FM = DTYPE("EXTENSION" => String[], "MODEL_DEFINITION" => Any[])
    IX = DTYPE("EXTENSION" => String[], "MODEL_DEFINITION" => Any[])
    out = DTYPE(
        "name" => missing,
        "FM" => FM,
        "IX" => IX
    )
    for r in parsed.children
        r::IXSimulationRecord
        cid = r.keyword
        if cid == "FM"
            dest = FM
            msg("Found field management model.")
        elseif cid == "IX"
            dest = IX
            out["name"] = r.casename
            msg("Found reservoir model.")
        else
            error("Unknown simulation component $(cid) in file $fname, expected FM or IX")
        end
        for rec in r.arg
            if rec isa IXIncludeRecord
                pth = rec.filename
                include_pth = normpath(joinpath(basepath, pth))
                if !isfile(include_pth)
                    error("Include file $include_pth does not exist, skipping.")
                end
                msg("Processing include record: $pth")
                read_ix_include_file!(dest, include_pth, rec.options; verbose = true)
            elseif rec isa IXExtensionRecord
                ext = rec.value
                msg("Processing extension record: $ext")
                push!(dest["EXTENSION"], ext)
            else
                error("Unknown record type $(typeof(rec)) in file $fname")
            end
        end
    end
    return out
end
