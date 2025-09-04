using Test
using GeoEnergyIO

import GeoEnergyIO.IXParser:
    IXStandardRecord,
    IXEqualRecord,
    IXKeyword,
    IXFunctionCall,
    IXSimulationRecord,
    IXIncludeRecord,
    IXExtensionRecord,
    parse_ix_record


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
    @test t.keyword == "WellDef"
    @test t.value == "ORIGEN_PROD-1"
    bdy = t.body[1]
    @test bdy isa IXEqualRecord
    @test bdy.keyword == "WellToCellConnections"
    @test bdy.value[1] == IXKeyword("Cell")
    @test bdy.value[2] == IXKeyword("Completion")
    @test bdy.value[3] == IXKeyword("SegmentNode")
    @test bdy.value[4] == IXKeyword("Status")
    @test bdy.value[5] == (1, 2, 3)
    @test bdy.value[6] == "COMPLETION1"
    @test bdy.value[7] == 1
    @test bdy.value[8] == GeoEnergyIO.IXParser.IX_OPEN
    @test bdy.value[9] == (5, 5, 20)
    @test bdy.value[10] == "COMPLETION2"
    @test bdy.value[11] == 1
    @test bdy.value[12] == GeoEnergyIO.IXParser.IX_OPEN
    @test bdy.value[13] == (3, 99, 7)
    @test bdy.value[14] == "COMPLETION3"
    @test bdy.value[15] == 1
    @test bdy.value[16] == GeoEnergyIO.IXParser.IX_OPEN

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
end
