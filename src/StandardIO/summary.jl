# Shared placement of summary columns in the structured VALUES dictionary.
function summary_category(key)
    startswith(key, "W") && return "WELLS"
    startswith(key, "G") && return "GROUP"
    startswith(key, "R") && return "REGIONS"
    startswith(key, "B") && return "BLOCKS"
    startswith(key, "C") && return "COMPLETIONS"
    startswith(key, "S") && return "SEGMENTS"
    startswith(key, "A") && return "AQUIFERS"
    return "MISC"
end

function summary_group(col)
    col.valid || return nothing
    key = col.keyword
    key in ("TIME", "YEARS", "DAY", "MONTH", "YEAR") && return nothing
    startswith(key, "F") && return ("FIELD", nothing)
    identity = first(key) in ('W', 'G') ? col.name : col.identity
    return (summary_category(key), identity)
end
