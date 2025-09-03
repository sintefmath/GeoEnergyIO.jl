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
    basepath = splitdir(include_pth)[1]
    parsed = parse_ix_file(include_pth)
    process_records!(dest, parsed.children, basepath)
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
            xml = parse(XML.Node, raw)
            if dir == ""
                out[name] = xml
            else
                if !haskey(out, dir)
                    out[dir] = Dict{String, Any}()
                end
                out[dir][name] = xml
            end
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
    function make_section()
        return DTYPE(
            "MODEL_DEFINITION" => Any[],
            "START" => Any[],
            "EXTENSION" => String[],
            "STEPS" => OrderedDict()
        )
    end
    FM = make_section()
    IX = make_section()
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
        process_records!(dest, r.arg, basepath, verbose = verbose)
    end
    return out
end

function process_records!(dest, recs::Vector, basepath; verbose = true)
    msg(x) = verbose && println(x)
    warn(x) = println("WARNING: $x")
    unsupported(x) = println("UNSUPPORTED KEYWORD: $x")

    # Just in case...
    current_section = dest["MODEL_DEFINITION"]
    for rec in recs
        if rec isa IXIncludeRecord
            pth = rec.filename
            include_pth = normpath(joinpath(basepath, pth))
            if !isfile(include_pth)
                error("Include file $include_pth does not exist, skipping.")
            end
            msg("Processing include record: $pth")
            read_ix_include_file!(dest, include_pth, rec.options, verbose = true)
        elseif rec isa IXExtensionRecord
            ext = rec.value
            msg("Processing extension record: $ext")
            push!(dest["EXTENSION"], ext)
        else
            kw = rec.keyword
            if kw in ("START", "MODEL_DEFINITION")
                current_section = dest[kw]
            elseif kw in ("DATE", "TIME")
                if !haskey(dest["STEPS"], rec)
                    dest["STEPS"][rec] = []
                end
                current_section = dest["STEPS"][rec]
            else
                push!(current_section, rec)
            end
        end
    end
    return dest
end
