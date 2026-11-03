using GeoEnergyIO
using Documenter

DocMeta.setdocmeta!(GeoEnergyIO, :DocTestSetup, :(using GeoEnergyIO); recursive=true)

makedocs(;
    modules=[GeoEnergyIO],
    authors="Olav Møyner <olav.moyner@gmail.com> and contributors",
    sitename="GeoEnergyIO.jl",
    format=Documenter.HTML(;
        canonical="https://sintefmath.github.io/GeoEnergyIO.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "parser.md",
        "cpgrid.md",
        "standard_io.md",
        "resdata.md",
    ],
)

deploydocs(;
    repo="github.com/sintefmath/GeoEnergyIO.jl",
    devbranch="main",
)
