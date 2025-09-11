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

function read_obsh_file(pth)
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
    return Dict(
        "units" => units,
        "date_format" => date_format,
        "header" => new_header,
        "data" => data,
    )
end

