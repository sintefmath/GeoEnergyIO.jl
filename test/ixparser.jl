using Test
using GeoEnergyIO
using Dates
using Jutul
using LinearAlgebra

import GeoEnergyIO.IXParser:
    IXStandardRecord,
    IXEqualRecord,
    IXKeyword,
    IXFunctionCall,
    IXSimulationRecord,
    IXIncludeRecord,
    IXExtensionRecord,
    parse_ix_record,
    read_afi_file,
    restructure_and_convert_units_afi

@testset "IXParser" begin
    teststr = """
    MyKw "SomeText" {
        array_name [1 2 3]
    }
    """

    t = parse_ix_record(teststr)

    @test t isa IXStandardRecord
    @test t.keyword == "MyKw"
    @test t.value == "SomeText"
    @test t.body[1] isa IXEqualRecord
    @test t.body[1].keyword == "array_name"
    @test t.body[1].value == [1, 2, 3]

    teststr = """
    MyKw "SomeText" {
        array_name "NAMED" [1 2 3]
    }
    """

    t = parse_ix_record(teststr)
    @test t isa IXStandardRecord
    @test t.keyword == "MyKw"
    @test t.value == "SomeText"
    @test t.body[1] isa IXStandardRecord
    @test t.body[1].keyword == "array_name"
    @test t.body[1].value == "NAMED"
    @test t.body[1].body == [1, 2, 3]

    teststr = """
    MyKw "SomeText" {
        AllowState = TRUE
    }
    """
    t = parse_ix_record(teststr)
    @test t isa IXStandardRecord
    @test t.keyword == "MyKw"
    @test t.value == "SomeText"
    @test t.body[1] isa IXEqualRecord
    @test t.body[1].keyword == "AllowState"
    @test t.body[1].value == true

    teststr = """
    WellDef "MYWELL-1" {
        Undefined=TRUE
        PseudoPressureModel=NONE
        AllowCrossFlow=TRUE
        HeadDensityCalculation=SEGMENTED
    }
    """
    t = parse_ix_record(teststr)
    @test length(t.body) == 4
    @test t.body[1] == IXEqualRecord("Undefined", true)
    @test t.body[2] == IXEqualRecord("PseudoPressureModel", nothing)
    @test t.body[3] == IXEqualRecord("AllowCrossFlow", true)
    @test t.body[4] == IXEqualRecord("HeadDensityCalculation", IXKeyword("SEGMENTED"))
    @test t.keyword == "WellDef"
    @test t.value == "MYWELL-1"

    teststr = """
    ####
    WellDef "MYWELL-1" {
        Undefined=TRUE
        ResVolConditions  {
            Method=RESERVOIR
        }
        # A comment
        PseudoPressureModel=NONE
        AllowCrossFlow=TRUE
        HeadDensityCalculation=SEGMENTED
    }
    """
    t = parse_ix_record(teststr)

    @test t.keyword == "WellDef"
    @test t.value == "MYWELL-1"
    @test t.body[1] == IXEqualRecord("Undefined", true)
    @test t.body[2].keyword == "ResVolConditions"
    @test t.body[2].value == [IXEqualRecord("Method", IXKeyword("RESERVOIR"))]
    @test t.body[3] == IXEqualRecord("PseudoPressureModel", nothing)
    @test t.body[4] == IXEqualRecord("AllowCrossFlow", true)
    @test t.body[5] == IXEqualRecord("HeadDensityCalculation", IXKeyword("SEGMENTED"))

    teststr = """
    WellDef "ORIGEN_PROD-1" {
        WellToCellConnections  [
            Cell         Completion        SegmentNode    Status    
            (1 2 3)      "COMPLETION1"     1              OPEN      
            (5 5 20)      "COMPLETION2"     1              OPEN      
            (3 99 7)      "COMPLETION3"     1              OPEN
        ]
    }
    """
    t = parse_ix_record(teststr)
    ix_endl = GeoEnergyIO.IXParser.IXArrayEndline()
    @test t.keyword == "WellDef"
    @test t.value == "ORIGEN_PROD-1"
    bdy = t.body[1]
    @test bdy isa IXEqualRecord
    @test bdy.keyword == "WellToCellConnections"
    @test bdy.value[1] == IXKeyword("Cell")
    @test bdy.value[2] == IXKeyword("Completion")
    @test bdy.value[3] == IXKeyword("SegmentNode")
    @test bdy.value[4] == IXKeyword("Status")
    @test bdy.value[5] == ix_endl
    @test bdy.value[6] == (1, 2, 3)
    @test bdy.value[7] == "COMPLETION1"
    @test bdy.value[8] == 1
    @test bdy.value[9] == GeoEnergyIO.IXParser.IX_OPEN
    @test bdy.value[10] == ix_endl
    @test bdy.value[11] == (5, 5, 20)
    @test bdy.value[12] == "COMPLETION2"
    @test bdy.value[13] == 1
    @test bdy.value[14] == GeoEnergyIO.IXParser.IX_OPEN
    @test bdy.value[15] == ix_endl
    @test bdy.value[16] == (3, 99, 7)
    @test bdy.value[17] == "COMPLETION3"
    @test bdy.value[18] == 1
    @test bdy.value[19] == GeoEnergyIO.IXParser.IX_OPEN

    teststr = """
    MODEL_DEFINITION
    """
    t = parse_ix_record(teststr)
    @test t == IXKeyword("MODEL_DEFINITION")

    teststr = """
    DATE "01-Jan-2020"
    """
    t = parse_ix_record(teststr)
    @test t == IXEqualRecord("DATE", "01-Jan-2020")

    teststr = """
    ###############################
    # MY COMMENT 123.4
    ###############################
    MODEL_DEFINITION

    START

    DATE "01-Jan-2016"

    """
    t = parse_ix_record(teststr)

    t.children == [
        IXKeyword("MODEL_DEFINITION"),
        IXKeyword("START"),
        IXEqualRecord("DATE", "01-Jan-2016")
    ]

    teststr = """
    WellDef "SOMEWELL-1" {
        WellToCellConnections  {
            PressureEquivalentRadius=[]
            Skin=[0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0]
            PermeabilityThickness=[]
        }
    }
    """
    t = parse_ix_record(teststr)
    @test t isa IXStandardRecord
    @test t.keyword == "WellDef"
    @test t.value == "SOMEWELL-1"
    @test length(t.body) == 1
    @test t.body[1] isa IXEqualRecord
    @test t.body[1].keyword == "WellToCellConnections"
    @test t.body[1].value[1].keyword == "PressureEquivalentRadius"
    @test length(t.body[1].value[1].value) == 0

    teststr = """
    WellDef "NAME" {
        one_function(cells=[(1 2 1) (2 3 1) (3 1 2)])
        function_name(cells=[(88 2 1) (99 5 1)])
    }
    """

    t = parse_ix_record(teststr)
    @test t isa IXStandardRecord
    @test t.keyword == "WellDef"
    @test t.value == "NAME"
    @test length(t.body) == 2
    @test t.body[1] isa IXFunctionCall
    @test t.body[1].keyword == "one_function"
    @test t.body[1].args[1] isa IXEqualRecord
    @test t.body[1].args[1].keyword == "cells"
    @test t.body[1].args[1].value == [(1, 2, 1), (2, 3, 1), (3, 1, 2)]
    @test t.body[2] isa IXFunctionCall
    @test t.body[2].keyword == "function_name"
    @test t.body[2].args[1] isa IXEqualRecord
    @test t.body[2].args[1].keyword == "cells"
    @test t.body[2].args[1].value == [(88, 2, 1), (99, 5, 1)]

    teststr = """
    Simulation FM "CaseName" {  
        INCLUDE "INCLUDE_DIR/TESTFILE.ixf" 
        INCLUDE "MODEL_Field_management.ixf" { type="epc" epc_type="props" resqml_type="props"  }
        EXTENSION "custom_scripts"
    }
    """
    t = parse_ix_record(teststr)

    @test t isa IXSimulationRecord
    @test t.keyword == "FM"
    @test t.casename == "CaseName"
    @test t.arg[1] isa IXIncludeRecord
    @test t.arg[1].filename == "INCLUDE_DIR/TESTFILE.ixf"
    @test t.arg[2] isa IXIncludeRecord
    @test t.arg[2].filename == "MODEL_Field_management.ixf"
    @test t.arg[2].options["type"] == "epc"
    @test t.arg[2].options["epc_type"] == "props"
    @test t.arg[2].options["resqml_type"] == "props"
    @test t.arg[3] == IXExtensionRecord("custom_scripts")

    teststr = """
    Simulation IX {  
        INCLUDE "INCLUDE_DIR/TESTFILE.ixf"
    }
    """
    t = parse_ix_record(teststr)
    @test t isa IXSimulationRecord
    @test t.keyword == "IX"
    @test ismissing(t.casename)
    @test t.arg[1] isa IXIncludeRecord
    @test t.arg[1].filename == "INCLUDE_DIR/TESTFILE.ixf"

    teststr = """
    Simulation  {
        StartDay=1
        StartMonth=JANUARY
        StartYear=2016
        PhasesPresent=[OIL WATER]
        StartHour=0
        StartMinute=0
        StartSecond=0
    }
    """
    t = parse_ix_record(teststr)
    @test t isa IXEqualRecord
    @test t.keyword == "Simulation"
    @test length(t.value) == 7
    @test t.value[1] == IXEqualRecord("StartDay", 1)
    @test t.value[2] == IXEqualRecord("StartMonth", IXKeyword("JANUARY"))
    @test t.value[3] == IXEqualRecord("StartYear", 2016)
    @test t.value[4].keyword == "PhasesPresent"
    @test t.value[4].value[1] == IXKeyword("OIL")
    @test t.value[4].value[2] == IXKeyword("WATER")
    @test t.value[5] == IXEqualRecord("StartHour", 0)
    @test t.value[6] == IXEqualRecord("StartMinute", 0)
    @test t.value[7] == IXEqualRecord("StartSecond", 0)

    teststr = """
    Group "GROUP 1" {
        remove_all_constraints_except(constraint_ids=[DRAWDOWN_PIW MAX_DRAWDOWN])
        Constraints=[ADD (900 OIL_PRODUCTION_RATE) (150 BOTTOM_HOLE_PRESSURE)]
        Members=[Well("Well1" "Well2" "CleverlyNamedWell")]
    }
    """
    t = parse_ix_record(teststr)

    @test t isa IXStandardRecord
    @test t.keyword == "Group"
    @test t.value == "GROUP 1"
    @test length(t.body) == 3
    @test t.body[1] isa IXFunctionCall
    @test t.body[1].keyword == "remove_all_constraints_except"
    @test t.body[1].args[1] isa IXEqualRecord
    @test t.body[1].args[1].keyword == "constraint_ids"
    @test t.body[1].args[1].value == [IXKeyword("DRAWDOWN_PIW"), IXKeyword("MAX_DRAWDOWN")]
    @test t.body[2] isa IXEqualRecord
    @test t.body[2].keyword == "Constraints"
    @test t.body[2].value[1] isa IXKeyword
    @test t.body[2].value[1] == IXKeyword("ADD")
    @test t.body[2].value[2] == (900, IXKeyword("OIL_PRODUCTION_RATE"))
    @test t.body[2].value[3] == (150, IXKeyword("BOTTOM_HOLE_PRESSURE"))
    @test t.body[3] isa IXEqualRecord
    @test t.body[3].keyword == "Members"
    # TODO: Here it is a bit strange since it splits up what should maybe be a group
    # representing Well("Well1", "Well2", "CleverlyNamedWell").
    @test t.body[3].value[1] == IXKeyword("Well")
    @test t.body[3].value[2] == ("Well1", "Well2", "CleverlyNamedWell")
    teststr = """
    GuideRateBalanceAction "FIELD_HGC" {
        TopGroup=Group('FIELD')
        Constraints=[ADD "Expression('FIELD_LPR_HGC')"]
        set_independent_entities(entities=[Group('FIELD')] allocations=[PRODUCTION] flag=FALSE)
    }

    """
    t = parse_ix_record(teststr)

    @test t isa IXStandardRecord
    @test t.keyword == "GuideRateBalanceAction"
    @test t.value == "FIELD_HGC"
    @test length(t.body) == 3
    fcall = t.body[1]
    @test fcall isa IXEqualRecord
    @test fcall.keyword == "TopGroup"
    @test fcall.value isa IXFunctionCall# ("Group", Any[IXKeyword("FIELD")])
    @test fcall.value.keyword == "Group"
    @test fcall.value.args[1] isa IXKeyword
    @test fcall.value.args[1] == IXKeyword("FIELD")


    teststr = """
    Group "FIELD" {
        Members=[Group('GROUP 1')]
    }
    """
    t = parse_ix_record(teststr)
    @test t isa IXStandardRecord
    @test t.keyword == "Group"
    @test t.value == "FIELD"
    @test length(t.body) == 1
    @test t.body[1] isa IXEqualRecord
    @test t.body[1].keyword == "Members"
    @test t.body[1].value[1] isa IXKeyword
    @test t.body[1].value[1] == IXKeyword("Group")
    @test t.body[1].value[2] == (IXKeyword("GROUP 1"), )

    # TODO: This part strips whitespace which is not ideal if this is a Python
    # script, but the Python scripting seems to use IX internal functions, so
    # there most important is that it doesn't crash the parser and that we can
    # see that something is there.
    teststr = """
    CustomControl "Somefunction_name" {
        Script=@{
    date=str(FieldManagement().CurrentDate)
    date=date[1:-1]
    if len(date)>1:
        date_formatted = datetime.strptime(date, 123)
    else:
        date_formatted = datetime.strptime(date, 123)
    _wellList=Well('*')
        }@
    }
    """
    t = parse_ix_record(teststr)
    @test t isa IXStandardRecord
    @test t.keyword == "CustomControl"
    @test t.value == "Somefunction_name"
    @test length(t.body) == 1
    @test t.body[1] isa IXEqualRecord
    @test t.body[1].keyword == "Script"

    @testset "newline-replacement" begin
        text = "Some text before.[\nContent\n of the section.\n]\nText after. Second region here.[Another\nsection\nhere.]End."
        new_text = GeoEnergyIO.IXParser.replace_square_bracketed_newlines(text)
        ref_text = "Some text before.[Content NEWLINE  of the section.]\nText after. Second region here.[Another NEWLINE section NEWLINE here.]End."
        @test new_text == ref_text

        text = """
        MODEL_DEFINITION

        StructuredInfo "CoarseGrid" {
            FirstCellId=1
            NumberCellsInI=10
            NumberCellsInJ=10
            NumberCellsInK=10
            UUID="UUID-GOES-HERE"
        }
        Units  {
            UnitSystem=ECLIPSE_METRIC
        }

        Simulation  {
            StartDay=1
            StartMonth=JANUARY
            StartYear=2030
            PhasesPresent=[OIL WATER]
            StartHour=0
            StartMinute=0
            StartSecond=0
        }
        """

        new_text = GeoEnergyIO.IXParser.replace_square_bracketed_newlines(text, "")
        @test new_text == text

        text = """
        FluidStream "S1" {
            Enthalpy=FluidEnthalpy("E 1")
            TracerConcentrations=[DoubleProperty(1 TRACER_CONCENTRATION['WI'])]
            Sources=[FluidSourceExternal("FSE 1")]
        }
        """
        new_text = GeoEnergyIO.IXParser.replace_square_bracketed_newlines(text)
        ref_text = "FluidStream \"S1\" {\n    Enthalpy=FluidEnthalpy(\"E 1\")\n    TracerConcentrations=[DoubleProperty(1 TRACER_CONCENTRATION['WI'])]\n    Sources=[FluidSourceExternal(\"FSE 1\")]\n}\n"
        @test new_text == ref_text

        text = """
        FluidStream "S1" {
            Enthalpy=FluidEnthalpy("E 1")
            TracerConcentrations=[
                1
                2
                3
            ]
            Sources=[FluidSourceExternal("FSE 1")]
        }
        """
        new_text = GeoEnergyIO.IXParser.replace_square_bracketed_newlines(text)
        ref_text = "FluidStream \"S1\" {\n    Enthalpy=FluidEnthalpy(\"E 1\")\n    TracerConcentrations=[        1 NEWLINE         2 NEWLINE         3 NEWLINE     ]\n    Sources=[FluidSourceExternal(\"FSE 1\")]\n}\n"
        @test new_text == ref_text
    end

    # Multiple entries in standard record
    teststr = """
    Well "Well1" "Well1"  "Well2" "Well3" {
        HistoricalControlModes=[RES_VOLUME_INJECTION_RATE]
        AutomaticClosureBehavior=ALL_COMPLETIONS_SHUTIN
        Status=ALL_COMPLETIONS_SHUTIN 
        Type= WATER_INJECTOR 
        Status = OPEN
    }
    """

    s = GeoEnergyIO.IXParser.parse_ix_record(teststr)

    @test s.value == ["Well1", "Well1", "Well2", "Well3"]
    @test s.body[1] isa GeoEnergyIO.IXParser.IXEqualRecord
    @test s.body[1].keyword == "HistoricalControlModes"
    # Check pathological group with no spaces
    teststr = """
    Well "Well1"	"Well1"  "Well2""Well3"	 {
        HistoricalControlModes=[RES_VOLUME_INJECTION_RATE]
        AutomaticClosureBehavior=ALL_COMPLETIONS_SHUTIN
        Status=ALL_COMPLETIONS_SHUTIN 
        Type= WATER_INJECTOR 
        Status = OPEN
    }
    """

    s = GeoEnergyIO.IXParser.parse_ix_record(teststr)

    @test s.value == ["Well1", "Well1", "Well2", "Well3"]
    @test s.body[1] isa GeoEnergyIO.IXParser.IXEqualRecord
    @test s.body[1].keyword == "HistoricalControlModes"

    @testset "assignment" begin
        teststr = """
        WellDef "WNAME" {         
            WellToCellConnections { 
                Status[1]=OPEN  
                PiMultiplier[1]=1.0  
                Status[2]=OPEN  
                PiMultiplier[2]=1.0  
            }
            AllowCrossFlow=TRUE
        }
        """

        s = GeoEnergyIO.IXParser.parse_ix_record(teststr)
        @test s isa GeoEnergyIO.IXParser.IXStandardRecord
        @test s.keyword == "WellDef"
        @test s.value == "WNAME"
        @test length(s.body) == 2
        @test s.body[1] isa GeoEnergyIO.IXParser.IXEqualRecord
        @test s.body[1].keyword == "WellToCellConnections"
        @test s.body[1].value[1] == GeoEnergyIO.IXParser.IXAssignmentRecord("Status", 1, GeoEnergyIO.IXParser.IX_OPEN)
        @test s.body[1].value[2] == GeoEnergyIO.IXParser.IXAssignmentRecord("PiMultiplier", 1, 1.0)
        @test s.body[1].value[3] == GeoEnergyIO.IXParser.IXAssignmentRecord("Status", 2, GeoEnergyIO.IXParser.IX_OPEN)
        @test s.body[1].value[4] == GeoEnergyIO.IXParser.IXAssignmentRecord("PiMultiplier", 2, 1.0)

        @test s.body[2] isa GeoEnergyIO.IXParser.IXEqualRecord
        @test s.body[2].keyword == "AllowCrossFlow"
        @test s.body[2].value == true

        teststr = """
        Well "W1" "W2""W3"  {
            HistoricalControlModes=[RES_VOLUME_PRODUCTION_RATE ]
            AutomaticClosureBehavior=SURFACE_SHUTIN
            Constraints[BOTTOM_HOLE_PRESSURE]=100.0
            Type=PRODUCER 
            Status = ALL_COMPLETIONS_SHUTIN
        
        }
        """
        t = parse_ix_record(teststr)
        @test t.body[3] isa GeoEnergyIO.IXParser.IXAssignmentRecord
        @test t.body[3].keyword == "Constraints"
        @test t.body[3].index == "BOTTOM_HOLE_PRESSURE"
        @test t.body[3].value == 100.0

        teststr = """
        FluidSourceExternal "FluidSource1" {
            Phase=WATER
            AvailableRate=DoubleProperty(0 WATER_FLOW_RATE)
            Enthalpy=FluidEnthalpy("EH1")
        }
        """
        t = parse_ix_record(teststr)
        @test t isa GeoEnergyIO.IXParser.IXStandardRecord
        @test t.keyword == "FluidSourceExternal"
        @test t.value == "FluidSource1"
        @test length(t.body) == 3
        @test t.body[1] isa GeoEnergyIO.IXParser.IXEqualRecord
        @test t.body[1].keyword == "Phase"
        @test t.body[1].value == IXKeyword("WATER")

        @test t.body[2] isa GeoEnergyIO.IXParser.IXEqualRecord
        @test t.body[2].keyword == "AvailableRate"
        @test t.body[2].value isa GeoEnergyIO.IXParser.IXDoubleProperty
        @test t.body[2].value.value == 0.0
        @test t.body[2].value.name == "WATER_FLOW_RATE"

        @test t.body[3] isa GeoEnergyIO.IXParser.IXEqualRecord
        @test t.body[3].keyword == "Enthalpy"
        @test t.body[3].value isa GeoEnergyIO.IXParser.IXLookupRecord
        @test t.body[3].value.name == "FluidEnthalpy"
        @test t.body[3].value.key == "EH1"

        @testset "DoubleProperty with lookup" begin
            teststr = """
            FluidStream "S1" {
                Enthalpy=FluidEnthalpy("E 1")
                TracerConcentrations=[DoubleProperty(1 TRACER_CONCENTRATION['WI'])]
                Sources=[FluidSourceExternal("FSE 1")]
            }
            """
            s = GeoEnergyIO.IXParser.parse_ix_record(teststr)
            @test s isa GeoEnergyIO.IXParser.IXStandardRecord
            @test s.keyword == "FluidStream"
            @test s.value == "S1"
            @test length(s.body) == 3
            @test s.body[1] isa GeoEnergyIO.IXParser.IXEqualRecord
            @test s.body[1].keyword == "Enthalpy"
            @test s.body[1].value isa GeoEnergyIO.IXParser.IXLookupRecord
            @test s.body[1].value.name == "FluidEnthalpy"
            @test s.body[1].value.key == "E 1"

            @test s.body[2] isa GeoEnergyIO.IXParser.IXEqualRecord
            @test s.body[2].keyword == "TracerConcentrations"
            @test s.body[2].value isa Vector
            @test length(s.body[2].value) == 1
            @test s.body[2].value[1] isa GeoEnergyIO.IXParser.IXDoubleProperty
            @test s.body[2].value[1].value == 1.0
            @test s.body[2].value[1].name == GeoEnergyIO.IXParser.IXLookupRecord("TRACER_CONCENTRATION", "WI")

            teststr = """
            FluidStream "S1" {
                TracerConcentrations=DoubleProperty(1 TRACER_CONCENTRATION['WI'])
            }
            """
            s = GeoEnergyIO.IXParser.parse_ix_record(teststr)
            @test s isa GeoEnergyIO.IXParser.IXStandardRecord
            @test s.keyword == "FluidStream"
            @test s.value == "S1"
            @test length(s.body) == 1
            @test s.body[1] isa GeoEnergyIO.IXParser.IXEqualRecord
            @test s.body[1].keyword == "TracerConcentrations"
            @test s.body[1].value isa GeoEnergyIO.IXParser.IXDoubleProperty
            @test s.body[1].value.value == 1.0
            @test s.body[1].value.name == GeoEnergyIO.IXParser.IXLookupRecord("TRACER_CONCENTRATION", "WI")
        end
    end

    @testset "repeats" begin
        teststr = """
        StraightPillarGrid "CoarseGrid" {
            Units="ECLIPSE_FIELD"
            DeltaX = [
                1.0 1.0 1.0 1.0 1.0
            ]
            CellDoubleProperty "PERM_I" {
                Values=[ 0.1 0.1 0.1 0.1 0.1]
            }
        }
        """
        function test_repeat_kw(x)
            @test x isa GeoEnergyIO.IXParser.IXStandardRecord
            @test x.keyword == "StraightPillarGrid"
            @test x.value == "CoarseGrid"
            @test length(x.body) == 3
            @test x.body[1] isa GeoEnergyIO.IXParser.IXEqualRecord
            @test x.body[1].keyword == "Units"
            @test x.body[1].value == "ECLIPSE_FIELD"
            @test x.body[2] isa GeoEnergyIO.IXParser.IXEqualRecord
            @test x.body[2].keyword == "DeltaX"
            @test x.body[2].value[1:5] == [1.0, 1.0, 1.0, 1.0, 1.0]
            @test x.body[3] isa GeoEnergyIO.IXParser.IXStandardRecord
            @test x.body[3].keyword == "CellDoubleProperty"
            @test x.body[3].value == "PERM_I"
            @test length(x.body[3].body) == 1
            @test x.body[3].body[1] isa GeoEnergyIO.IXParser.IXEqualRecord
            @test x.body[3].body[1].keyword == "Values"
            @test x.body[3].body[1].value[1:5] == [0.1, 0.1, 0.1, 0.1, 0.1]
        end


        s1 = GeoEnergyIO.IXParser.parse_ix_record(teststr)
        test_repeat_kw(s1)

        teststr = """
        StraightPillarGrid "CoarseGrid" {
            Units="ECLIPSE_FIELD"
            DeltaX = [
                1.0 1.0 1.0 1.0 1.0
            ]
            CellDoubleProperty "PERM_I" {
                Values=[ 0.1 3*0.1 0.1]
            }
        }
        """

        s2 = GeoEnergyIO.IXParser.parse_ix_record(teststr)
        test_repeat_kw(s2)

        teststr = """
        StraightPillarGrid "CoarseGrid" {
            Units="ECLIPSE_FIELD"
            DeltaX = [
                1.0 1.0 1.0 1.0 1.0
            ]
            CellDoubleProperty "PERM_I" {
                Values=[ 5*0.1]
            }
        }
        """
        s3 = GeoEnergyIO.IXParser.parse_ix_record(teststr)
        test_repeat_kw(s3)
    end

    @testset "DateTime formatting" begin
        function testdate(s, ref)
            rec = GeoEnergyIO.IXParser.IXEqualRecord("DATE", s)
            return GeoEnergyIO.IXParser.time_from_record(rec, missing, missing) == ref
        end
        teststr = "1-Dec-2020 "
        @test testdate(teststr, DateTime(2020, 12, 1))
        teststr = "1-Dec-2020"
        @test testdate(teststr, DateTime(2020, 12, 1))
        teststr = " 1-Dec-2020"
        @test testdate(teststr, DateTime(2020, 12, 1))
        teststr = "1-Dec-2020 "
        @test testdate(teststr, DateTime(2020, 12, 1))

        teststr = "1-Dec-2020 01:10:00.984000"
        @test testdate(teststr, DateTime(2020, 12, 1, 1, 10, 0, 984))

        teststr = "1-Dec-2020 01:10:00"
        @test testdate(teststr, DateTime(2020, 12, 1, 1, 10, 0))


        testdate("01-Jan-2020", Dates.DateTime(2020, 1, 1)),
        testdate("1-Dec-2020 01:10:00.10000", Dates.DateTime(2020, 12, 1, 1, 10, 0, 100)),
        testdate("01-Apr-2027", Dates.DateTime(2027, 4, 1)),
        testdate("01-Jan-1994 01:10:00", Dates.DateTime(1994, 1, 1, 1, 10, 0)),
        testdate("01-Mar-1994 03:16:56.507232", Dates.DateTime(1994, 3, 1, 3, 16, 56, 507))

    end

    @testset "SPE9" begin
        fn = GeoEnergyIO.test_input_file_path("SPE9_AFI_GSG", "SPE9_clean_split.afi")
        setup = read_afi_file(fn, verbose = false, convert = true)
        # Check that we have 91 times defined (=90 timesteps)
        @test length(setup["FM"]["STEPS"]) == 91
        # Check that all timesteps are 10 days
        steps = collect(keys(setup["FM"]["STEPS"]))
        dt = map(x -> x.value, diff(steps))
        @test all(dt .≈ 864000000)
    end

    @testset "OLYMPUS_25" begin
        fn = GeoEnergyIO.test_input_file_path("OLYMPUS_25_AFI_RESQML", "OLYMPUS_25.afi")
        setup = read_afi_file(fn, verbose = false, convert = true)
        # Check that we have 241 times defined (=240 timesteps)
        @test length(setup["FM"]["STEPS"]) == 241

        resqml = setup["IX"]["RESQML"]
        for k in ["ACTIVE_CELL_FLAG", "NET_TO_GROSS_RATIO", "POROSITY", "SATURATION_FUNCTION_DRAINAGE_TABLE_NO", "PERM_I", "PERM_J", "PERM_K"]
            @test haskey(resqml, k)
            @test size(resqml[k]["values"]) == (118, 181, 16)
            is_disc = k in ["ACTIVE_CELL_FLAG", "SATURATION_FUNCTION_DRAINAGE_TABLE_NO"]
            @test is_disc == resqml[k]["is_discrete"]
            @test is_disc == !resqml[k]["is_continuous"]
        end
        gj = mesh_from_grid_section(setup["IX"]["RESQML"]["GRID"])

        @test number_of_cells(gj) == 192750
        @test number_of_faces(gj) == 552227
        @test number_of_boundary_faces(gj) == 63773

        geo = Jutul.tpfv_geometry(gj)
        @test all(geo.volumes .> 0.0)
        @test all(geo.areas .> 0.0)
        @test all(geo.boundary_areas .> 0.0)
        # Check orientation of face normals (left/right-handedness)
        for face in 1:number_of_faces(gj)
            c1, c2 = geo.neighbors[:, face]
            n = geo.normals[:, face]
            vec = geo.cell_centroids[:, c2] - geo.cell_centroids[:, c1]
            @test dot(n, vec) > 0.0
        end
    end
end

