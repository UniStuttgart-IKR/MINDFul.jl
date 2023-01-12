using Documenter, MINDFul

makedocs(sitename="MINDFul.jl",
    pages = [
        "Introduction" => "index.md",
        "Usage and Examples" => "usage.md",
        "Roadmap" => "roadmap.md",
        "API" => "API.md"
    ])

 deploydocs(
     repo = "github.com/UniStuttgart-IKR/MINDFul.jl.git",
 )
