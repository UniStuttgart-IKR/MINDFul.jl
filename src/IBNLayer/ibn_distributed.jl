using JSON, HTTP 
using AttributeGraphs

function send_request(handler::RemoteIBNFHandler, endpoint::String, data::Dict)
    url = handler.ibnfcomm.base_url * endpoint
    body = JSON.json(data)  # Serialize data to JSON
    headers = Dict("Content-Type" => "application/json") 
    response = HTTP.post(url, body; headers=headers)
    return response.status, JSON.parse(String(response.body))  # Return status and parsed response
end


"""function Base.show(io::IO, graph::AttributeGraphs.AttributeGraph)
    JSON.print(io, Dict(
        "nodes" => Graphs.vertices(graph.graph),  # Serialize nodes
        "edges" => [(e.src, e.dst) for e in Graphs.edges(graph.graph)],  # Serialize edges
        "attributes" => graph.attributes  # Serialize attributes
    ))
end"""

function serialize_attributegraph(graph::AttributeGraphs.AttributeGraph)
    return Dict(
        "nodes" => collect(Graphs.vertices(graph)),  # Serialize nodes
        "edges" => [(e.src, e.dst) for e in Graphs.edges(graph)],  # Serialize edges
        #"attributes" => graph.attributes  # Serialize attributes
    )
end


# function to start a REST API server for an IBNFramework
function start_ibn_server(ibnf::IBNFramework, port::Int)
    HTTP.serve!("127.0.0.1", port) do req
        if req.target == "/api/ibnattributegraph"
            # Handle request for IBN Attribute Graph
            graph = getibnag(ibnf)
            serialized_graph = serialize_attributegraph(graph)
            return HTTP.Response(200, JSON.json(serialized_graph))
        else
            return HTTP.Response(404, "Not Found")
        end
    end

end
