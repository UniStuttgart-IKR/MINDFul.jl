@recvtime function send_request(remotehandler::RemoteHTTPHandler, endpoint::String, data::Dict)
    url = remotehandler.baseurl * endpoint

    if isnothing(offsettime)
        push!(data, "offsettime" => "nothing")
    else
        push!(data, "offsettime" => string(@logtime))
    end
    body = JSON.json(data)  
    headers = Dict("Content-Type" => "application/json") # "Content-Length" => string(length(body)
    #println(" ")
    #println("SENDING REQUEST TO $url")
    
    #println("Headers: $headers")
    #println("Body: $body")

    #@show offsettime
    # @show typeof(offsettime)
    #@show @logtime
    # @show typeof(@logtime)
        
    response = HTTP.post(url, headers, body;  http_version=HTTP.Strings.HTTPVersion("1.0"))
    return response
end


function startibnserver!(myibnf::IBNFramework)
    sel_handler = myibnf.ibnfhandlers[1]
    baseurl = sel_handler.baseurl
    uri = HTTP.URI(baseurl)
    ip_address = string(uri.host)
    port = parse(Int, uri.port)
    
    println(" ")
    println("Starting server on $ip_address:$port")
    try
        Server.serve(port=port, async=true, context=myibnf, serialize=false, swagger=true, access_log=nothing)
    catch e
        if isa(e, Base.IOError)
            println("Server at $ip_address:$port is already running")
        else
            rethrow(e)  
        end
    end
end

function startibnserver!(ibnfs::Vector{<:IBNFramework})
    ibnfs_dict = Dict{Int, IBNFramework}()
    for ibnf in ibnfs 
        sel_handler = ibnf.ibnfhandlers[1]
        baseurl = sel_handler.baseurl
        uri = HTTP.URI(baseurl)
        port = parse(Int, uri.port)
        push!(ibnfs_dict, port => ibnf)
    end

    for ibnf in ibnfs
        sel_handler = ibnf.ibnfhandlers[1]
        baseurl = sel_handler.baseurl
        uri = HTTP.URI(baseurl)
        ip_address = string(uri.host)
        port = parse(Int, uri.port)
        
        println(" ")
        println("Starting server on $ip_address:$port")
        try
            Server.serve(port=port, async=true, context=ibnfs_dict, serialize=false, swagger=true, access_log=nothing) 
        catch e
            if isa(e, Base.IOError)
                println("Server at $ip_address:$port is already running")
            else
                rethrow(e)  
            end
        end     
    end
end



function serialize_globaledge(edge::GlobalEdge)
    return Dict(
        "src" => serialize_globalnode(edge.src),  # Serialize the source node
        "dst" => serialize_globalnode(edge.dst)   # Serialize the destination node
    )
end

function serialize_globalnode(node::GlobalNode)
    return Dict(
        "ibnfid" => string(node.ibnfid),  # Convert UUID to string
        "localnode" => node.localnode    # Keep localnode as Int64
    )
end


function serialize_connectivity_intent(intent::ConnectivityIntent)
    return Dict(
        "src" => serialize_globalnode(intent.sourcenode),
        "dst" => serialize_globalnode(intent.destinationnode),
        "rate" => string(intent.rate),
        "constraints" => [serialize_constraint(constraint) for constraint in intent.constraints]
    )
end

function serialize_constraint(constraint::AbstractIntentConstraint)
    if constraint isa OpticalInitiateConstraint
        return Dict(
            "type" => "OpticalInitiateConstraint",
            "globalnode_input" => serialize_globalnode(constraint.globalnode_input),
            "spectrumslotsrange" => [constraint.spectrumslotsrange.start, constraint.spectrumslotsrange.stop],
            "opticalreach" => string(constraint.opticalreach),
            "transmissionmodulecompat" => serialize_transmissionmodulecompatibility(constraint.transmissionmodulecompat)
        )
    elseif constraint isa OpticalTerminateConstraint
        return Dict(
            "type" => "OpticalTerminateConstraint"
        )
    else
        error("Unsupported constraint type: $(typeof(constraint))")
    end
end

function serialize_transmissionmodulecompatibility(transmissionmodulecompat::TransmissionModuleCompatibility)
    return Dict(
        "rate" => string(transmissionmodulecompat.rate),
        "spectrumslotsneeded" => transmissionmodulecompat.spectrumslotsneeded,
        "name" => transmissionmodulecompat.name,
    )
end

function serialize_lowlevelintent(ll)
    if ll isa OXCAddDropBypassSpectrumLLI
        return Dict(
            "type" => "OXCAddDropBypassSpectrumLLI",
            "node" => ll.localnode,
            "input" => ll.localnode_input,
            "adddropport" => ll.adddropport,
            "output" => ll.localnode_output,
            "slotstart" => ll.spectrumslotsrange.start,
            "slotend" => ll.spectrumslotsrange.stop,
        )
    elseif ll isa TransmissionModuleLLI
        return Dict(
            "type" => "TransmissionModuleLLI",
            "node" => ll.localnode,
            "poolindex" => ll.transmissionmoduleviewpoolindex,
            "modesindex" => ll.transmissionmodesindex,
            "port" => ll.routerportindex,
            "adddropport" => ll.adddropport
        )
    elseif ll isa RouterPortLLI
        return Dict(
            "type" => "RouterPortLLI",
            "node" => ll.localnode,
            "port" => ll.routerportindex
        )
    else
        error("Unknown LowLevelIntent type: $(typeof(ll))")
    end
end

function deserializelowlevelintent(dict)
    if dict["type"] == "OXCAddDropBypassSpectrumLLI"
        return MINDFul.OXCAddDropBypassSpectrumLLI(
            dict["node"], dict["input"], dict["adddropport"], dict["output"], dict["slotstart"]:dict["slotend"]
        )
    elseif dict["type"] == "TransmissionModuleLLI"
        return MINDFul.TransmissionModuleLLI(
            dict["node"], dict["poolindex"], dict["modesindex"], dict["port"], dict["adddropport"]
        )
    elseif dict["type"] == "RouterPortLLI"
        return MINDFul.RouterPortLLI(
            dict["node"], dict["port"]
        )
    else
        error("Unknown LowLevelIntent type: $(dict["type"])")
    end
end

function reconvert_constraint(constraint)
    if constraint["type"] == "OpticalInitiateConstraint"
        return OpticalInitiateConstraint(
            GlobalNode(UUID(constraint["globalnode_input"]["ibnfid"]), constraint["globalnode_input"]["localnode"]),
            constraint["spectrumslotsrange"][1]:constraint["spectrumslotsrange"][2],
            KMf(parse(Float64, replace(constraint["opticalreach"], " km" => ""))),
            TransmissionModuleCompatibility(GBPSf(parse(Float64, replace(constraint["transmissionmodulecompat"]["rate"], " Gbps" => ""))), constraint["transmissionmodulecompat"]["spectrumslotsneeded"], constraint["transmissionmodulecompat"]["name"])
        )
    elseif constraint["type"] == "OpticalTerminateConstraint"
        return nothing
    else
        error("Unknown constraint type")
    end
end

#=   function serialize_idag(idag)
    #@show typeof(idag)
    #@show idag.edge_list
    
    #@show idag.vertex_attr
    #@show idag.graph_attr
    @show idag.edge_attr
    return Dict(
        "graph" => serialize_simpledigraph(idag.graph),
        "nodes" => [serialize_intentdagnode(n) for n in idag.vertex_attr],
        "info" => serialize_idaginfo(idag.graph_attr)
    )
end

function serialize_simpledigraph(g)
    return Dict(
        "nv" => g.nv,
        "outneighbors" => g.outneighbors,
        "inneighbors" => g.inneighbors
    )
end

function serialize_idaginfo(info)
    return Dict("count" => info.count)
end

function serialize_intentdagnode(node)
    return Dict(
        "type" => string(typeof(node)),
        "uuid" => string(node.uuid),
        "data" => serialize_node_data(node.data),
        "generator" => string(typeof(node.generator)),
        "statelog" => [Dict("datetime" => string(dt), "state" => string(state)) for (dt, state) in node.statelog]
    )
end

function serialize_node_data(data)
    if typeof(data) <: MINDFul.RemoteIntent
        return serialize_remoteintent(data)
    elseif typeof(data) <: MINDFul.ConnectivityIntent
        return serialize_connectivityintent(data)
    elseif typeof(data) <: MINDFul.RouterPortLLI
        return serialize_routerportlli(data)
    elseif typeof(data) <: MINDFul.OXCAddDropBypassSpectrumLLI
        return serialize_oxcadddropbypassspectrumlli(data)
    elseif typeof(data) <: MINDFul.TransmissionModuleLLI
        return serialize_transmissionmodulelli(data)
    else
        return string(data)
    end
end

function serialize_remoteintent(ri)
    return Dict(
        "remote_ibnfid" => string(ri.remote_ibnfid),
        "internal_idagnodeid" => string(ri.internal_idagnodeid),
        "intent" => serialize_connectivityintent(ri.intent),
        "is_terminal" => ri.is_terminal
    )
end

function serialize_connectivityintent(ci)
    return Dict(
        "src" => serialize_globalnode(ci.src),
        "dst" => serialize_globalnode(ci.dst),
        "rate" => string(ci.rate),
        "constraints" => [string(c) for c in ci.constraints] # You can expand this if you want detailed constraint serialization
    )
end

function serialize_globalnode(gn)
    return Dict(
        "ibnfid" => string(gn.ibnfid),
        "localnode" => gn.localnode
    )
end

function serialize_routerportlli(rp)
    return Dict(
        "node" => rp.node,
        "port" => rp.port
    )
end

function serialize_oxcadddropbypassspectrumlli(oxc)
    return Dict(
        "node" => oxc.node,
        "port" => oxc.port,
        "direction" => oxc.direction,
        "adddrop" => oxc.adddrop,
        "slots" => collect(oxc.slots)
    )
end

function serialize_transmissionmodulelli(tm)
    return Dict(
        "srcnode" => tm.srcnode,
        "dstnode" => tm.dstnode,
        "srcport" => tm.srcport,
        "dstport" => tm.dstport,
        "modulation" => tm.modulation
    )
end
=#