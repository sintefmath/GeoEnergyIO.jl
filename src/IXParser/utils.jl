function replace_square_bracketed_newlines(s, replacement=" NEWLINE ")
    section_regex = r"\[(.*?)\]"s # 's' flag for single-line mode (dot matches newline)
    m = match(section_regex, s)
    if isnothing(m)
        return s
    end
    start = 1
    str = ""
    for m in eachmatch(section_regex, s)
        str *= s[start:m.offset-1]
        content = replace(m.captures[1], "\n" => replacement)
        str *= "[" * content * "]"
        start = m.offset + length(m.match)
    end
    return str
end
