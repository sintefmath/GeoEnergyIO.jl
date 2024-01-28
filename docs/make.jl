using GeoEnergyIO
using Documenter

DocMeta.setdocmeta!(GeoEnergyIO, :DocTestSetup, :(using GeoEnergyIO); recursive=true)

makedocs(;
    modules=[GeoEnergyIO],
    authors="Olav Møyner <olav.moyner@gmail.com> and contributors",
    sitename="GeoEnergyIO.jl",
    format=Documenter.HTML(;
        canonical="https://moyner.github.io/GeoEnergyIO.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/moyner/GeoEnergyIO.jl",
    devbranch="main",
)
