function get_extension(fn)
    e = fn |> splitext |> last |> lowercase
    return lstrip(e, '.')
end

function check_extension(fname, ext)
    @assert !startswith(ext, ".") "Extension should not start with a dot."
    e = get_extension(fname)
    e == lowercase(ext) || error("File $fname does not have the expected extension $ext, got $e")
end

function read_ix_include_file(fname, options; kwarg...)
    return read_ix_include_file!(Dict{String, Any}(), fname, options; kwarg...)
end

function read_ix_include_file!(dest, include_pth, local_path, options; verbose = false, strict = false)
    ext = get_extension(include_pth)
    if ext == "ixf"
        read_ixf_file!(dest, include_pth, options; verbose = verbose, strict = strict)
    elseif ext == "epc"
        read_epc_file!(dest, include_pth, options; verbose = verbose, strict = strict)
    elseif ext == "h5"
        # H5 is implicitly handled by EPC reading
    elseif ext == "obsh"
        if !haskey(dest, "OBSH")
            dest["OBSH"] = Dict{String, Any}()
        end
        dest["OBSH"][local_path] = read_obsh_file(include_pth; reformat = true)
    else
        msg = "Unsupported file extension $ext for include file $include_pth (local path $local_path)."
        if strict
            error(msg)
        else
            println("$msg - will be ignored.")
        end
    end
end

function read_ixf_file(include_pth, arg...; kwarg...)
    dest = Dict{String, Any}()
    read_ixf_file!(dest, include_pth, arg...; kwarg...)
    return dest
end

function read_ixf_file!(dest, include_pth, options = missing; kwarg...)
    basepath = splitdir(include_pth)[1]
    parsed = parse_ix_file(include_pth)
    process_records!(dest, parsed.children, basepath; kwarg...)
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
            xml = parse(Node, raw)
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

function unwrap_resqml_h5_contents(h5)
    kys = keys(h5)
    for k in kys
        if startswith(lowercase(k), "resqml")
            return h5[k]
        end
    end
    if length(kys) > 1
        @warn "Multiple top-level groups found in HDF5 file and no group started with resqml, returning the first one."
    elseif length(kys) == 0
        error("No top-level groups found in HDF5 file.")
    end
    return h5[kys[1]]
end

function read_epc_file!(dest, include_pth, options; verbose = false, strict = false)
    t = get(options, "type", "epc")
    t == "epc" || error("EPC type must be 'epc', got $t")
    epc_type = get(options, "resqml_type", "props")

    prop_info = parse_epc_info(include_pth)
    basename, ext = splitext(include_pth)

    h5 = HDF5.h5open("$basename.h5", "r")
    resqml = unwrap_resqml_h5_contents(h5)
    if epc_type == "props"
        ks = keys(resqml)
        if length(ks) == 0
            error("No RESQML groups found in EPC file $include_pth")
        elseif length(ks) > 1
            println("Multiple RESQML groups found in EPC file $include_pth, using the first one: $(collect(ks))")
        end
        data = resqml[first(ks)]
    elseif epc_type == "geom_and_props"
        data = Dict{String, Any}()
        for (k, v) in pairs(resqml)
            data[k] = read(v)
        end
    else
        error("Unsupported EPC type $epc_type, expected 'props' or 'geom_and_props'")
    end
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

"""
    read_afi_file("somefile.afi")
    read_afi_file(fpath; verbose = true, convert = false, strict = false)

Read .afi files. The .afi file is the main file of the IX input format and
contains references to other files, such as .ixf and .epc files.

# Arguments
- `fpath::String`: Path to the .afi file.
- `verbose::Bool=true`: Whether to print progress messages.
- `convert::Bool=false`: Whether to convert the parsed records to more
  user-friendly with unit conversion applied. The output format is substantially
  altered by enabling this option.
- `strict::Bool=false`: Whether to throw errors on unrecognized keywords or
  unsupported files.

# Notes
For input of dense data (e.g. grid properties), the parser is limited to the
RESQML format. This means that .gsg files are not supported.
"""
function read_afi_file(fpath;
        verbose = true,
        convert = false,
        strict = false
    )
    DTYPE = Dict{String, Any}
    msg(x) = verbose && println(x)
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
        if r isa IXSimulationRecord
            dest, cid = get_simulation_section(out, r.keyword, verbose = verbose)
            if cid == "IX"
                out["name"] = r.casename
            end
            process_records!(dest, r.arg, basepath, verbose = verbose, strict = strict)
        elseif r isa IXIncludeRecord
            dest, cid = get_simulation_section(out, get(r.options, "simulation", "IX"), verbose = verbose)
            recs = [r]
            process_records!(dest, recs, basepath; verbose = verbose, strict = strict)
        else
            continue
        end
    end
    if convert
        out = restructure_and_convert_units_afi(out; verbose = verbose, strict = strict)
    end
    return out
end

function get_simulation_section(out, cid; verbose = false)
    msg(x) = verbose && println(x)
    cid = uppercase(cid)
    if cid == "FM"
        dest = out["FM"]
        msg("Found field management model.")
    elseif cid == "IX"
        dest = out["IX"]
        msg("Found reservoir model.")
    else
        error("Unknown simulation component $(cid) in file $fname, expected FM or IX")
    end
    return (dest, cid)
end

function process_records!(dest, recs::Vector, basepath; verbose = true, strict = false)
    msg(x) = verbose && println(x)

    # Just in case...
    if !haskey(dest, "MODEL_DEFINITION")
        dest["MODEL_DEFINITION"] = Any[]
    end
    current_section = dest["MODEL_DEFINITION"]
    for rec in recs
        if rec isa IXIncludeRecord
            pth = rec.filename
            include_pth = normpath(joinpath(basepath, pth))
            msg("Processing include record: $pth")
            if !isfile(include_pth)
                msg = "Include file $include_pth does not exist, skipping."
                if strict
                    error(msg)
                else
                    println(msg)
                    continue
                end
            end
            read_ix_include_file!(dest, include_pth, pth, rec.options, verbose = true, strict = strict)
        elseif rec isa IXExtensionRecord
            ext = rec.value
            msg("Processing extension record: $ext")
            push!(dest["EXTENSION"], ext)
        else
            kw = rec.keyword
            if kw in ("START", "MODEL_DEFINITION")
                if !haskey(dest, kw)
                    dest[kw] = Any[]
                end
                current_section = dest[kw]
            elseif kw in ("DATE", "TIME")
                if !haskey(dest, "STEPS")
                    # This means that we are parsing a file standalone, use a
                    # wide key definition just in case.
                    dest["STEPS"] = OrderedDict{Any, Any}()
                end
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
