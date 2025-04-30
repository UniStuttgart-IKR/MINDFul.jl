# for importing TestModule
using Test, JET

using Documenter, MINDFul, JSON

makedocs(
    format = Documenter.HTML(; size_threshold=1_000_000),
    sitename = "MINDFul.jl",
    modules = [MINDFul],
    pages = [
        "Introduction" => "index.md",
        "Developing" => "dev.md",
        "ROADMap" => "roadmap.md",
        "API" => "API.md",
        "HTTP API" => [
            "HTTP" => "HTTP.md",
            "OxygenInstance" => "OxygenInstance.md",
        ],
    ],

)

open("swagger.json", "w") do file
    swagger_document = MINDFul.Server.OxygenInstance.getschema()
    JSON.print(file, swagger_document)
end


deploydocs(
    repo = "https://github.com/UniStuttgart-IKR/MINDFul.jl.git",
)
