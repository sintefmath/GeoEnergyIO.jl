abstract type AbstractIXRecord end

struct IXStandardRecord <: AbstractIXRecord
    keyword::String
    value::String
    body::Vector{Any}
end

function Base.show(io::IO, t::MIME"text/plain", dopt::IXStandardRecord)
    println(io, "IXStandardRecord with keyword: $(dopt.keyword), value: $(dopt.value), body:")
    for line in dopt.body
        Base.show(io, t, line)
    end
end

struct IXEqualRecord <: AbstractIXRecord
    keyword::String
    value::Any
end

struct IXAssignmentRecord <: AbstractIXRecord
    keyword::String
    index::Int
    value::Any
end

function Base.show(io::IO, t::MIME"text/plain", dopt::IXEqualRecord)
    println(io, "IXEqualRecord: $(dopt.keyword) = $(dopt.value)")
end

struct IXKeyword <: AbstractIXRecord
    keyword::String
end

Base.String(x::IXKeyword) = x.keyword
Base.convert(::Type{String}, x::IXKeyword) = x.keyword

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

struct IXRepeatRecord <: AbstractIXRecord
    count::Int
    value::Union{Float64, Int}
end
