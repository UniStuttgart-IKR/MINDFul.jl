module Server
using Oxygen, HTTP, SwaggerMarkdown, JSON, UUIDs, Documenter
#using Oxygen: serve 
using MINDFul
const MINDF = MINDFul


module OxygenInstance using Oxygen; @oxidise end
import .OxygenInstance: @get, @put, @post, @delete, mergeschema, serve, router

export serve

    api = OxygenInstance.router("/api", tags=["api endpoint"])
    
    @swagger """
    /api/compilation_algorithms: 
      post:
        description: Return the available compilation algorithms        
        responses:
          "200":
            description: Successfully returned the compilation algorithms.
    """
    @post api("/compilation_algorithms") function (req)
        compilation_algorithms = MINDF.requestavailablecompilationalgorithms_term!()
        if compilation_algorithms !== nothing
            return HTTP.Response(200, JSON.json(compilation_algorithms))
        else
            return HTTP.Response(404, JSON.json(Dict("error" => "Compilation algorithms not found")))
        end
    end

    
    @swagger """
    /api/spectrum_availability:
      post:
        description: Return the spectrum availability
        requestBody:
          description: The global edge for which to check spectrum availability
          required: true
          content:
            application/json:
              schema:
                type: object
                properties:
                  src:
                    type: object
                    properties:
                      ibnfid:
                        type: string
                      localnode:
                        type: integer
                  dst:
                    type: object
                    properties:
                      ibnfid:
                        type: string
                      localnode:
                        type: integer
        responses:
          "200":
            description: Successfully returned the spectrum availability.
    """    
    @post "/api/spectrum_availability" function (req; context)
        #body = JSON.parse(String(req.body))
        ibnf :: MINDF.IBNFramework = context
        body = HTTP.payload(req)
        parsed_body = JSON.parse(String(body))
        ge_data = parsed_body["global_edge"]
        received_ge = MINDF.GlobalEdge(
            MINDF.GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
            MINDF.GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
        )
        spectrum_availability = MINDF.requestspectrumavailability_term!(ibnf, received_ge)
        if spectrum_availability !== nothing
            return HTTP.Response(200, JSON.json(spectrum_availability))
        else
            return HTTP.Response(404, "Spectrum availability not found")
        end
    end

    info = Dict("title" => "MINDFul Api", "version" => "1.0.0")
    openApi = OpenAPI("3.0", info)
    swagger_document = build(openApi)
    open("swagger.json", "w") do file
        JSON.print(file, swagger_document)
    end
    println("Swagger documentation saved to swagger.json")
    # merge the SwaggerMarkdown schema with the internal schema
    OxygenInstance.mergeschema(swagger_document)

end