function replace_square_bracketed_newlines(s, replacement=" NEWLINE ")
    section_regex = r"\[\n*(.*?)\n*\]"s # 's' flag for single-line mode (dot matches newline)
    m = match(section_regex, s)
    if isnothing(m)
        return s
    end
    start = 1
    str = ""
    for m in eachmatch(section_regex, s)
        str *= s[start:m.offset-1]
        content = replace(only(m.captures), "\n" => replacement)
        str *= "[" * content * "]"
        start = m.offset + length(m.match)
    end
    str *= s[start:end]
    return str
end

function strip_comments(s::AbstractString)
    return replace(s, r"#.*" => "")
end

function strip_empty_strings(s::AbstractString)
    return replace(s, " \"\" " => "NONE")
end

"""
    obs_data = read_obs_file(pth)
    obs_data = read_obs_file(pth, reformat = true)

Read an OBSH file from path `pth`. If `reformat` is true, the data is
reformatted into a dictionary of wells, each containing a dictionary of
data series and a vector of `DateTime` objects.
"""
function read_obsh_file(pth; reformat = false)
    h = open(pth)
    units = readline(h)
    date_format = readline(h)
    data, header = readdlm(h, header = true)
    new_header = String[]
    for h in header
        if h == "DATE"
            for fmt in date_format
                if fmt == 'D'
                    push!(new_header, "DAY")
                elseif fmt == 'M'
                    push!(new_header, "MONTH")
                elseif fmt == 'Y'
                    push!(new_header, "YEAR")
                else
                    error("Unknown date format character $fmt in $date_format")
                end
            end
        elseif h != ""
            push!(new_header, h)
        end
    end
    close(h)
    out = Dict(
        "units" => units,
        "date_format" => date_format,
        "header" => new_header,
        "data" => data,
    )
    if reformat
        out = reformat_obsh_file(out)
    end
    return out
end

function reformat_obsh_file(x::AbstractDict)
    months = Dict(
        "jan" => 1,
        "feb" => 2,
        "mar" => 3,
        "apr" => 4,
        "may" => 5,
        "jun" => 6,
        "jul" => 7,
        "aug" => 8,
        "sep" => 9,
        "oct" => 10,
        "nov" => 11,
        "dec" => 12
    )
    header = x["header"]
    function header_index(key)
        ix = findfirst(isequal(key), header)
        @assert !isnothing(ix) "Did not find header $key in obsh file header $header"
        return ix
    end
    wellix = header_index("WELL")
    dayix = header_index("DAY")
    monthix = header_index("MONTH")
    yearix = header_index("YEAR")
    remainder = setdiff(header, ["WELL", "DAY", "MONTH", "YEAR"])
    otherix = [header_index(h) for h in remainder]
    data = x["data"]

    out = Dict{String, Any}()
    for row in axes(data, 1)
        well = data[row, wellix]
        if !haskey(out, well)
            out[well] = Dict{String, Any}()
            for h in remainder
                out[well][h] = Float64[]
            end
            out[well]["dates"] = DateTime[]
        end
        welldest = out[well]
        day = data[row, dayix]
        month = months[lowercase(data[row, monthix])[1:3]]
        year = data[row, yearix]
        date = DateTime(year, month, day)
        push!(welldest["dates"], date)
        for (i, h) in enumerate(remainder)
            push!(welldest[h], data[row, otherix[i]])
        end
    end
    return Dict("wells" => out, "keys" => remainder)
end

function find_records(d::AbstractDict, keyword, arg...; kwarg...)
    return find_records(AFIInputFile(d), keyword, arg...; kwarg...)
end

function find_records(d::AFIInputFile, keyword, t = "IX";
        steps = true,
        model = true,
        once = false
    )
    out = []
    src = d.setup[t]
    if model
        find_records!(out, src["MODEL_DEFINITION"], keyword; once = once)
    end
    if steps && !(once && length(out) > 0)
        for (k, step) in pairs(src["STEPS"])
            find_records!(out, step, keyword; once = once)
            if once && length(out) > 0
                break
            end
        end
    end
    if once
        out = only(out)
    end
    return out
end

function find_records(d::AbstractVector, keyword; once = false)
    out = find_records!([], d, keyword; once = once)
    if once
        out = only(out)
    end
    return out
end

function find_records!(dest::AbstractVector, recs::AbstractVector, keyword; once = false)
    for rec in recs
        if rec.keyword == keyword
            push!(dest, rec)
            if once
                break
            end
        end
    end
    return dest
end
