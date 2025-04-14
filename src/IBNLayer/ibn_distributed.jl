using JSON, HTTP 
using AttributeGraphs

function send_request(ibnf::IBNFramework, endpoint::String, data::Dict)
    remotehandler=ibnf.ibnfhandlers[1]
    url = remotehandler.handlerproperties.base_url * endpoint
    body = JSON.json(data)  
    headers = Dict("Content-Type" => "application/json") 
    response = HTTP.post(url, body; headers=headers)
    #return response.status, JSON.parse(String(response.body)) 
    return response
end


#function Base.show(io::IO, graph::AttributeGraphs.AttributeGraph)
#    JSON.print(io, Dict(
#        "nodes" => Graphs.vertices(graph.graph),  # Serialize nodes
#        "edges" => [(e.src, e.dst) for e in Graphs.edges(graph.graph)],  # Serialize edges
#        "attributes" => graph.attributes  # Serialize attributes
#    ))
#end

function serialize_attributegraph(graph::AttributeGraphs.AttributeGraph)
    return Dict(
        "nodes" => collect(Graphs.vertices(graph)),  # Serialize nodes
        "edges" => [(e.src, e.dst) for e in Graphs.edges(graph)],  # Serialize edges
        #"attributes" => graph.attributes  # Serialize attributes
    )
end


""" function to start a REST API server for an IBNFramework"""
function start_ibn_server(ibnf::IBNFramework)
    sel_handler = ibnf.ibnfhandlers[1]
    base_url = sel_handler.handlerproperties.base_url
    uri = HTTP.URI(base_url)
    ip_address = string(uri.host)
    port = parse(Int, uri.port)
    #@show ip_address
    #@show port

    HTTP.serve!(ip_address, port) do req
        if req.target == "/api/ibnattributegraph"
            """ Handle request for IBN Attribute Graph """
            graph = getibnag(ibnf)
            serialized_graph = serialize_attributegraph(graph)
            return HTTP.Response(200, JSON.json(serialized_graph))
        elseif req.target == "/api/compilation_algorithms"
            """ Handle request for compilation algorithms """
            compilation_algorithms = requestavailablecompilationalgorithms_term!(ibnf)
            if compilation_algorithms !== nothing
                return HTTP.Response(200, JSON.json(compilation_algorithms))
            else
                return HTTP.Response(404, "Compilation algorithms not found")
            end
        else
            return HTTP.Response(404, "Not Found")
        end
    end
end




""" function to start a REST API server for an IBNFramework"""
function start_ibn_server_ge(ibnf::IBNFramework, ge::GlobalEdge)
    sel_handler = ibnf.ibnfhandlers[1]
    base_url = sel_handler.handlerproperties.base_url
    uri = HTTP.URI(base_url)
    ip_address = string(uri.host)
    port = parse(Int, uri.port)
    #@show ip_address
    #@show port

    HTTP.serve!(ip_address, port) do req
        if req.target == "/api/spectrum_availability"
            """ Handle request for link spectrum availability """
            spectrum_availability = requestspectrumavailability_term!(ibnf, ge)
            if spectrum_availability !== nothing
                return HTTP.Response(200, JSON.json(spectrum_availability))
            else
                return HTTP.Response(404, "Spectrum availability not found")
            end
        else
            return HTTP.Response(404, "Not Found")
        end
    end
end
