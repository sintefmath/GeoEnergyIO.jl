abstract type AbstractIXRecord end

struct IXStandardRecord <: AbstractIXRecord
    keyword::String
    value::Union{String, Vector{String}}
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

struct AFIInputFile <: AbstractInputFile
    setup::AbstractDict
end

struct IXLookupRecord <: AbstractIXRecord
    name::String
    key::String
end

function IXLookupRecord(a)
    name = to_string(a[1])
    key = to_string(a[2])
    return IXLookupRecord(name, key)
end

struct IXDoubleProperty <: AbstractIXRecord
    name::Union{String, IXLookupRecord}
    value::Float64
end

function IXDoubleProperty(a)
    length(a) == 2 || error("Expected 2 arguments to DoubleProperty, got $(length(a))")
    value = convert(Float64, a[1])
    if a[2] isa Vector
        name = IXLookupRecord(a[2])
    else
        name = a[2]
    end
    return IXDoubleProperty(name, value)
end


Base.getindex(f::AFIInputFile, k::String) = f.setup[k]
Base.haskey(f::AFIInputFile, k::String) = haskey(f.setup, k)
Base.keys(f::AFIInputFile) = keys(f.setup)
Base.length(f::AFIInputFile) = length(f.setup)

function Base.show(io::IO, ::MIME"text/plain", f::AFIInputFile)
    k = join(keys(f.setup), ", ")
    print(io, "AFIInputFile with sections $k\n")
end
