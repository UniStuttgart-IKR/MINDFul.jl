using JSON, HTTP, Sockets, Oxygen, SwaggerMarkdown
using AttributeGraphs
#import .Server

function send_request(remotehandler::RemoteIBNFHandler, endpoint::String, data::Dict)
    #remotehandler=ibnf.ibnfhandlers[1]
    url = remotehandler.base_url * endpoint
    body = JSON.json(data)  
    headers = Dict("Content-Type" => "application/json") # "Content-Length" => string(length(body))) 
    println("Sending request to $url")
    println("Headers: $headers")
    println("Body: $body")
    response = HTTP.post(url, headers, body;  http_version=HTTP.Strings.HTTPVersion("1.0"))
    #return response.status, JSON.parse(String(response.body)) 
    return response
end



function start_ibn_server(myibnf::IBNFramework)
    sel_handler = myibnf.ibnfhandlers[1]
    base_url = sel_handler.base_url
    uri = HTTP.URI(base_url)
    ip_address = string(uri.host)
    port = parse(Int, uri.port)
    
    println("Starting server on $ip_address:$port")
    Server.serve(port=port, async=true, context=myibnf, serialize=false, swagger=true) 
        
end


#=function serialize_attributegraph(graph::AttributeGraphs.AttributeGraph)
    return Dict(
        "nodes" => collect(Graphs.vertices(graph)),  # Serialize nodes
        "edges" => [(e.src, e.dst) for e in Graphs.edges(graph)],  # Serialize edges
        #"attributes" => graph.attributes  # Serialize attributes
    )
end=#




#=function response(req::HTTP.Request, ibnf::IBNFramework, parsed_body::Dict)
    
    if req.target == "/api/ibnattributegraph"
        """ Handle request for IBN Attribute Graph """
        #graph = getibnag(ibnf)
        #serialized_graph = serialize_attributegraph(graph)
        #return HTTP.Response(200, JSON.json(serialized_graph))
    elseif req.target == "/api/compilation_algorithms"
        """ Handle request for compilation algorithms """
        compilation_algorithms = requestavailablecompilationalgorithms_term!()
        if compilation_algorithms !== nothing
            return HTTP.Response(200, JSON.json(compilation_algorithms))
        else
            return HTTP.Response(404, "Compilation algorithms not found")
        end
    elseif req.target == "/api/spectrum_availability"
            """ Handle request for link spectrum availability """
            #body = JSON.parse(String(req.body))
            ge_data = parsed_body["global_edge"]
            received_ge = GlobalEdge(
                GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
                GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
            )
            spectrum_availability = requestspectrumavailability_term!(ibnf, received_ge)
            if spectrum_availability !== nothing
                return HTTP.Response(200, JSON.json(spectrum_availability))
            else
                return HTTP.Response(404, "Spectrum availability not found")
            end
    else
        return HTTP.Response(404, "Not Found")
    end
end=#


#= function request(req::HTTP.Request, remoteibnf::IBNFramework, parsed_body::Dict)
    """ Handle request for IBN Attribute Graph """
    if req.target == "/api/ibnattributegraph"
        response = send_request(remoteibnf, "/api/ibnattributegraph", Dict("func" => "response"))
        if response.status == 200
            return HTTP.Response(response.body)
        else
            error("Failed to request atrribute graph")
        end 
    
    elseif req.target == "/api/compilation_algorithms"
        response = send_request(remoteibnf, "/api/compilation_algorithms", Dict("func" => "response"))
        if response.status == 200
            return HTTP.Response(response.body)
        else
            error("Failed to request compilation algorithms")
        end 
    
    elseif req.target == "/api/spectrum_availability"
        #body = JSON.parse(String(req.body))
        received_ge = parsed_body["global_edge"]
        
        response = send_request(remoteibnf, "/api/spectrum_availability", Dict("func" => "response", "global_edge" => received_ge))
        if response.status == 200
            return HTTP.Response(response.body)
        else
            error("Failed to request spectrum availability")
        end 
    else
        return HTTP.Response(404, "Not Found")
    end
end =#


#=""" function to start a REST API server for an IBNFramework"""
function start_ibn_server_1(myibnf::IBNFramework)
    sel_handler = myibnf.ibnfhandlers[1]
    base_url = sel_handler.handlerproperties.base_url
    uri = HTTP.URI(base_url)
    ip_address = string(uri.host)
    port = parse(Int, uri.port)
    #@show ip_address
    #@show port

    println("Starting server on $ip_address:$port")
    HTTP.serve!(ip_address, port) do req
        body = HTTP.payload(req)
        parsed_body = JSON.parse(String(body))
        #@show parsed_body
        #func_value = parsed_body["func"]
        #@show func_value
        #if func_value == "request"
        #    return request(req, remoteibnf, parsed_body)
        #else
        return response(req, myibnf, parsed_body)
        #end
    end
end=#




#=function start_ibn_server_2(myibnf::IBNFramework)
    sel_handler = myibnf.ibnfhandlers[1]
    base_url = sel_handler.handlerproperties.base_url
    uri = HTTP.URI(base_url)
    ip_address = string(uri.host)
    port = parse(Int, uri.port)
    
    api = router("/api", tags=["api endpoint"])
    
    @swagger """
    /api/compilation_algorithms: 
      post:
        description: Return the available compilation algorithms        
        responses:
          "200":
            description: Successfully returned the compilation algorithms.
    """
    @post api("/compilation_algorithms") function (req)
        compilation_algorithms = requestavailablecompilationalgorithms_term!()
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
        ibnf :: IBNFramework = context
        body = HTTP.payload(req)
        parsed_body = JSON.parse(String(body))
        ge_data = parsed_body["global_edge"]
        received_ge = GlobalEdge(
            GlobalNode(UUID(ge_data["src"]["ibnfid"]), ge_data["src"]["localnode"]),
            GlobalNode(UUID(ge_data["dst"]["ibnfid"]), ge_data["dst"]["localnode"])
        )
        spectrum_availability = requestspectrumavailability_term!(ibnf, received_ge)
        if spectrum_availability !== nothing
            return HTTP.Response(200, JSON.json(spectrum_availability))
        else
            return HTTP.Response(404, "Spectrum availability not found")
        end
    end

    info = Dict("title" => "MINDFul Api", "version" => "1.0.0")
    openApi = OpenAPI("3.0", info)
    swagger_document = build(openApi)
    # merge the SwaggerMarkdown schema with the internal schema
    mergeschema(swagger_document)
    
    println("Starting server on $ip_address:$port")
    serve(port=port, async=true, context=myibnf, serialize=false, swagger=true) 
        
end=#




