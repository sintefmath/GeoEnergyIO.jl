# Deck keyword reference

This reference lists the explicit keyword definitions in GeoEnergyIO's
`.DATA` and GRDECL parser. The section headings group related definitions.
Some keywords may appear in more than one deck section.

- **Parsed** means GeoEnergyIO interprets the keyword and applies its parsing rules.
- **Flag** means the keyword is recorded as present.
- **Raw record** means the input is retained as text records.
- **Partial** means the parser interprets part of the keyword.
- **Ignored** means the parser recognizes or consumes the keyword and discards its contents.

The last column lists explicit support warnings that the parser may emit.
Solver support refers to JutulDarcy. The `SUMMARY` section is skipped by
`parse_data_file` by default.

A single record is terminated by `/` and can span several physical lines.
A list of records typically ends with an empty `/` record. For regional
tables, the number of tables or records comes from the deck dimensions.

```@eval
using GeoEnergyIO, Markdown
const Parser = GeoEnergyIO.InputParser

layouts = Dict(
    :none => "No data",
    :single => "Single record",
    :text => "Single text line",
    :terminated => "Record list",
    :regional => "Regional records",
    :saturation => "Saturation-region tables",
    :dependent => "Count derived from input",
)
support = Dict(
    :parsed => "Parsed",
    :flag => "Flag",
    :raw => "Raw record",
    :partial => "Partial",
    :ignored => "Ignored",
    :section => "Section header",
    :control => "Parser directive",
)
warnings = Dict(
    nothing => "—",
    Parser.PARSER_MISSING_SUPPORT => "Missing parser support",
    Parser.PARSER_PARTIAL_SUPPORT => "Partial parser support",
    Parser.PARSER_JUTULDARCY_MISSING_SUPPORT => "Missing solver support",
    Parser.PARSER_JUTULDARCY_PARTIAL_SUPPORT => "Partial solver support",
)
sections = [
    :CONTROL => "Parser directives and section headers",
    :RUNSPEC => "RUNSPEC",
    :GRID => "GRID",
    :EDIT => "EDIT",
    :PROPS => "PROPS",
    :REGIONS => "REGIONS",
    :SOLUTION => "SOLUTION",
    :SCHEDULE => "SCHEDULE",
    :SUMMARY => "SUMMARY",
    :SKIPPED => "Other recognized keywords",
]
names = sort!(collect(keys(Parser.KEYWORD_SECTIONS)))
tables = String[]
for (section, title) in sections
    push!(tables, "## $title", "", "| Keyword | Input layout | Parser behavior | Support warning |",
        "|:--------|:-------------|:----------------|:----------------|")
    for name in names
        Parser.KEYWORD_SECTIONS[name] == section || continue
        Parser.keyword_start(String(name)) == name || continue
        def = Parser.keyword_definition(Val(name))
        layout = Parser.keyword_layout(def)
        format = layout isa Int ? "$layout records" : layouts[layout]
        behavior = support[Parser.keyword_support(def)]
        warning = warnings[Parser.keyword_warning(def)]
        push!(tables, "| `$name` | $format | $behavior | $warning |")
    end
    push!(tables, "")
end
Markdown.parse(join(tables, '\n'))
```

## Keyword families and limits

- `SWOF`, `SGOF`, `SLGOF`, `SWFN`, `SGFN` and `GSF` convert the capillary
  pressure column. The first saturation-region table must be supplied. An
  empty table for a subsequent region inherits the preceding table.
- `TVDPF*` headers accept depth and tracer-concentration pairs or an all-zero
  profile. Other `TVDP*` headers are consumed with an unsupported-keyword warning.
- Unlisted headers in `GRID`, `EDIT` and `SOLUTION` fall back to numeric grid
  arrays. Unlisted headers in `REGIONS` fall back to integer grid arrays.
- `TUNING` reads three records and keeps the timestep and convergence settings.
  JutulDarcy uses a subset of those settings.
- `MINPORV`, `RTEMPA`, `TEMPVD` and `WELLTARG` use the output keys `MINPV`,
  `RTEMP`, `RTEMPVD` and `WELTARG`, respectively.
- The deck lexer stops at punctuation in keyword headers. Directional
  spellings ending in `-` currently resolve to the same name as their
  unsuffixed spelling.

## Inspecting a definition

The registry is available under `GeoEnergyIO.InputParser`.

```@docs
GeoEnergyIO.InputParser.keyword_definition
```

```@example
using GeoEnergyIO
parser = GeoEnergyIO.InputParser
pinch = parser.keyword_definition(Val(:PINCH))
(parser.keyword_defaults(pinch), parser.keyword_units(pinch), parser.keyword_layout(pinch))
```
