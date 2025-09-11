
function convert_function_call(fcall::IXFunctionCall, unit_systems, context_kw = missing)
    kw = fcall.keyword
    args = fcall.args
    converted_args = map(arg -> convert_function_argument(arg, unit_systems, context_kw), args)
    return IXFunctionCall(kw, converted_args)
end

function convert_function_argument(arg, unit_systems, context_kw = missing)
    kw = arg.keyword
    function convert_farg(x::IXKeyword)
        return convert_farg(String(x))
    end
    function convert_farg(x::AbstractString)
        return x
    end
    function convert_farg(x)
        error("Unhandled function argument type $kw $(typeof(x)) in context $context_kw")
    end

    return IXEqualRecord(kw, map(convert_farg, arg.value))
end
