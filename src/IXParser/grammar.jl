struct IXTransformer <: Lerche.Transformer end

function setup_ix_grammar()
    grammar = raw"""
    ?start: value*

    ?value: full_record
            | string
            | array
            | named_array
            | bare_array
            | empty_array
            | bare_string
            | string_record
            | anon_record
            | float
            | integer
            | tuple
            | simulation_record
            | script

    inner_record: full_record
            | array
            | equal_record
            | anon_record
            | bare_array
            | empty_array
            | named_array
            | function_call
            | include_record
            | extension_record
            | bare_string


    tuple_type: float
        | integer
        | string
        | bare_string
        | tuple

    array_type: tuple_type
        | repeat_float
        | repeat_int

    script: "@{" ANYTHING+ "}@"
    float: SIGNED_FLOAT | FLOAT
    repeat_float: integer "*" float
    repeat_int: integer "*" integer
    integer: SIGNED_INT | INT
    string : ESCAPED_STRING
    bare_string: NAME | ESCAPED_STRING_SINGLE
    any_string: bare_string | string
    array  : NAME "[" [array_type ( array_type)*] "]"
    named_array : NAME string "[" [array_type ( array_type)*] "]"
    bare_array: "[" array_type (array_type)* "]"
    string_record: NAME string+
    full_record: string_record "{"  (inner_record)* "}"
    equal_record: NAME bare_array? "=" (value | function_call)
    anon_record: NAME "{" (inner_record)* "}"
    include_record: "INCLUDE" string include_param*
    extension_record: "EXTENSION" string include_param*
    simulation_record: ("Simulation" (full_record | anon_record)) | "Simulation" "{" inner_record (inner_record)* "}"
    include_param: "{" equal_record (equal_record)* "}"
    tuple.10: "(" tuple_type (tuple_type)* ")"
    empty_array: "[" "]"
    function_call: NAME "(" [inner_record (inner_record)*] ")"

    COMMENT: /#+.*/
    NAME: /[A-Za-z_][A-Za-z0-9_\.\-]*/
    ANYTHING: /.+/

    _STRING_INNER: /.*?/
    _STRING_ESC_INNER: _STRING_INNER /(?<!\\)(\\\\)*?/
    ESCAPED_STRING_SINGLE : "'" _STRING_ESC_INNER "'"

    %import common.ESCAPED_STRING
    %import common.SIGNED_FLOAT
    %import common.SIGNED_INT
    %import common.FLOAT
    %import common.INT
    %import common.WS
    %import common.NEWLINE

    %ignore WS
    %ignore COMMENT
    """
    return Lerche.Lark(grammar, transformer = IXTransformer())
end

const IX_ENDLINE = raw"IX_ENDLINE"

function parse_ix_record(s::AbstractString, grammar = setup_ix_grammar())
    s = replace(s, " \"\" " => "NONE")
    s = replace_square_bracketed_newlines(s, " $IX_ENDLINE ")
    return Lerche.parse(grammar, s)
end

function parse_ix_file(fpath::String, g = setup_ix_grammar())
    fstr = read(fpath, String)
    return parse_ix_record(fstr, g)
end


function convert_ix_simulation_record(args::Vector)
    if length(args) == 1
        return convert_ix_simulation_record(only(args))
    else
        # A hack because we both have Simulation in the outer file and also in
        # the inner (where it is just another keyword...)
        return IXEqualRecord("Simulation", args)
    end
end

function convert_ix_simulation_record(x::IXStandardRecord)
    return IXSimulationRecord(x.keyword, x.value, x.body)
end

function convert_ix_simulation_record(x::IXEqualRecord)
    return IXSimulationRecord(x.keyword, missing, x.value)
end

struct IXExtensionRecord <: AbstractIXRecord
    value::Any
end

function to_string(x)
    return replace(String(x), "\\" => "", "\"" => "")
end

function convert_ix_equal_record(a)
    N = length(a)
    kw = to_string(a[1])
    if N == 3
        out = IXAssignmentRecord(kw, only(a[2]), a[3])
    else
        @assert N == 2
        out = IXEqualRecord(kw, a[2])
    end
    return out
end

function convert_ix_record(a)
    start = a[1]::IXEqualRecord
    return IXStandardRecord(start.keyword, start.value, a[2:end])
end

function convert_ix_anon_record(a)
    return IXEqualRecord(to_string(a[1]), a[2:end])
end

function convert_ix_inner_record(a)
    return only(a)
end

function convert_ix_bare_string(s)
    s = only(s)
    s = strip(s, '\'')
    if s == "TRUE"
        return true
    elseif s == "FALSE"
        return false
    elseif s == "NONE"
        return nothing
    elseif s == "OPEN"
        return IX_OPEN
    elseif s == "CLOSED"
        return IX_CLOSED
    elseif s == "HEAT"
        return IX_HEAT
    elseif s == "I"
        return IX_I
    elseif s == "J"
        return IX_J
    elseif s == "K"
        return IX_K
    elseif s == "IX_ENDLINE"
        return IXArrayEndline()
    else
        return IXKeyword(s)
    end
end

function convert_ix_array(a; is_named::Bool)
    kw = to_string(a[1])
    if is_named
        val = to_string(a[2])
        el_start = 3
    else
        el_start = 2
    end
    els = expand_ix_array(a; start = el_start)
    if is_named
        out = IXStandardRecord(kw, val, els)
    else
        out = IXEqualRecord(kw, els)
    end
    return out
end

function expand_ix_array(a; start::Int = 1)
    els = Any[]
    prev_type = missing
    for i in start:length(a)
        v = a[i]
        if v isa IXRepeatRecord
            for _ in 1:v.count
                push!(els, v.value)
            end
        else
            push!(els, v)
        end
        current_type = typeof(els[end])
        if ismissing(prev_type)
            prev_type = current_type
        elseif current_type != prev_type
            prev_type = Any
        end
    end
    if prev_type != Any
        els = convert(Vector{prev_type}, els)
    end
    return els
end

function convert_ix_ijk_tuple(a)
    return (parse(Int, a[1]), parse(Int, a[2]), parse(Int, a[3]))
end

function convert_ix_include_param(a)
    out = Dict{String, Any}()
    for rec in a
        out[rec.keyword] = rec.value
    end
    return out
end

function convert_ix_include_record(a)
    pth = a[1]
    if length(a) > 1
        @assert length(a) == 2
        opts = a[2]
    else
        opts = Dict()
    end
    return IXIncludeRecord(pth, opts)
end

function convert_ix_tuple(a)
    return Tuple(a)
end

function convert_ix_string_record(a)
    kw = to_string(a[1])
    if length(a) == 2
        g = to_string(a[2])
    else
        g = map(to_string, a[2:end])
    end
    return IXEqualRecord(kw, g)
end

function parse_ix_script(a)
    return a
end

function parse_repeat(a; T = Float64)
    n, v = a
    n = convert(Int, n)
    v = convert(T, v)
    return IXRepeatRecord(n, v)
end

@inline_rule float(t::IXTransformer,n) = Base.parse(Float64, n)
@inline_rule integer(t::IXTransformer,n) = Base.parse(Int, n)
@inline_rule tuple_type(t::IXTransformer,n) = n
@inline_rule array_type(t::IXTransformer,n) = n

@rule array(t::IXTransformer, a) = convert_ix_array(a; is_named = false)
@rule named_array(t::IXTransformer, a) = convert_ix_array(a; is_named = true)
@rule bare_array(t::IXTransformer, a) = expand_ix_array(a, start = 1)

@rule keyword(t::IXTransformer, a) = to_string(a)
@rule full_record(t::IXTransformer, a) = convert_ix_record(a)
@rule equal_record(t::IXTransformer, a) = convert_ix_equal_record(a)
@rule inner_record(t::IXTransformer, a) = convert_ix_inner_record(a)
# We just alias this one...
# @rule string_record(t::IXTransformer, a) = IXEqualRecord(to_string(a[1]), to_string(a[2]))
@rule string_record(t::IXTransformer, a) = convert_ix_string_record(a)

@rule anon_record(t::IXTransformer, a) = convert_ix_anon_record(a)
@rule bare_string(t::IXTransformer, a) = convert_ix_bare_string(a)
@rule string(t::IXTransformer, a) = to_string(only(a))
@rule empty_array(t::IXTransformer, _) = []
@rule function_call(t::IXTransformer, a) = IXFunctionCall(to_string(a[1]), a[2:end])
@rule include_param(t::IXTransformer, a) = convert_ix_include_param(a)
@rule include_record(t::IXTransformer, a) = convert_ix_include_record(a)
@rule simulation_record(t::IXTransformer, a) = convert_ix_simulation_record(a)
@rule extension_record(t::IXTransformer, a) = IXExtensionRecord(only(a))
@rule tuple(t::IXTransformer, a) = convert_ix_tuple(a)
@rule script(t::IXTransformer, a) = parse_ix_script(a)

@rule repeat_float(t::IXTransformer, a) = parse_repeat(a; T = Float64)
@rule repeat_int(t::IXTransformer, a) = parse_repeat(a; T = Int)

@rule t(t::IXTransformer, _) = true
@rule f(t::IXTransformer, _) = false
