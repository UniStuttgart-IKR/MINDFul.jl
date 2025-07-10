# for importing TestModule
using Test, JET

using Documenter, MINDFul, JSON, Oxygen


function generate_swagger_html(output_path::String, swagger_json_path::String)
    html_template = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Swagger UI</title>
        <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.8/swagger-ui.css">
    </head>
    <body>
        <div id="swagger-ui"></div>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.8/swagger-ui-bundle.js"></script>
        <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/5.11.8/swagger-ui-standalone-preset.js"></script>
        <script>
            window.onload = () => {
                const ui = SwaggerUIBundle({
                    url: "$swagger_json_path",
                    dom_id: '#swagger-ui',
                    presets: [
                        SwaggerUIBundle.presets.apis,
                        SwaggerUIStandalonePreset
                    ],
                    layout: "StandaloneLayout"
                });
                window.ui = ui;
            };
        </script>
    </body>
    </html>
    """
    open(output_path, "w") do file
        write(file, html_template)
    end
    println("Swagger HTML file generated at $output_path")
end



open(joinpath(@__DIR__, "src", "swagger.json"), "w") do file
    swagger_document = MINDFul.Server.OxygenInstance.getschema()
    JSON.print(file, swagger_document)
end

generate_swagger_html(joinpath(@__DIR__, "src", "swagger.html"), "swagger.json")


#=Documenter.HTML(assets = [
    asset("assets/swagger/swagger@5.7.2/swagger-ui-bundle.js", class=:js, islocal=true),
    #asset(joinpath(@__DIR__, "src/assets/swagger/swagger@5.7.2/swagger-ui-bundle.js"), class=:js, islocal=true),
])=#

makedocs(
    #checkdocs=:none,
    format = Documenter.HTML(; size_threshold=1_000_000),
    sitename = "MINDFul.jl",
    modules = [MINDFul],
    pages = [
        "Introduction" => "index.md",
        "Developing" => "dev.md",
        "ROADMap" => "roadmap.md",
        "API" => "API.md",
        "Distributed API" => [
            "HTTP" => "HTTP.md",
            "OxygenInstance" => "OxygenInstance.md",
            "Docker" => "Docker.md",
        ],
    ],

)




deploydocs(
    # devbranch = "ma1069",
    # repo = "github.com/fgobantes/MINDFul.jl.git"
    repo = "https://github.com/UniStuttgart-IKR/MINDFul.jl.git"
)
