module InputParser
    using Parsers, DelimitedFiles, Jutul, OrderedCollections, Dates, LinearAlgebra
    export parse_data_file
    @enum PARSER_WARNING PARSER_MISSING_SUPPORT PARSER_JUTULDARCY_MISSING_SUPPORT PARSER_JUTULDARCY_PARTIAL_SUPPORT PARSER_PARTIAL_SUPPORT
    const KEYWORD_SKIP_LIST = Tuple{Symbol, Union{Float64, Int}, Union{PARSER_WARNING, Nothing}}[]

    include("parser.jl")
    include("units.jl")
    include("utils.jl")
    include("keywords/keywords.jl")

    function __init__()
        # Keywords with a single line
        skip_kw!(:PETOPTS, 1)
        skip_kw!(:PARALLEL, 1)
        skip_kw!(:MULTSAVE, 1)
        skip_kw!(:VECTABLE, 1)
        skip_kw!(:MULTSAVE, 1)
        skip_kw!(:WHISTCTL, 1, PARSER_JUTULDARCY_MISSING_SUPPORT)
        skip_kw!(:MEMORY, 1)
        skip_kw!(:OPTIONS3, 1)
        skip_kw!(:TSCRIT, 1, PARSER_JUTULDARCY_MISSING_SUPPORT)
        skip_kw!(:CVCRIT, 1, PARSER_JUTULDARCY_MISSING_SUPPORT)
        skip_kw!(:RPTPRINT, 1)
        skip_kw!(:GUIDERAT, 1, PARSER_MISSING_SUPPORT)
        # Keywords without data (i.e. just the name)
        skip_kw!(:MULTOUT, 0)
        skip_kw!(:NOSIM, 0)
        skip_kw!(:NOINSPEC, 0)
        skip_kw!(:NORSSPEC, 0)
        skip_kw!(:NOWARN, 0)
        skip_kw!(:NOWARNEP, 0)
        skip_kw!(:NOHYKR, 0)
        skip_kw!(:NOMIX, 0)
        skip_kw!(:FILLEPS, 0)
        skip_kw!(:NPROCX, 0)
        skip_kw!(:NPROCY, 0)
        skip_kw!(:NONNC, 0)
        skip_kw!(:NEWTRAN, 0)
        skip_kw!(:RPTGRID, 1)
        skip_kw!(:RPTINIT, 1)
        skip_kw!(:DIFFUSE, 0, PARSER_JUTULDARCY_MISSING_SUPPORT)
        skip_kw!(:OLDTRAN, 0, PARSER_JUTULDARCY_MISSING_SUPPORT)
        skip_kw!(:UNIFSAVE, 0)
        skip_kw!(:SATOPTS, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:EQLOPTS, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:TRACERS, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:PIMTDIMS, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:FLUXNUM, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:OPTIONS, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:ZIPPY2, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:DRSDT, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:WPAVE, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:VAPPARS, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:RESTART, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:NETBALAN, 1, PARSER_MISSING_SUPPORT)
        skip_kw!(:JFUNC, 1, PARSER_MISSING_SUPPORT)
        # Keywords with any number of records, terminated by empty records
        for kw in [
                :WSEGSICD,
                :WSEGVALS,
                :WSEGAICD,
                :WPAVEDEP,
                :WTEST,
                :WECON,
                :WGRUPCON,
                :WSEGVALVS,
                :GCONPROD,
                :GEFAC,
                :GCONSUMP,
                :PSPLITX,
                :PSPLITY,
                :PSPLITZ,
                :COMPLUMP,
                :TRACER,
                :THPRES,
                :PIMULTAB,
                :VFPPROD,
                :VFPINJ,
                :WTRACER,
                :GCONINJE,
                :WTEST,
                :WLIST,
            ]
            skip_kw!(kw, Inf, PARSER_MISSING_SUPPORT)
        end
    end
end
