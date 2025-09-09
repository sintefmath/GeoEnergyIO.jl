abstract type AbstractIXRecord end

struct IXStandardRecord <: AbstractIXRecord
    keyword::String
    value::String
    body::Vector{Any}
end

struct IXEqualRecord <: AbstractIXRecord
    keyword::String
    value::Any
end

struct IXKeyword <: AbstractIXRecord
    keyword::String
end

struct IXFunctionCall <: AbstractIXRecord
    keyword::String
    args::Vector{Any}
end

struct IXIncludeRecord <: AbstractIXRecord
    filename::String
    options::Dict{String, Any}
end

struct IXSimulationRecord <: AbstractIXRecord
    keyword::String
    casename::Union{String, Missing}
    arg::Any
end

struct IXArrayEndline <: AbstractIXRecord

end
