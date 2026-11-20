abstract type KeywordDefinition{K} end
abstract type NoRecordKeyword{K} <: KeywordDefinition{K} end
abstract type SingleRecordKeyword{K} <: KeywordDefinition{K} end
abstract type MultiRecordKeyword{K} <: KeywordDefinition{K} end
abstract type SaturationTableKeyword{K} <: MultiRecordKeyword{K} end

struct FlagKeyword{K} <: NoRecordKeyword{K}
    support::Symbol
    warning::Union{PARSER_WARNING, Nothing}
end

FlagKeyword{K}(; support = :flag, warning = nothing) where K = FlagKeyword{K}(support, warning)

struct RecordKeyword{K, D, U} <: SingleRecordKeyword{K}
    defaults::D
    units::U
    support::Symbol
    warning::Union{PARSER_WARNING, Nothing}
end

function RecordKeyword{K}(; defaults = nothing, units = nothing, support = :parsed, warning = nothing) where K
    return RecordKeyword{K, typeof(defaults), typeof(units)}(defaults, units, support, warning)
end

struct TextKeyword{K} <: SingleRecordKeyword{K} end

struct RecordsKeyword{K, D, U} <: MultiRecordKeyword{K}
    defaults::D
    units::U
    records::Union{Int, Symbol}
    support::Symbol
    warning::Union{PARSER_WARNING, Nothing}
end

function RecordsKeyword{K}(; defaults = nothing, units = nothing, fields = nothing, records = :terminated,
        support = :parsed, warning = nothing) where K
    if !isnothing(fields)
        defaults = map(first, fields)
        units = map(last, fields)
    end
    return RecordsKeyword{K, typeof(defaults), typeof(units)}(defaults, units, records, support, warning)
end

keyword_edit_unit(::KeywordDefinition) = nothing
keyword_default_value(::KeywordDefinition, T::Type) = zero(T)

struct UnrecognizedKeyword{K} <: KeywordDefinition{K} end
struct TracerProfileKeyword{K} <: SingleRecordKeyword{K} end
struct UnsupportedTracerKeyword{K} <: SingleRecordKeyword{K} end

keyword_name(::KeywordDefinition{K}) where K = K
keyword_defaults(::KeywordDefinition) = nothing
keyword_defaults(def::Union{RecordKeyword, RecordsKeyword}) = def.defaults
keyword_defaults(def::KeywordDefinition, outer_data, units) = keyword_defaults(def)
keyword_units(::KeywordDefinition) = nothing
keyword_units(def::Union{RecordKeyword, RecordsKeyword}) = def.units
keyword_units(def::KeywordDefinition, record) = keyword_units(def)
keyword_support(::KeywordDefinition) = :parsed
keyword_support(def::Union{FlagKeyword, RecordKeyword, RecordsKeyword}) = def.support
keyword_warning(::KeywordDefinition) = nothing
keyword_warning(def::Union{FlagKeyword, RecordKeyword, RecordsKeyword}) = def.warning

keyword_layout(::NoRecordKeyword) = :none
keyword_layout(::SingleRecordKeyword) = :single
keyword_layout(::TextKeyword) = :text
keyword_layout(def::RecordsKeyword) = def.records
keyword_layout(::SaturationTableKeyword) = :saturation

const KEYWORD_SECTIONS = Dict{Symbol, Symbol}()

# The declaration also registers the keyword's section for the manual.
macro keyword(section, names, kind, options...)
    names = names isa Expr && names.head == :tuple ? names.args : (names,)
    kwargs = map(option -> Expr(:kw, option.args...), options)
    declarations = map(names) do name
        symbol = name isa String ? Symbol(name) : name.value
        key = QuoteNode(symbol)
        quote
            keyword_definition(::Val{$key}) = $kind{$key}(; $(kwargs...))
            KEYWORD_SECTIONS[$key] = $section
        end
    end
    return esc(Expr(:block, declarations...))
end

"""
    keyword_definition(::Val{:KEYWORD})

Construct the parser definition for a deck keyword. Use
`keyword_defaults(definition)`, `keyword_units(definition)` and
`keyword_layout(definition)` to inspect its metadata. Some defaults and units
are resolved from the deck or record during parsing.
"""
function keyword_definition(::Val{K}) where K
    name = String(K)
    if startswith(name, "TVDPF")
        return TracerProfileKeyword{K}()
    elseif startswith(name, "TVDP")
        return UnsupportedTracerKeyword{K}()
    end
    return UnrecognizedKeyword{K}()
end

function parse_keyword!(data, outer_data, units, cfg, f, name::Val)
    definition = keyword_definition(name)
    if definition isa Union{UnrecognizedKeyword, TracerProfileKeyword, UnsupportedTracerKeyword}
        for (kw, num, warning) in KEYWORD_SKIP_LIST
            if kw === keyword_name(definition)
                definition = skipped_keyword(name, num, warning)
                break
            end
        end
    end
    return parse_keyword!(data, outer_data, units, cfg, f, definition)
end

function skipped_keyword(::Val{K}, num, warning) where K
    if num == 0
        return FlagKeyword{K}(; warning)
    elseif num == 1
        return RecordKeyword{K}(; support = :raw, warning)
    else
        return RecordsKeyword{K}(; support = :ignored, warning)
    end
end

function report_keyword_warning(cfg, outer_data, def)
    warning = keyword_warning(def)
    if !isnothing(warning)
        parser_message(cfg, outer_data, String(keyword_name(def)), warning)
    end
end

function parse_keyword!(data, outer_data, units, cfg, f, def::FlagKeyword)
    report_keyword_warning(cfg, outer_data, def)
    if keyword_support(def) == :flag
        return data[String(keyword_name(def))] = true
    end
    return nothing
end

function parse_keyword!(data, outer_data, units, cfg, f, def::RecordKeyword)
    report_keyword_warning(cfg, outer_data, def)
    record = read_record(f)
    if keyword_support(def) == :ignored
        return record
    end
    defaults = keyword_defaults(def, outer_data, units)
    values = isnothing(defaults) ? record : parse_defaulted_line(record, defaults)
    return data[String(keyword_name(def))] = values
end

function parse_keyword!(data, outer_data, units, cfg, f, def::RecordsKeyword)
    if keyword_support(def) != :ignored
        error("Missing parser for keyword $(keyword_name(def)).")
    end
    report_keyword_warning(cfg, outer_data, def)
    skip_record(f)
    return nothing
end

function parse_keyword!(data, outer_data, units, cfg, f, def::UnrecognizedKeyword)
    name = keyword_name(def)
    section = outer_data["CURRENT_SECTION"]
    if section == :REGIONS
        data[String(name)] = parse_and_set_grid_data!(data, outer_data, units, cfg, f, name, T = Int)
    elseif section in (:GRID, :EDIT, :SOLUTION)
        data[String(name)] = parse_and_set_grid_data!(data, outer_data, units, cfg, f, name, T = Float64)
    else
        error("Unhandled keyword $name in $section encountered.")
    end
    return data
end

keyword_units(::TracerProfileKeyword) = (:length, :id)
keyword_support(::UnsupportedTracerKeyword) = :ignored
keyword_warning(::UnsupportedTracerKeyword) = PARSER_MISSING_SUPPORT

function parse_keyword!(data, outer_data, units, cfg, f, def::TracerProfileKeyword)
    name = String(keyword_name(def))
    values = parse_deck_vector(f)
    if !isempty(values) && all(iszero, values)
        # Some exported decks write one zero per layer for a zero profile.
        data[name] = [0.0 0.0; 1.0 0.0]
        if isodd(length(values))
            parser_message(cfg, outer_data, name, "Interpreting an all-zero record as a uniform zero tracer profile.", important = true)
        end
    else
        @assert iseven(length(values)) && length(values) >= 4 "$name requires depth/concentration pairs."
        table = permutedims(reshape(values, 2, :))
        swap_unit_system_axes!(table, units, keyword_units(def))
        @assert all(diff(table[:, 1]) .> 0) "$name depths must be increasing."
        data[name] = table
    end
    return data
end

function parse_keyword!(data, outer_data, units, cfg, f, def::UnsupportedTracerKeyword)
    report_keyword_warning(cfg, outer_data, def)
    read_record(f)
    return data
end

@keyword :CONTROL (:RUNSPEC, :GRID, :EDIT, :PROPS, :REGIONS, :SOLUTION, :SUMMARY, :SCHEDULE) FlagKeyword support = :section
@keyword :CONTROL (:SKIP, :ENDSKIP, :END) FlagKeyword support = :control
@keyword :CONTROL :INCLUDE RecordKeyword support = :control
