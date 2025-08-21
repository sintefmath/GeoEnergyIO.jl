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


    array_type: float
        | integer
        | string
        | bare_string
        | function_call

    script: "@{" ANYTHING+ "}@"
    float: SIGNED_FLOAT | FLOAT
    integer: SIGNED_INT | INT
    string : ESCAPED_STRING
    bare_string: NAME | ESCAPED_STRING_SINGLE
    any_string: bare_string | string
    array  : NAME "[" [value ( value)*] "]"
    named_array : NAME string "[" [value ( value)*] "]"
    full_record: NAME string "{"  (inner_record)* "}"
    equal_record: NAME "=" (value | function_call)
    anon_record: NAME "{" (inner_record)* "}"
    string_record: NAME string
    include_record: "INCLUDE" string include_param*
    extension_record: "EXTENSION" string include_param*
    simulation_record: ("Simulation" (full_record | anon_record)) | "Simulation" "{" inner_record (inner_record)* "}"
    include_param: "{" equal_record (equal_record)* "}"
    tuple.10: "(" array_type (array_type)* ")"
    bare_array: "[" value (value)* "]"
    empty_array: "[" "]"
    function_call: NAME "(" [inner_record (inner_record)*] ")"

    COMMENT: /#+.*/
    NAME: /[A-Za-z_][A-Za-z0-9_\-]*/
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

function parse_ix_record(s::AbstractString, grammar = setup_ix_grammar())
    s = replace(s, "\"\"" => "NONE")
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
    return IXEqualRecord(to_string(a[1]), a[2])
end

function convert_ix_record(a)
    return IXStandardRecord(to_string(a[1]), to_string(a[2]), a[3:end])
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
    else
        return IXKeyword(s)
    end
end

function convert_ix_array(a; is_named::Bool)
    if is_named
        return IXStandardRecord(to_string(a[1]), to_string(a[2]), a[3:end])
    else
        return IXEqualRecord(to_string(a[1]), Array(a[2:end]))
    end
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

function parse_ix_script(a)
    return a
end


@inline_rule float(t::IXTransformer,n) = Base.parse(Float64, n)
@inline_rule integer(t::IXTransformer,n) = Base.parse(Int, n)
@inline_rule array_type(t::IXTransformer,n) = n

@rule array(t::IXTransformer, a) = convert_ix_array(a; is_named = false)
@rule named_array(t::IXTransformer, a) = convert_ix_array(a; is_named = true)

@rule keyword(t::IXTransformer, a) = to_string(a)
@rule full_record(t::IXTransformer, a) = convert_ix_record(a)
@rule equal_record(t::IXTransformer, a) = convert_ix_equal_record(a)
@rule inner_record(t::IXTransformer, a) = convert_ix_inner_record(a)
# We just alias this one...
@rule string_record(t::IXTransformer, a) = IXEqualRecord(to_string(a[1]), to_string(a[2]))
@rule anon_record(t::IXTransformer, a) = convert_ix_anon_record(a)
@rule bare_string(t::IXTransformer, a) = convert_ix_bare_string(a)
@rule string(t::IXTransformer, a) = to_string(only(a))
@rule ijk_tuple(t::IXTransformer, a) = convert_ix_ijk_tuple(a)
@rule empty_array(t::IXTransformer, _) = []
@rule function_call(t::IXTransformer, a) = IXFunctionCall(to_string(a[1]), a[2:end])
@rule bare_array(t::IXTransformer, a) = a
@rule include_param(t::IXTransformer, a) = convert_ix_include_param(a)
@rule include_record(t::IXTransformer, a) = convert_ix_include_record(a)
@rule simulation_record(t::IXTransformer, a) = convert_ix_simulation_record(a)
@rule extension_record(t::IXTransformer, a) = IXExtensionRecord(only(a))
@rule tuple(t::IXTransformer, a) = convert_ix_tuple(a)
@rule script(t::IXTransformer, a) = parse_ix_script(a)

@rule t(t::IXTransformer, _) = true
@rule f(t::IXTransformer, _) = false
