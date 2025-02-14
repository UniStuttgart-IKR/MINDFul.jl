using Documenter, MINDFul

makedocs(
    sitename = "MINDFul.jl",
    modules = [MINDFul],
    pages = [
        "Introduction" => "index.md",
        "API" => "API.md",
    ],
)
