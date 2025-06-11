@recvtime function sendrequest(remotehandler::RemoteHTTPHandler, endpoint::String, data::Dict)
    url = getbaseurl(remotehandler) * endpoint
    
    if offsettime == now()
        push!(data, HTTPMessages.KEY_OFFSETTIME => HTTPMessages.KEY_NOTHING)
    else
        push!(data, HTTPMessages.KEY_OFFSETTIME => string(@logtime))
    end
    body = JSON.json(data)  
    headers = Dict("Content-Type" => "application/json") # "Content-Length" => string(length(body)
    
    hasverbose = haskey(data, HTTPMessages.KEY_VERBOSE) 
    if hasverbose && data[HTTPMessages.KEY_VERBOSE] == true
        println(" ")
        println("SENDING REQUEST TO $url")
        println("Body: $body")
        logtime = @logtime
        println("Logtime = $logtime")
    end

    response = HTTP.post(url, headers, body;  http_version=HTTP.Strings.HTTPVersion("1.0"))
    return response
end


function startibnserver!(myibnf::IBNFramework)
    selectedhandler = getibnfhandlers(myibnf)[1]
    baseurl = getbaseurl(selectedhandler)
    uri = HTTP.URI(baseurl)
    ipaddress = string(uri.host)
    port = parse(Int, uri.port)
    
    println(" ")
    println("Starting server on $ipaddress:$port")
    try
        Server.serve(port=port, async=true, context=myibnf, serialize=false, swagger=true, access_log=nothing)
    catch e
        if isa(e, Base.IOError)
            println("Server at $ipaddress:$port is already running")
        else
            rethrow(e)  
        end
    end
end

function startibnserver!(ibnfs::Vector{<:IBNFramework})
    ibnfsdict = Dict{Int, IBNFramework}()
    for ibnf in ibnfs 
        selectedhandler = getibnfhandlers(ibnf)[1]
        baseurl = getbaseurl(selectedhandler)
        uri = HTTP.URI(baseurl)
        port = parse(Int, uri.port)
        push!(ibnfsdict, port => ibnf)
    end

    for ibnf in ibnfs
        selectedhandler = getibnfhandlers(ibnf)[1]
        baseurl = getbaseurl(selectedhandler)
        uri = HTTP.URI(baseurl)
        ipaddress = string(uri.host)
        port = parse(Int, uri.port)
        
        println(" ")
        println("Starting server on $ipaddress:$port")
        try
            Server.serve(port=port, async=true, context=ibnfsdict, serialize=false, swagger=true, access_log=nothing) 
        catch e
            if isa(e, Base.IOError)
                println("Server at $ipaddress:$port is already running")
            else
                rethrow(e)  
            end
        end     
    end
end



function serializeglobaledge(edge::GlobalEdge)
    return Dict(
        HTTPMessages.KEY_SRC => serializeglobalnode(edge.src),  # Serialize the source node
        HTTPMessages.KEY_DST => serializeglobalnode(edge.dst)   # Serialize the destination node
    )
end

function serializeglobalnode(node::GlobalNode)
    return Dict(
        HTTPMessages.KEY_IBNFID => string(node.ibnfid),  # Convert UUID to string
        HTTPMessages.KEY_LOCALNODE => node.localnode    # Keep localnode as Int64
    )
end


function serializeconnectivityintent(intent::ConnectivityIntent)
    return Dict(
        HTTPMessages.KEY_SRC => serializeglobalnode(intent.sourcenode),
        HTTPMessages.KEY_DST => serializeglobalnode(intent.destinationnode),
        HTTPMessages.KEY_RATE => string(intent.rate),
        HTTPMessages.KEY_CONSTRAINTS => [serializeconstraint(constraint) for constraint in intent.constraints]
    )
end

function serializeconstraint(constraint::AbstractIntentConstraint)
    if constraint isa OpticalInitiateConstraint
        return Dict(
            HTTPMessages.KEY_TYPE => HTTPMessages.KEY_OPTICALINITIATECONSTRAINT,
            HTTPMessages.KEY_GNI => serializeglobalnode(constraint.globalnode_input),
            HTTPMessages.KEY_SSR => [constraint.spectrumslotsrange.start, constraint.spectrumslotsrange.stop],
            HTTPMessages.KEY_OPTICALREACH => string(constraint.opticalreach),
            HTTPMessages.KEY_TMC => serializetransmissionmodulecompatibility(constraint.transmissionmodulecompat)
        )
    elseif constraint isa OpticalTerminateConstraint
        return Dict(
            HTTPMessages.KEY_TYPE => HTTPMessages.KEY_OPTICALTERMINATECONSTRAINT,
        )
    else
        error("Unsupported constraint type: $(typeof(constraint))")
    end
end

function serializetransmissionmodulecompatibility(transmissionmodulecompat::TransmissionModuleCompatibility)
    return Dict(
        HTTPMessages.KEY_RATE => string(transmissionmodulecompat.rate),
        HTTPMessages.KEY_SSN => transmissionmodulecompat.spectrumslotsneeded,
        HTTPMessages.KEY_NAME => transmissionmodulecompat.name,
    )
end

function serializelowlevelintent(ll)
    if ll isa OXCAddDropBypassSpectrumLLI
        return Dict(
            HTTPMessages.KEY_TYPE => HTTPMessages.KEY_ADBYPASSSPECTRUM,
            HTTPMessages.KEY_NODE => ll.localnode,
            HTTPMessages.KEY_INPUT => ll.localnode_input,
            HTTPMessages.KEY_ADDDROPPORT => ll.adddropport,
            HTTPMessages.KEY_OUTPUT => ll.localnode_output,
            HTTPMessages.KEY_SLOTSTART => ll.spectrumslotsrange.start,
            HTTPMessages.KEY_SLOTEND => ll.spectrumslotsrange.stop,
        )
    elseif ll isa TransmissionModuleLLI
        return Dict(
            HTTPMessages.KEY_TYPE => HTTPMessages.KEY_TRANSMISSIONMODULE,
            HTTPMessages.KEY_NODE => ll.localnode,
            HTTPMessages.KEY_POOLINDEX => ll.transmissionmoduleviewpoolindex,
            HTTPMessages.KEY_MODESINDEX => ll.transmissionmodesindex,
            HTTPMessages.KEY_PORT => ll.routerportindex,
            HTTPMessages.KEY_ADDDROPPORT => ll.adddropport
        )
    elseif ll isa RouterPortLLI
        return Dict(
            HTTPMessages.KEY_TYPE => HTTPMessages.KEY_ROUTERPORT,
            HTTPMessages.KEY_NODE => ll.localnode,
            HTTPMessages.KEY_PORT => ll.routerportindex
        )
    else
        error("Unknown LowLevelIntent type: $(typeof(ll))")
    end
end

function deserializelowlevelintent(dict)
    if dict[HTTPMessages.KEY_TYPE] == HTTPMessages.KEY_ADBYPASSSPECTRUM
        return MINDFul.OXCAddDropBypassSpectrumLLI(
            dict[HTTPMessages.KEY_NODE], dict[HTTPMessages.KEY_INPUT], dict[HTTPMessages.KEY_ADDDROPPORT], dict[HTTPMessages.KEY_OUTPUT], dict[HTTPMessages.KEY_SLOTSTART]:dict[HTTPMessages.KEY_SLOTEND]
        )
    elseif dict[HTTPMessages.KEY_TYPE] == HTTPMessages.KEY_TRANSMISSIONMODULE
        return MINDFul.TransmissionModuleLLI(
            dict[HTTPMessages.KEY_NODE], dict[HTTPMessages.KEY_POOLINDEX], dict[HTTPMessages.KEY_MODESINDEX], dict[HTTPMessages.KEY_PORT], dict[HTTPMessages.KEY_ADDDROPPORT]
        )
    elseif dict[HTTPMessages.KEY_TYPE] == HTTPMessages.KEY_ROUTERPORT
        return MINDFul.RouterPortLLI(
            dict[HTTPMessages.KEY_NODE], dict[HTTPMessages.KEY_PORT]
        )
    else
        error("Unknown LowLevelIntent type: $(dict["type"])")
    end
end

function reconvertconstraint(constraint)
    if constraint[HTTPMessages.KEY_TYPE] == HTTPMessages.KEY_OPTICALINITIATECONSTRAINT
        return OpticalInitiateConstraint(
            GlobalNode(UUID(constraint[HTTPMessages.KEY_GNI][HTTPMessages.KEY_IBNFID]), constraint[HTTPMessages.KEY_GNI][HTTPMessages.KEY_LOCALNODE]),
            constraint[HTTPMessages.KEY_SSR][1]:constraint[HTTPMessages.KEY_SSR][2],
            KMf(parse(Float64, replace(constraint[HTTPMessages.KEY_OPTICALREACH], " km" => ""))),
            TransmissionModuleCompatibility(GBPSf(parse(Float64, replace(constraint[HTTPMessages.KEY_TMC][HTTPMessages.KEY_RATE], " Gbps" => ""))), constraint[HTTPMessages.KEY_TMC][HTTPMessages.KEY_SSN], constraint[HTTPMessages.KEY_TMC][HTTPMessages.KEY_NAME])
        )
    elseif constraint[HTTPMessages.KEY_TYPE] == HTTPMessages.KEY_OPTICALTERMINATECONSTRAINT
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