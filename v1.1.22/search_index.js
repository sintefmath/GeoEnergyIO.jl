var documenterSearchIndex = {"docs":
[{"location":"resdata/#resdata-extension:-Dealing-with-summary,-restart-and-egrid-files","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"","category":"section"},{"location":"resdata/#Input-and-output-using-resdata-package","page":"resdata extension: Dealing with summary, restart and egrid files","title":"Input and output using resdata package","text":"","category":"section"},{"location":"resdata/","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"The Python package resdata developed by Equinor can be loaded to add support for reading summary files (sparse data), egrid (processed grid), init (initial conditions) and restart (cell-wise results).","category":"page"},{"location":"resdata/","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"note: resdata is GPL-3.0 licensed\nThe resdata package is under a different license than GeoEnergyIO which uses MIT. The licenses are compatible, but a distributed product that contains resdata must comply with the terms of the GPL license.","category":"page"},{"location":"resdata/","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"To add support for this extension, you have to add PythonCall to your environment (one-time operation):","category":"page"},{"location":"resdata/","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"using Pkg\nPkg.add(\"PythonCall\")","category":"page"},{"location":"resdata/","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"Afterwards, you can then load the package to get access to the new functions:","category":"page"},{"location":"resdata/","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"using PythonCall","category":"page"},{"location":"resdata/#Reading-output","page":"resdata extension: Dealing with summary, restart and egrid files","title":"Reading output","text":"","category":"section"},{"location":"resdata/","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"read_restart\nread_init\nread_egrid\nread_summary","category":"page"},{"location":"resdata/#GeoEnergyIO.read_restart","page":"resdata extension: Dealing with summary, restart and egrid files","title":"GeoEnergyIO.read_restart","text":"restart = read_restart(fn)\nrestart, raw_restart = read_restart(fn, extra_out = true)\n\nRead a restart file from fn. This should be the base path (i.e. without the .RSRT extension). The results are given as a Vector of Dicts.\n\nKeyword arguments\n\nextra_out: If true, return the raw Python object as well as the parsed data. Default is false.\nactnum=missing: ACTNUM array that can be used to reduce the outputs to the active cells.\negrid=missing: EGRID object needed to read the restarts. Will be read from the same path as fn if not provided.\n\nNotes\n\nThis function requires the resdata Python package to be installed, which will be automatically added to your environment if you first install PythonCall and put using PythonCall in your script or REPL.\n\nThe main class to lookup on the Python side of things is ResdataRestartFile.\n\n\n\n\n\n","category":"function"},{"location":"resdata/#GeoEnergyIO.read_init","page":"resdata extension: Dealing with summary, restart and egrid files","title":"GeoEnergyIO.read_init","text":"init = read_init(fn)\ninit, raw_init = read_init(fn, extra_out = true)\n\nRead a init file from fn. This should be the base path (i.e. without the .RSRT extension). The results are given as a Dict.\n\nKeyword arguments\n\nextra_out: If true, return the raw Python object as well as the parsed data. Default is false.\nactnum=missing: ACTNUM array that can be used to reduce the outputs to the active cells.\n\nNotes\n\nThis function requires the resdata Python package to be installed, which will be automatically added to your environment if you first install PythonCall and put using PythonCall in your script or REPL.\n\nThe main class to lookup on the Python side of things is ResdataFile.\n\n\n\n\n\n","category":"function"},{"location":"resdata/#GeoEnergyIO.read_egrid","page":"resdata extension: Dealing with summary, restart and egrid files","title":"GeoEnergyIO.read_egrid","text":"egrid = read_egrid(pth)\negrid, raw_egrid = read_egrid(pth, extra_out = true)\n\nRead the EGRID file from pth. The results are given as a Dict and can be passed further on to mesh_from_grid_section to construct a Jutul mesh.\n\nNotes\n\nThis function requires the resdata Python package to be installed, which will be automatically added to your environment if you first install PythonCall and put using PythonCall in your script or REPL.\n\nUses primarily resdata.grid.Grid.\n\n\n\n\n\n","category":"function"},{"location":"resdata/#GeoEnergyIO.read_summary","page":"resdata extension: Dealing with summary, restart and egrid files","title":"GeoEnergyIO.read_summary","text":"summary = read_summary(pth)\nsummary, raw_summary = read_summary(pth, extra_out = true)\n\nRead the SUMMARY file from pth. The results are given as a Dict.\n\nNotes\n\nThis function requires the resdata Python package to be installed, which will be automatically added to your environment if you first install PythonCall and put using PythonCall in your script or REPL.\n\nUses primarily resdata.summary.Summary.\n\n\n\n\n\n","category":"function"},{"location":"resdata/#Writing-output","page":"resdata extension: Dealing with summary, restart and egrid files","title":"Writing output","text":"","category":"section"},{"location":"resdata/","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"warning: Experimental features\nWriting files is currently highly experimental. Not all fields are properly set in summary files (e.g. units).","category":"page"},{"location":"resdata/","page":"resdata extension: Dealing with summary, restart and egrid files","title":"resdata extension: Dealing with summary, restart and egrid files","text":"GeoEnergyIO.write_egrid\nGeoEnergyIO.write_jutuldarcy_summary","category":"page"},{"location":"resdata/#GeoEnergyIO.write_egrid","page":"resdata extension: Dealing with summary, restart and egrid files","title":"GeoEnergyIO.write_egrid","text":"write_egrid(case::JutulCase, pth)\n\nWrite an EGRID file from a JutulCase from JutulDarcy.jl. This is a convenience function that will extract the reservoir domain and input data from the case. It is assumed that the case has been set up from a data file so that the mesh matches the GRID section.\n\n\n\n\n\nwrite_egrid(reservoir::DataDomain, data::Dict, pth)\n\nWrite EGRID from a reservoir/DataDomain from JutulDarcy.jl that has been constructed from a data file.\n\n\n\n\n\nwrite_egrid(G::UnstructuredMesh, data::Dict, pth)\n\nWrite EGRID from UnstructuredMesh that was constructed from the GRID section of the data file.\n\n\n\n\n\nwrite_egrid(data::AbstractDict, pth)\n\nWrite EGRID from a Dict that has been parsed from a data file. Can be either the GRID section or the full data file.\n\n\n\n\n\n","category":"function"},{"location":"resdata/#GeoEnergyIO.write_jutuldarcy_summary","page":"resdata extension: Dealing with summary, restart and egrid files","title":"GeoEnergyIO.write_jutuldarcy_summary","text":"write_jutuldarcy_summary(filename, smry_jutul; unified = true)\n\nExperimental function to write a summary file from JutulDarcy results.\n\n\n\n\n\n","category":"function"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = GeoEnergyIO","category":"page"},{"location":"#GeoEnergyIO","page":"Home","title":"GeoEnergyIO","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for GeoEnergyIO. See the subpages on the left for more details on functionality.","category":"page"},{"location":"#Internals","page":"Home","title":"Internals","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"GeoEnergyIO.InputParser.keyword_default_value","category":"page"},{"location":"#GeoEnergyIO.InputParser.keyword_default_value","page":"Home","title":"GeoEnergyIO.InputParser.keyword_default_value","text":"keyword_default_value(x::AbstractString, T::Type)\n\nGet the default value of a keyword (as String or ::Val{X} where X is a Symbol) when placed in a array with element type T. This is used to initialize defaulted entries when using COPY, ADD, MULTIPLY and so on.\n\n\n\n\n\n","category":"function"},{"location":"#Index-of-functions","page":"Home","title":"Index of functions","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"parser/#Parsing-of-simulation-cases","page":"Parsing of simulation cases","title":"Parsing of simulation cases","text":"","category":"section"},{"location":"parser/","page":"Parsing of simulation cases","title":"Parsing of simulation cases","text":"The most significant feature of this module is a parser for .DATA reservoir simulation cases. The format originated with the Eclipse reservoir simulator produced by SLB and is now used by many reservoir simulators. The most useful publicly available description of one such dialect is found in the OPM Flow manual.","category":"page"},{"location":"parser/","page":"Parsing of simulation cases","title":"Parsing of simulation cases","text":"parse_data_file","category":"page"},{"location":"parser/#GeoEnergyIO.InputParser.parse_data_file","page":"Parsing of simulation cases","title":"GeoEnergyIO.InputParser.parse_data_file","text":"parse_data_file(filename; units = :si)\nparse_data_file(filename; units = :field)\ndata = parse_data_file(\"MY_MODEL.DATA\")\n\nParse a .DATA file given by the path in filename (industry standard input file) into a Dict with String keys. Units will be converted to strict SI unless you pass an alternative unit system like units = :field. Setting units = nothing will skip unit conversion. Note that the simulators in JutulDarcy.jl assumes that the unit system is internally consistent. It is highly recommended to parse to the SI units if you want to perform simulations with JutulDarcy.jl.\n\nThe best publicly available documentation on this format is available from the Open Porous Media (OPM) project's webpages: OPM Flow manual .\n\nKeyword arguments\n\nwarn_parsing=true: Produce a warning when keywords are not supported (or partially supported) by the parser.\nwarn_feature=true: Produce a warning when keywords are supported, but have limited or missing support in the numerical solvers in JutulDarcy.jl.\nunits=:si: Symbol that indicates the unit system to be used in the output. Setting this to nothing will return values without conversion, i.e. exactly what is in the input files. :si will use strict SI. Other alternatives are :field and :metric. :lab is currently unsupported.\nverbose=false: Produce verbose output about parsing progress. For larger files, a lot of output will be generated. Useful when figuring out where a parser fails or spends a lot of time.\n\nNote\n\nThis function only covers a small portion of the keywords that exist for various simulators. You will get warnings that indicate the level of support for keywords in both the parser and the numerical solvers when known keywords with limited support. Pull requests for new keywords are welcome!\n\nThe SUMMARY section is skipped due to the large volume of available keywords that are not essential to define simulation cases.\n\n\n\n\n\n","category":"function"},{"location":"parser/","page":"Parsing of simulation cases","title":"Parsing of simulation cases","text":"Let us for example parse the SPE1 dataset, turning into a nested Dict containing all the entries of the data file. We use the unexported test_input_file_path utility to get the path of a test file.","category":"page"},{"location":"parser/","page":"Parsing of simulation cases","title":"Parsing of simulation cases","text":"using GeoEnergyIO\nspe1_pth = GeoEnergyIO.test_input_file_path(\"SPE1\", \"SPE1.DATA\")\nspe1 = parse_data_file(spe1_pth)","category":"page"},{"location":"parser/#Handling-unsupported-keywords","page":"Parsing of simulation cases","title":"Handling unsupported keywords","text":"","category":"section"},{"location":"parser/","page":"Parsing of simulation cases","title":"Parsing of simulation cases","text":"Not all keywords are supported by the parser, but not all keywords are important. The input format is such that it is difficult to automatically skip keywords, but you an manually add keywords to the skip list:","category":"page"},{"location":"parser/","page":"Parsing of simulation cases","title":"Parsing of simulation cases","text":"GeoEnergyIO.InputParser.skip_kw!","category":"page"},{"location":"parser/#GeoEnergyIO.InputParser.skip_kw!","page":"Parsing of simulation cases","title":"GeoEnergyIO.InputParser.skip_kw!","text":"skip_kw!(kw, num, msg = nothing)\n\nAdd a keyword to list of records that will be skipped on parsing.\n\nkw is the symbol (usually capitalized) of the keyword to skip, num is the number of expected records:\n\n0 means that the keyword to skip has no data (for example \"WATER\" with no data to follow)\n1 means that the keyword has a single record terminated by /\nAny other number means a fixed number of lines, without termination by empty record.\nInf means that the keyword has any number of records, terminated by a record without entries.\n\n\n\n\n\n","category":"function"},{"location":"parser/","page":"Parsing of simulation cases","title":"Parsing of simulation cases","text":"Adding keywords to the skip list is not persistent across Julia sessions and can be added to the top of your script. Contributions to the global skip list defined in the __init__ function of the parser are welcome.","category":"page"},{"location":"parser/","page":"Parsing of simulation cases","title":"Parsing of simulation cases","text":"using GeoEnergyIO\n# Skip keyword without data\nGeoEnergyIO.InputParser.skip_kw!(:MY_KW, 0)\n# Keyword with a single record of data, e.g.\n# MY_DATA_KW\n# \"some data\" 1 2 3 /\nGeoEnergyIO.InputParser.skip_kw!(:MY_DATA_KW, 1)\n# Keyword with many records, terminated by empty record:\n# MY_LONG_DATA_KW\n# \"some data\" 1 2 3 /\n# \"more data\" 4 5 6 /\n# \"even more data\" 1 9 /\n# /\nGeoEnergyIO.InputParser.skip_kw!(:MY_LONG_DATA_KW, Inf)","category":"page"},{"location":"cpgrid/#Parsing-and-processing-of-corner-point-grids","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"","category":"section"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"Corner-point meshes are the de-facto standard format for simulation of subsurface flow. These meshes are semi-structured, but can have quite complex structure in practice due to eroded and collapsed cells and the presence of faults. This module includes a processor to convert the input format into a mesh that can be used for simulation. Converting the corner-points into a mesh with a connected topology is non-trivial, but the included algorithm has been verified on a number of real-field assets.","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"There are two main functions to parse and process corner-point inputs:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"parse_grdecl_file\nmesh_from_grid_section","category":"page"},{"location":"cpgrid/#GeoEnergyIO.InputParser.parse_grdecl_file","page":"Parsing and processing of corner-point grids","title":"GeoEnergyIO.InputParser.parse_grdecl_file","text":"parse_grdecl_file(\"mygrid.grdecl\"; actnum_path = missing, kwarg...)\n\nParse a GRDECL file separately from the full input file. Note that the GRID section does not contain units - passing the input_units keyword is therefore highly recommended.\n\nKeyword arguments\n\nactnum_path=missing: Path to ACTNUM file, if this is not included in the main file.\nunits=:si: Units to use for return values. Requires input_units to be set.\ninput_units=nothing: The units the file is given in.\nverbose=false: Toggle verbosity.\nextra_paths: List of extra paths to parse as a part of grid section, ex: [\"PORO.inc\", \"PERM.inc\"].\n\n\n\n\n\n","category":"function"},{"location":"cpgrid/#GeoEnergyIO.CornerPointGrid.mesh_from_grid_section","page":"Parsing and processing of corner-point grids","title":"GeoEnergyIO.CornerPointGrid.mesh_from_grid_section","text":"mesh_from_grid_section(f, actnum = missing, repair_zcorn = true, process_pinch = false)\n\nGenerate a Jutul unstructured mesh from a grid section. The input arugment f can be one of the following:\n\n(1) An already parsed complete data file read using parse_data_file. The \"GRID\" field will be used.\n(2) A parsed \"GRID\" section from parse_grdecl_file.\n(3) The file-name of a .GRDECL file to be parsed before processing.\n\nOptionally the actnum can be specified separately. The actnum should have equal length to the number of logical cells in the grid with true/false indicating if a cell is to be included in the processed mesh.\n\nThe additional argument repair_zcorn only applies when the grid is defined using COORD/ZCORN arrays. If set to true, the monotonicity of the ZCORN coordinates in each corner-point pillar will be checked and optionally fixed prior to mesh construction. Note that if non-monotone ZCORN are fixed, if the first input argument to this function is an already parsed data structure, the ZCORN array will be mutated during fixing to avoid a copy.\n\n\n\n\n\n","category":"function"},{"location":"cpgrid/#Example-corner-point-meshes","page":"Parsing and processing of corner-point grids","title":"Example corner point meshes","text":"","category":"section"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"The module ships with several corner point grids suitable for testing. These include partially collapsed cells, faults and other degenerate cases that the parser should be able to handle. We can make a few plots of such test grids. The first example is a single hexahedral cell:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"using GeoEnergyIO, Jutul, GLMakie\npth = GeoEnergyIO.test_input_file_path(\"grdecl\", \"1cell.txt\")\ngrdecl = parse_grdecl_file(pth)\ng = mesh_from_grid_section(grdecl)\nfig, ax, plt = plot_mesh(g)\nJutul.plot_mesh_edges!(ax, g)\nfig","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"To understand a bit more of how this format behaves in practice, we can look at a faulted mesh:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"using GeoEnergyIO, Jutul, GLMakie\npth = GeoEnergyIO.test_input_file_path(\"grdecl\", \"raised_col_sloped.txt\")\ngrdecl = parse_grdecl_file(pth)\ng = mesh_from_grid_section(grdecl)\nfig, ax, plt = plot_mesh(g)\nJutul.plot_mesh_edges!(ax, g)\nfig","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"More complicated meshes include multiple faults. One synthetic test model is the model3 case from MRST:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"using GeoEnergyIO, Jutul, GLMakie\npth = GeoEnergyIO.test_input_file_path(\"grdecl\", \"model3_5_5_5.txt\")\ngrdecl = parse_grdecl_file(pth)\ng = mesh_from_grid_section(grdecl)\nix = collect(1:number_of_cells(g))\nfig = Figure()\nax = Axis3(fig[1,1], zreversed = true, azimuth = 2.0)\nplot_cell_data!(ax, g, ix, colormap = :seaborn_icefire_gradient)\nfig","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"We can also parse a high-resolution version of the same case:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"using GeoEnergyIO, Jutul, GLMakie\npth = GeoEnergyIO.test_input_file_path(\"grdecl\", \"model3_20_20_50.txt\")\ngrdecl = parse_grdecl_file(pth)\ng = mesh_from_grid_section(grdecl)\nix = collect(1:number_of_cells(g))\nfig = Figure()\nax = Axis3(fig[1,1], zreversed = true, azimuth = 2.0)\nplot_cell_data!(ax, g, ix, colormap = :seaborn_icefire_gradient)\nfig","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"The parser has been tested on many complex models. Here is an example mesh parsed from the OLYMPUS Optimization Benchmark Challenge where the parsed porosity is plotted together with the wells:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"(Image: image)","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"We can parse this mesh in the same manner as before:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"using GeoEnergyIO, Jutul, GLMakie\npth = GeoEnergyIO.test_input_file_path(\"OLYMPUS_1\", \"OLYMPUS_GRID.GRDECL\")\ngrdecl = parse_grdecl_file(pth)\ng = mesh_from_grid_section(grdecl)\nix = collect(1:number_of_cells(g))\nfig = Figure()\nax = Axis3(fig[1,1], zreversed = true, azimuth = 2.0)\nplot_cell_data!(ax, g, ix, colormap = :seaborn_icefire_gradient)\nfig","category":"page"},{"location":"cpgrid/#Generation-of-corner-point-meshes","page":"Parsing and processing of corner-point grids","title":"Generation of corner-point meshes","text":"","category":"section"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"The package also contains functionality for generating corner-point meshes.","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"cpgrid_from_horizons","category":"page"},{"location":"cpgrid/#GeoEnergyIO.CornerPointGrid.cpgrid_from_horizons","page":"Parsing and processing of corner-point grids","title":"GeoEnergyIO.CornerPointGrid.cpgrid_from_horizons","text":"cpgrid_from_horizons(X, Y, depths)\ncpgrid_from_horizons(X, Y, depths, (100, 100))\ncpgrid_from_horizons(X, Y, depths, sz = missing;\n    layer_width = 1,\n    transforms = [(x, y, z, x_c, y_c, i, j, k) -> z],\n    xy_transform = (x, y, i, j, z_t, z_b) -> (x, y, x, y)\n)\n\nCreate a CornerPointGrid from a set of horizons. The horizons are given as a set of 2D arrays, where each array represents the depth of a horizon at each point in the grid. The horizons must be the same size and will be used to create the top and bottom of each cell in the grid. At least two horizons must be provided, one for the top and one for the bottom of the grid, and additional horizons can be provided. If horizons intersect, the cells will be pinched so that the lowest horizon is preserved.\n\nThe grid will be created with the given X and Y coordinates which are vectors/ranges of equal length to the number of rows and columns in the depths arrays. The sz argument can be used to resample the grid to a different size in the I/J directions. If sz is not provided, the grid will have the same size as the horizons.\n\nKeyword arguments\n\nlayer_width: Number of cells inside each layer. Can be a single integer or an array of integers with the same length as the number of horizons/depths minus one. Default is 1, i.e. that each layer has one cell in the vertical direction.\ntransforms: A function or an array of functions that can be used to modify the depth of each cell. The function(s) should take the following arguments: x, y, z, x_c, y_c, i, j, k, where x, y and z are the coordinates of the point to be modified, x_c and y_c are the coordinates of the cell center that the point belongs to, i and j are the indices of the cell in the I/J directions, and k is the index of the cell in the K direction. The function(s) should return the new depth of the point.\nxy_transform: A function that can be used to modify the X and Y coordinates of each pillar. The function should take the following arguments: x, y, i, j, z_t, z_b, where x and y are the original X and Y coordinates of the line, i and j are the indices of the line in the I/J directions, and z_t and z_b are the top and bottom depths of the line. The function should return the new X and Y coordinates of the line.\n\n\n\n\n\n","category":"function"},{"location":"cpgrid/#Example-of-mesh-generation","page":"Parsing and processing of corner-point grids","title":"Example of mesh generation","text":"","category":"section"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"Let us look at how the corner-point generator can be used in practice. A common concept of horizons, a more or less continious surface where the litography changes significantly. Typically these horizons would come from data, but for the purpose of this example we will generate some noisy surfaces with different averages and trends. One matrix for the top surface, one for the middle and one for the bottom of our domain.","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"using GeoEnergyIO, Jutul, GLMakie\nnx = ny = 25\nLx = 1000.0\nLy = 800.0\nxrng = range(0.0, Lx, nx)\nyrng = range(0.0, Ly, ny)\ndepths = [\n    5 .*rand(nx, ny),\n    5 .*rand(nx, ny) .+ 30.0,\n    5 .*rand(nx, ny) .+ 100.0 .- xrng/Lx*40.0\n]\nfig = Figure()\nax = Axis3(fig[1, 1], zreversed = true)\ncolors = Makie.wong_colors()\nfor (c, layer) in enumerate(depths)\n    surface!(ax, xrng, yrng, layer, color = fill(colors[c], nx, ny), shading = NoShading)\nend\nfig\n","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"We generate a mesh based on these depth matrices for each horizon, creating two layers with three cells each, and turn the keyword Dict into a mesh:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"grd = cpgrid_from_horizons(xrng, yrng, depths, layer_width = 3)\nmesh = mesh_from_grid_section(grd)\nfig, ax, plt = plot_cell_data(mesh, grd[\"LAYERNUM\"][mesh.cell_map], colormap = :winter)\nJutul.plot_mesh_edges!(ax, mesh)\nfig","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"Let us say that the data was at a different resolution than what we want for our simulation mesh. We can increase or decrease the resolution by a third keyword argument, which will use linear interpolation to add additional points:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"grd = cpgrid_from_horizons(xrng, yrng, depths, (100, 100), layer_width = [20, 25])\nmesh2 = mesh_from_grid_section(grd)\nfig, ax, plt = plot_cell_data(mesh2, grd[\"LAYERNUM\"][mesh2.cell_map], colormap = :winter)\nJutul.plot_mesh_edges!(ax, mesh2)\nfig","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"We can also add various transforms to make the model complex. There are two types of supported transforms:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"Vertical transforms, which can be multiple transforms that change the depths of corner points based on the cell centroid and original corner points. These are typically used to create faults.\nPillar transforms, which can alter the top and bottom points of the pillars that define the corner point mesh. A single transform is supported at the time.","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"We will now do the following:","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"Introduce two faults, one sloping and one with fixed throw.\nAdd a pillar transform that makes the mesh smaller for increasing depth.","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"fault1 = (x, y, z, x_c, y_c, i, j, k) -> ifelse(x_c/Lx + 0.25*y_c/Ly > 0.5, z + 50.0.*(y/Ly) + 15.0, z)\nfault2 = (x, y, z, x_c, y_c, i, j, k) -> ifelse(y_c/Ly > 0.5, z + 25.0, z)\ntransforms = [fault1, fault2]\nxy_transform = (x, y, i, j, zt, zb) -> (x, y, 0.9*x, 0.8*y)\ngrd = cpgrid_from_horizons(xrng, yrng, depths,\n    layer_width = 3,\n    transforms = transforms,\n    xy_transform = xy_transform\n)\nmesh3 = mesh_from_grid_section(grd)\nfig, ax, plt = plot_cell_data(mesh3, grd[\"LAYERNUM\"][mesh3.cell_map], colormap = :winter)\nax.azimuth[] = 5.44\nJutul.plot_mesh_edges!(ax, mesh3)\nfig","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"We can also make cells inactive by setting NaN values in the depths. Note that as each entry in depths corresponds to the intersection between two layers, we set NaN in the top and bottom depths to impact the two layers separately. For more fine grained control, the \"ACTNUM\" array is also present and can be altered before mesh_from_grid_section is called.","category":"page"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"for i in 1:nx\n    for j in 1:ny\n        center_dist = sqrt((xrng[i] - 500)^2 + (yrng[j] - 400)^2)\n        if center_dist > 400\n            depths[1][i, j] = NaN\n        end\n        if center_dist > 500\n            depths[3][i, j] = NaN\n        end\n    end\nend\ngrd = cpgrid_from_horizons(xrng, yrng, depths, layer_width = [20, 25])\nmesh4 = mesh_from_grid_section(grd)\nfig, ax, plt = plot_cell_data(mesh4, grd[\"LAYERNUM\"][mesh4.cell_map], colormap = :winter)\nJutul.plot_mesh_edges!(ax, mesh4)\nfig","category":"page"},{"location":"cpgrid/#Utilities","page":"Parsing and processing of corner-point grids","title":"Utilities","text":"","category":"section"},{"location":"cpgrid/","page":"Parsing and processing of corner-point grids","title":"Parsing and processing of corner-point grids","text":"get_data_file_cell_region\nnumber_of_tables","category":"page"},{"location":"cpgrid/#GeoEnergyIO.InputParser.get_data_file_cell_region","page":"Parsing and processing of corner-point grids","title":"GeoEnergyIO.InputParser.get_data_file_cell_region","text":"region = get_data_file_cell_region(data, t::Symbol; active = nothing)\nsatnum = get_data_file_cell_region(data, :satnum)\npvtnum = get_data_file_cell_region(data, :pvtnum, active = 1:10)\n\nGet the region indicator of some type for each cell of the domain stored in data (the output from parse_data_file). The optional keyword argument active can be used to extract the values for a subset of cells.\n\nt should be one of the following:\n\n:satnum (saturation function region)\n:pvtnum (PVT function region)\n:eqlnum (equilibriation region)\n:eosnum (equation-of-state region)\n\n\n\n\n\n","category":"function"},{"location":"cpgrid/#GeoEnergyIO.InputParser.number_of_tables","page":"Parsing and processing of corner-point grids","title":"GeoEnergyIO.InputParser.number_of_tables","text":"number_of_tables(outer_data, t::Symbol)\n\nNumber of declared tables for given type t. Should be one of the following:\n\n:satnum (saturation function region)\n:pvtnum (PVT function region)\n:eqlnum (equilibriation region)\n:eosnum (equation-of-state region)\n\n\n\n\n\n","category":"function"}]
}
