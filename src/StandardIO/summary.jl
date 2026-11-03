# Shared placement of summary columns in the structured VALUES dictionary.
function summary_category(key)
    if startswith(key, "W")
        return "WELLS"
    elseif startswith(key, "G")
        return "GROUP"
    elseif startswith(key, "R")
        return "REGIONS"
    elseif startswith(key, "B")
        return "BLOCKS"
    elseif startswith(key, "C")
        return "COMPLETIONS"
    elseif startswith(key, "S")
        return "SEGMENTS"
    elseif startswith(key, "A")
        return "AQUIFERS"
    end
    return "MISC"
end

function summary_group(col)
    if !col.valid
        return nothing
    end
    key = col.keyword
    if key in ("TIME", "YEARS", "DAY", "MONTH", "YEAR")
        return nothing
    elseif startswith(key, "F")
        return ("FIELD", nothing)
    end
    identity = ifelse(first(key) in ('W', 'G'), col.name, col.identity)
    return (summary_category(key), identity)
end
