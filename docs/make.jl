using Documenter, MINDFul

makedocs(
    format = Documenter.HTML(; size_threshold=1_000_000),
    sitename = "MINDFul.jl",
    modules = [MINDFul],
    pages = [
        "Introduction" => "index.md",
        "Developing" => "dev.md",
        "ROADMap" => "roadmap.md",
        "API" => "API.md",
    ],
)
