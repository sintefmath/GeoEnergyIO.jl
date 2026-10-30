"An industry standard format keyword, including its on-disk type (INTE, REAL, DOUB, LOGI, CHAR, Cnnn or MESS)."
struct BinaryKeyword
    name::String
    data::Vector
    type::String
    function BinaryKeyword(name::AbstractString, data::AbstractArray, type::AbstractString)
        name = String(name)
        isascii(name) && 0 < ncodeunits(name) <= 8 && !isspace(first(name)) &&
            !isspace(last(name)) || throw(ArgumentError("Keyword names must contain 1–8 ASCII characters without surrounding whitespace: $name"))
        T, width = keyword_type(type)
        type == "MESS" && !isempty(data) && throw(ArgumentError("MESS keywords must be empty"))
        vals = vec(collect(T, data))
        if T == String
            all(s -> isascii(s) && ncodeunits(s) <= width, vals) ||
                throw(ArgumentError("Strings in $name must fit in $width ASCII bytes"))
        end
        new(name, vals, String(type))
    end
end

function BinaryKeyword(name::AbstractString, data::AbstractArray; type = nothing)
    if isnothing(type)
        T = eltype(data)
        if T <: Bool
            type = "LOGI"
        elseif T <: Integer
            type = "INTE"
        elseif T <: AbstractFloat
            type = ifelse(T == Float32, "REAL", "DOUB")
        elseif T <: AbstractString
            width = maximum(ncodeunits, data; init = 8)
            width <= 999 || throw(ArgumentError("industry standard format strings cannot exceed 999 bytes"))
            type = ifelse(width == 8, "CHAR", "C$(lpad(width, 3, '0'))")
        else
            throw(ArgumentError("Cannot infer industry standard format type for $T; supply type explicitly"))
        end
    end
    return BinaryKeyword(name, data, type)
end

function keyword_type(type::AbstractString)
    if type == "INTE"
        return (Int32, 4)
    elseif type == "REAL"
        return (Float32, 4)
    elseif type == "DOUB"
        return (Float64, 8)
    elseif type == "LOGI"
        return (Bool, 4)
    elseif type == "CHAR"
        return (String, 8)
    elseif type == "MESS"
        return (UInt8, 0)
    elseif occursin(r"^C[0-9]{3}$", type)
        width = parse(Int, type[2:4])
        if width > 0
            return (String, width)
        end
    end
    throw(ArgumentError("Unsupported industry standard format keyword type '$type'"))
end

"Ordered keywords. String indexing returns the first occurrence; `keyword_values` returns every occurrence."
struct KeywordFile <: AbstractVector{BinaryKeyword}
    keywords::Vector{BinaryKeyword}
    endian::Symbol
end
KeywordFile(keywords::AbstractVector{BinaryKeyword}; endian = :big) = KeywordFile(collect(keywords), endian)
Base.size(f::KeywordFile) = size(f.keywords)
Base.getindex(f::KeywordFile, i::Int) = f.keywords[i]
Base.IndexStyle(::Type{KeywordFile}) = IndexLinear()
Base.haskey(f::KeywordFile, name::AbstractString) = any(k -> k.name == name, f)
function Base.getindex(f::KeywordFile, name::AbstractString)
    data = get(f, name, nothing)
    if isnothing(data)
        throw(KeyError(name))
    end
    return data
end
function Base.get(f::KeywordFile, name::AbstractString, default)
    ix = findfirst(k -> k.name == name, f)
    if isnothing(ix)
        return default
    end
    return f[ix].data
end
keyword_values(f::KeywordFile, name::AbstractString) = [k.data for k in f if k.name == name]

byteorder(x, endian) = ifelse(endian == :big, ntoh(x), ltoh(x))
function check_endian(endian; auto = false)
    endian in (:big, :little) || (auto && endian == :auto) ||
        throw(ArgumentError("endian must be :big, :little$(ifelse(auto, " or :auto", ""))"))
end

function read_marker(io, endian)
    return Int(reinterpret(Int32, byteorder(read(io, UInt32), endian)))
end

function read_record(io, endian; expected = nothing, limit = typemax(Int32))
    n = read_marker(io, endian)
    0 <= n <= limit || throw(ArgumentError("Invalid Fortran record length $n at byte $(position(io)-4)"))
    isnothing(expected) || n == expected || throw(ArgumentError("Expected $expected bytes, got $n at byte $(position(io)-4)"))
    bytes = read(io, n)
    length(bytes) == n || throw(EOFError())
    tail = read_marker(io, endian)
    n == tail || throw(ArgumentError("Fortran record markers disagree ($n != $tail) at byte $(position(io)-4)"))
    return bytes
end

"""
    read_binary(path_or_io; endian=:auto)

Read unformatted industry standard format records with 32-bit Fortran record markers. Numeric
types and keyword ordering are preserved. Both byte orders are accepted.
Malformed record markers, truncated arrays and unsupported types are errors.
"""
read_binary(path::AbstractString; kw...) = open(io -> read_binary(io; kw...), path, "r")
function read_binary(io::IO; endian = :auto)
    check_endian(endian; auto = true)
    keywords = BinaryKeyword[]
    if endian == :auto
        if eof(io)
            return KeywordFile(keywords)
        end
        pos = position(io)
        marker = read(io, UInt32)
        if ntoh(marker) == 16
            endian = :big
        elseif ltoh(marker) == 16
            endian = :little
        else
            throw(ArgumentError("Not an unformatted industry standard format file: expected a 16-byte keyword header at byte $pos"))
        end
        seek(io, pos)
    end
    while !eof(io)
        header = read_record(io, endian; expected = 16)
        name = rstrip(String(header[1:8]), [' ', '\0'])
        n = Int(reinterpret(Int32, byteorder(reinterpret(UInt32, header[9:12])[1], endian)))
        n >= 0 || throw(ArgumentError("Negative array length for $name (X231 arrays are not supported)"))
        type = String(header[13:16])
        T, width = keyword_type(type)
        type == "MESS" && n != 0 && throw(ArgumentError("Nonempty MESS keyword $name"))
        # Allocate from validated payload sizes.
        data = Vector{T}()
        while length(data) < n
            bytes = read_record(io, endian; limit = min(Int64(n-length(data))*width, typemax(Int32)))
            !isempty(bytes) && length(bytes) % width == 0 || throw(ArgumentError("Invalid payload length for $name"))
            if T == String
                for off in 1:width:length(bytes)
                    push!(data, rstrip(String(bytes[off:off+width-1]), [' ', '\0']))
                end
            else
                U = ifelse(width == 8, UInt64, UInt32)
                bits = byteorder.(reinterpret(U, bytes), endian)
                if T == Bool
                    vals = bits .!= 0
                else
                    vals = reinterpret(T, bits)
                end
                append!(data, vals)
            end
        end
        push!(keywords, BinaryKeyword(name, data, type))
    end
    return KeywordFile(keywords; endian)
end

function write_record(io, bytes, endian)
    n = Int32(sizeof(bytes))
    marker = byteorder(reinterpret(UInt32, n), endian)
    write(io, marker)
    write(io, bytes)
    write(io, marker)
end

function write_keyword(io, kw::BinaryKeyword, endian)
    n = length(kw.data)
    n <= typemax(Int32) || throw(ArgumentError("X231 arrays are not supported"))
    header = IOBuffer()
    write(header, rpad(kw.name, 8), byteorder(UInt32(n), endian), kw.type)
    write_record(io, take!(header), endian)
    T, width = keyword_type(kw.type)
    chunk = ifelse(T == String, 105, 1000)
    for first in 1:chunk:n
        vals = @view kw.data[first:min(first+chunk-1, n)]
        if T == String
            bytes = collect(codeunits(join(rpad.(vals, width))))
        else
            # industry standard format uses -1 for LOGI true (some producers use 1); accept both.
            if T == Bool
                vals = Int32[ifelse(v, -1, 0) for v in vals]
            end
            U = ifelse(width == 8, UInt64, UInt32)
            bytes = byteorder.(reinterpret(U, vals), endian)
        end
        write_record(io, bytes, endian)
    end
    return nothing
end

"""
    write_binary(path_or_io, keywords; endian=:big)

Write a `KeywordFile`, vector of `BinaryKeyword`s or dictionary of arrays.
Repeated keywords require the ordered representation. Files use standard
1000-element numeric and 105-element string payload blocks.
"""
function write_binary(io::IO, keywords; endian = nothing)
    if isnothing(endian)
        if keywords isa KeywordFile
            endian = keywords.endian
        else
            endian = :big
        end
    end
    check_endian(endian)
    if keywords isa AbstractDict
        entries = (BinaryKeyword(string(k), v) for (k, v) in pairs(keywords))
    else
        entries = keywords
    end
    for kw in entries
        write_keyword(io, kw, endian)
    end
    return io
end
function write_binary(path::AbstractString, keywords; kw...)
    open(io -> write_binary(io, keywords; kw...), path, "w")
    return abspath(path)
end

function file_path(path, extension)
    if endswith(uppercase(path), ".$extension")
        return String(path)
    end
    upper = "$path.$extension"
    lower = "$path.$(lowercase(extension))"
    return ifelse(isfile(upper), upper, ifelse(isfile(lower), lower, upper))
end

function output_path(path, extension)
    if endswith(uppercase(path), ".$extension")
        return String(path)
    end
    name = basename(path)
    lower = any(islowercase, name) && !any(isuppercase, name)
    return "$path.$(ifelse(lower, lowercase(extension), extension))"
end

function case_base(path)
    base, ext = splitext(path)
    if uppercase(ext) in (".INIT", ".EGRID", ".UNRST", ".RSSPEC", ".SMSPEC", ".UNSMRY") ||
            occursin(r"^\.[XS][0-9]+$"i, ext)
        return base
    end
    return String(path)
end

function split_files(base, letter)
    dir, name = splitdir(base)
    dir = ifelse(isempty(dir), ".", dir)
    isdir(dir) || throw(ArgumentError("Directory not found: $dir"))
    files = filter(readdir(dir; join = true)) do f
        stem, ext = splitext(basename(f))
        stem == name && occursin(Regex("^\\.$letter[0-9]+\$", "i"), ext)
    end
    sort!(files; by = f -> parse(Int, splitext(f)[2][3:end]))
    return files
end
