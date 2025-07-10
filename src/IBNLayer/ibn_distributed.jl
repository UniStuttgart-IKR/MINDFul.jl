@recvtime function sendrequest(remotehandler::RemoteHTTPHandler, endpoint::String, data::Dict)
    if getibnfhandlertokenrecv(remotehandler) == String[]
        initiatoribnfid = data[HTTPMessages.KEY_INITIATORIBNFID]
        token = handshake_init(initiatoribnfid, remotehandler)
    else
        token = last(getibnfhandlertokenrecv(remotehandler))
    end
    push!(data, HTTPMessages.KEY_TOKEN => token)
    
    url = getbaseurl(remotehandler) * endpoint
    
    if offsettime == now()
        push!(data, HTTPMessages.KEY_OFFSETTIME => HTTPMessages.KEY_NOTHING)
    else
        push!(data, HTTPMessages.KEY_OFFSETTIME => string(@logtime))
    end
    body = JSON.json(data)  
    headers = Dict("Content-Type" => "application/json") # "Connection" => "close" "Content-Length" => string(length(body)
    
    hasverbose = haskey(data, HTTPMessages.KEY_VERBOSE) 
    if hasverbose && data[HTTPMessages.KEY_VERBOSE] == true
        println(" ")
        println("SENDING REQUEST TO $url")
        #println("Body: $body")
        logtime = @logtime
        println("Logtime = $logtime")
    end

    response = HTTP.post(url, headers, body; keepalive=false, require_ssl_verification=false)
    #http_version=HTTP.Strings.HTTPVersion("1.0")
    return response
end

function ipfiltering(tcp, neighbourips)
    if tcp isa MbedTLS.SSLContext
        socket = tcp.bio
    else
        socket = tcp
    end
    host, port = Sockets.getpeername(socket)

    if string(host) == "127.0.0.1" || string(host) in neighbourips
        #println("Request from... $host:$port")
        return true
    else 
        return false
    end
    # if startswith(string(host), "192.168.")
    #     println("Blocked connection from $host")
    #     return false
    # end
end


function startibnserver!(myibnf::IBNFramework, encryption, neighbourips)
    selectedhandler = getibnfhandlers(myibnf)[1]
    port = getibnfhandlerport(selectedhandler)
    dir = @__DIR__
    if encryption
        sslconf=MbedTLS.SSLConfig("selfsigned.cert", "selfsigned.key")
    else
        sslconf=nothing
    end
    
    try
        httpserver = Server.serve(host="0.0.0.0", port=port;
            async=true, context=myibnf, serialize=false, swagger=true, access_log=nothing, 
            tcpisvalid= tcp->ipfiltering(tcp, neighbourips),
            sslconfig=sslconf,
            )
        return httpserver
    catch e
        if isa(e, Base.IOError)
            println("Server at 0.0.0.0:$port is already running")
        else
            rethrow(e)  
        end
    end
end

function startibnserver!(ibnfs::Vector{<:IBNFramework}, encryption, ips)
    ibnfsdict = Dict{Int, IBNFramework}()
    if encryption
        sslconf=MbedTLS.SSLConfig("selfsigned.cert", "selfsigned.key")
        #sslconf=MbedTLS.SSLConfig()
        #sslconf=MbedTLS.SSLConfig(dir*"/selfsigned.cert", dir*"/selfsigned.key")
    else
        sslconf=nothing
    end
    for ibnf in ibnfs 
        selectedhandler = getibnfhandlers(ibnf)[1]
        port = getibnfhandlerport(selectedhandler)
        push!(ibnfsdict, port => ibnf)
    end

    for ibnf in ibnfs
        selectedhandler = getibnfhandlers(ibnf)[1]
        port = getibnfhandlerport(selectedhandler)
        dir = @__DIR__
        println(" ")
        println("Starting server on 0.0.0.0:$port")
 
        try
            Server.serve(host="0.0.0.0", port=port;
            async=true, context=ibnfsdict, serialize=false, swagger=true, access_log=nothing, 
            tcpisvalid= tcp->ipfiltering(tcp, ips),
            sslconfig=sslconf,
            #readtimeout=10,
            #keepalive_timeout=10,
            #idle_timeout=10
            ) 
        catch e
            if isa(e, Base.IOError)
                println("Server at 0.0.0.0:$port is already running")
            else
                rethrow(e)  
            end
        end     
    end
end



function serializeglobaledge(edge::GlobalEdge)
    return Dict(
        HTTPMessages.KEY_SRC => serializeglobalnode(edge.src),  # Serializing the source node
        HTTPMessages.KEY_DST => serializeglobalnode(edge.dst)   # Serializing the destination node
    )
end

function serializeglobalnode(node::GlobalNode)
    return Dict(
        HTTPMessages.KEY_IBNFID => string(node.ibnfid),  # UUID to string
        HTTPMessages.KEY_LOCALNODE => node.localnode    # localnode as Int64
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

function serializelowlevelintent(ll::LowLevelIntent)
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

function deserializelowlevelintent(dict::Dict{String, Any})
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

function reconvertconstraint(constraint::Dict{String, Any})
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