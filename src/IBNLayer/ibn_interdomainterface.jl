# Every function in this file should be implemented for all `AbstractIBNFHandler`
# MA1069
# each function should have an _init and a _term version
# _init is to construct the data structures, send them and initiate connection
# _init functions should be different for RemoteIBNFHandler and IBNFramework but `term` should be the same
# _term is for the terminal entity to do the job
# the operation might  depend on the relation of `myibnf`, and `remoteibnf`.

# TODO make a macro for the generation of the init/term function ?

"""
$(TYPEDSIGNATURES) 

Request topology information
"""
function requestibnattributegraph(myibnf::IBNFramework, remoteibnf::IBNFramework)
    return getibnag(remoteibnf)
end

"""
$(TYPEDSIGNATURES) 

Request intent dag information
"""
function requestidag_init(myibnf::IBNFramework, remoteibnf::IBNFramework)
    myibnfhandler = getibnfhandler(remoteibnf)
    return requestidag_term(myibnfhandler, remoteibnf)
end

function requestidag_term(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework)
    return getidag(myibnf)
end

"""
$(TYPEDSIGNATURES) 

Request spectrum slot availabilities of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""
function requestspectrumavailability_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, ge::GlobalEdge)
    remoteibnag = getibnag(remoteibnf)
    nodeviewsrc = getnodeview(remoteibnag, src(ge))
    nodeviewdst = getnodeview(remoteibnag, dst(ge))
    localnodesrc = something(getlocalnode(remoteibnag, src(ge)))
    localnodedst = something(getlocalnode(remoteibnag, dst(ge)))
    le = Edge(localnodesrc, localnodedst)

    if getibnfid(getglobalnode(getproperties(nodeviewsrc))) == getibnfid(myibnf)
        # src is remote, dst is intra
        return getlinkspectrumavailabilities(something(getoxcview(nodeviewdst)))[le]
    elseif getibnfid(getglobalnode(getproperties(nodeviewdst))) == getibnfid(myibnf)
        # dst is remote, src is intra
        return getlinkspectrumavailabilities(something(getoxcview(nodeviewsrc)))[le]
    end

    return nothing
end

"""
$(TYPEDSIGNATURES) 

Request the path that is implementing intent `intentuuid` in the remote IBN framework as global node vector
"""
function requestintentglobalpath_init(myibnf::IBNFramework, remoteibnf::IBNFramework, intentuuid::UUID; onlyinstalled::Bool = true)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestintentglobalpath_term(myibnfhandler, remoteibnf, intentuuid; onlyinstalled)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestintentglobalpath_term(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, intentuuid::UUID; onlyinstalled::Bool = true)
    localnodepath = logicalordergetpath(getlogicallliorder(myibnf, intentuuid; onlyinstalled))
    globalnodepath = map(ln -> getglobalnode(getibnag(myibnf), ln), localnodepath)
    return globalnodepath
end

"""
$(TYPEDSIGNATURES)

Request the link state of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""
function requestcurrentlinkstate_init(myibnf::IBNFramework, remoteibnf::IBNFramework, ge::GlobalEdge)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestcurrentlinkstate_term(myibnfhandler, remoteibnf, ge)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestcurrentlinkstate_term(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, ge::GlobalEdge)
    println(" ")
    @show ge
    myibnag = getibnag(myibnf)
    nodeviewsrc = getnodeview(myibnag, src(ge))
    nodeviewdst = getnodeview(myibnag, dst(ge))
    localnodesrc = something(getlocalnode(myibnag, src(ge)))
    localnodedst = something(getlocalnode(myibnag, dst(ge)))
    le = Edge(localnodesrc, localnodedst)
    @show le

    if getibnfid(getglobalnode(getproperties(nodeviewsrc))) == getibnfid(remoteibnfhandler)
        # src is remote, dst is intra
        return getcurrentlinkstate(something(getoxcview(nodeviewdst)), le)
    elseif getibnfid(getglobalnode(getproperties(nodeviewdst))) == getibnfid(remoteibnfhandler)
        # dst is remote, src is intra
        return getcurrentlinkstate(something(getoxcview(nodeviewsrc)), le)
    end

    return nothing
end

"""
$(TYPEDSIGNATURES) 

Request all the link states of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""
function requestlinkstates_init(myibnf::IBNFramework, remoteibnf::IBNFramework, ge::GlobalEdge)
    println("requestlinkstates_init")
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestlinkstates_term(myibnfhandler, remoteibnf, ge)
end

function requestlinkstates_term(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, ge::GlobalEdge)
    myibnag = getibnag(myibnf)
    nodeviewsrc = getnodeview(myibnag, src(ge))
    nodeviewdst = getnodeview(myibnag, dst(ge))
    localnodesrc = something(getlocalnode(myibnag, src(ge)))
    localnodedst = something(getlocalnode(myibnag, dst(ge)))
    le = Edge(localnodesrc, localnodedst)

    if getibnfid(getglobalnode(getproperties(nodeviewsrc))) == getibnfid(remoteibnfhandler)
        # src is remote, dst is intra
        return getlinkstates(something(getoxcview(nodeviewdst)), le)
    elseif getibnfid(getglobalnode(getproperties(nodeviewdst))) == getibnfid(remoteibnfhandler)
        # dst is remote, src is intra
        return getlinkstates(something(getoxcview(nodeviewsrc)), le)
    end

    return nothing
end

"""
$(TYPEDSIGNATURES)

Request to set the state of the neighboring link
"""
@recvtime function requestsetlinkstate_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, ge::GlobalEdge, operatingstate::Bool)
    println("requestsetlinkstate_init")
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestsetlinkstate_term!(myibnfhandler, remoteibnf, ge, operatingstate; @passtime)
end

"""
$(TYPEDSIGNATURES) 
TODO-now implement
"""
@recvtime function requestsetlinkstate_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, ge::GlobalEdge, operatingstate::Bool)
    myibnag = getibnag(myibnf)
    nodeviewsrc = getnodeview(myibnag, src(ge))
    nodeviewdst = getnodeview(myibnag, dst(ge))
    localnodesrc = something(getlocalnode(myibnag, src(ge)))
    localnodedst = something(getlocalnode(myibnag, dst(ge)))
    le = Edge(localnodesrc, localnodedst)

    if getibnfid(getglobalnode(getproperties(nodeviewsrc))) == getibnfid(remoteibnfhandler)
        # src is remote, dst is intra
        return setlinkstate!(myibnf, something(getoxcview(nodeviewdst)), le, operatingstate; @passtime)
    elseif getibnfid(getglobalnode(getproperties(nodeviewdst))) == getibnfid(remoteibnfhandler)
        # dst is remote, src is intra
        return getcurrentlinkstate(something(getoxcview(nodeviewsrc)), le, operatingstate; @passtime)
    end

    return nothing
end

"""
$(TYPEDSIGNATURES) 

Return the id of the new dag node if successful and `nothing` otherwise
"""
@recvtime function requestdelegateintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, intent::AbstractIntent, internalidagnodeid::UUID)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    
    return requestdelegateintent_term!(myibnfhandler, remoteibnf, intent, internalidagnodeid; @passtime)
    
    # println("requestdelegateintent")
    # remoteintent = RemoteIntent(getibnfid(myibnf), internalidagnodeid, intent, false)
    # remoteintentdagnode = addidagnode!(getidag(remoteibnf), remoteintent; @passtime)
    # return getidagnodeid(remoteintentdagnode)
end





"""
$(TYPEDSIGNATURES)

Compilation algorithms are given as symbols because they might not be available programmatically to different IBN frameworks
"""
function requestavailablecompilationalgorithms(myibnf::IBNFramework, remoteibnf::IBNFramework{<:AbstractOperationMode})
    compalglist = [KSPFFalg]
end

"""
$(TYPEDSIGNATURES) 

The initiator domain `myibnf` asks `remoteibnf` to compile the external remote intent `idagnodeid` with the specified compilation algorithm
"""
@recvtime function requestcompileintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=(); verbose::Bool = false)
    requestcompileintent_term!(myibnf, remoteibnf, idagnodeid, compilationalgorithmkey, compilationalgorithmargs; verbose, @passtime)
end

"""
$(TYPEDSIGNATURES) 

The initiator domain `remoteibnf` asks this domain `myibnf` to compile the internal remote intent `idagnodeid` with the specified compilation algorithm
"""
@recvtime function requestcompileintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=(); verbose::Bool = false)
    # get the algorithm
    compilationalgorithm = getcompilationalgorithm(myibnf, compilationalgorithmkey, compilationalgorithmargs)
    intent_return = compileintent!(myibnf, idagnodeid, compilationalgorithm; verbose, @passtime)
    @show intent_return
    return intent_return
end

"""
$(TYPEDSIGNATURES) 
"""
@recvtime function requestinstallintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return requestinstallintent_term!(myibnf, remoteibnf, idagnodeid; verbose=false, @passtime)
end

"""
$(TYPEDSIGNATURES) 
"""
@recvtime function requestinstallintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return installintent!(myibnf, idagnodeid; verbose, @passtime)
end

"""
$(TYPEDSIGNATURES) 
"""
@recvtime function requestuninstallintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return requestuninstallintent_term!(myibnf, remoteibnf, idagnodeid; verbose=false, @passtime)
end

"""
$(TYPEDSIGNATURES) 
"""
@recvtime function requestuninstallintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return uninstallintent!(myibnf, idagnodeid; verbose, @passtime)
end

"""
$(TYPEDSIGNATURES) 
"""
@recvtime function requestuncompileintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    return requestuncompileintent_term!(myibnf, remoteibnf, idagnodeid; verbose=false, @passtime)
end

"""
$(TYPEDSIGNATURES) 
"""
@recvtime function requestuncompileintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    uncompiledflag = uncompileintent!(myibnf, idagnodeid; verbose, @passtime)
    if uncompiledflag == ReturnCodes.SUCCESS
        # delete also the intent
        removeintent!(myibnf, idagnodeid; verbose)
        return ReturnCodes.SUCCESS
    end
    return uncompiledflag
end

"""
$(TYPEDSIGNATURES) 

Request to `remoteibnf` whether the `idagnode` is theoretically satisfied
"""
function requestissatisfied(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; onlyinstalled::Bool, noextrallis::Bool)
    return issatisfied(remoteibnf, idagnodeid; onlyinstalled, noextrallis)
end

"""
$(TYPEDSIGNATURES) 

Request the initiator `remoteibnf` to update the state of its mirrored remote intent
"""
# @recvtime function requestremoteintentstateupdate!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID, newstate::IntentState.T)
#     oldstate = getidagnodestate(getidag(remoteibnf), idagnodeid)
#     if oldstate != newstate
#         idagnode = getidagnode(getidag(remoteibnf), idagnodeid)
#         pushstatetoidagnode!(idagnode, newstate; @passtime)
#         foreach(getidagnodeparents(getidag(remoteibnf), idagnodeid)) do idagnodeparent
#             updateidagnodestates!(remoteibnf, idagnodeparent; @passtime)
#         end
#     end
#     return oldstate != newstate
# end

@recvtime function requestremoteintentstateupdate_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID, newstate::IntentState.T)
    if idagnodeid == UUID(0xc) && getibnfid(remoteibnf) == UUID(0x3) && newstate == IntentState.Compiled
        # This is a test case for the interdomain interface
        # It should be removed in the future
        println("TEST CASE QWERTY")
        
        
    end
    #println("TEST CASE ABCDEF")
    
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    requestremoteintentstateupdate_term!(myibnfhandler, remoteibnf, idagnodeid, newstate; @passtime)
end

@recvtime function requestremoteintentstateupdate_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, idagnodeid::UUID, newstate::IntentState.T)
    if idagnodeid == UUID(0xc) && getibnfid(remoteibnfhandler) == UUID(0x3) && newstate == IntentState.Compiled
        # This is a test case for the interdomain interface
        # It should be removed in the future
        println("TEST CASE QWERTYMD")
        
        
    end
    
    src_domain = string(myibnf.ibnfid)
    @show newstate
    resp = send_request(remoteibnfhandler, HTTPCodes.REMOTEINTENT_STATEUPDATE, Dict("idagnodeid" => string(idagnodeid), "src_domain" => src_domain, "newstate" => string(newstate)))

    return Bool.(JSON.parse(String(resp.body)))
end

@recvtime function requestremoteintentstateupdate_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID, newstate::IntentState.T)
    @show getidag(myibnf)
    @show idagnodeid
    @show myibnf.ibnfid
    if idagnodeid == UUID(0xc) && getibnfid(myibnf) == UUID(0x3) && newstate == IntentState.Compiled
        # This is a test case for the interdomain interface
        # It should be removed in the future
        println("TEST CASE QWERTY_TERM")
        
        
    end
    #println("TEST CASE ABCDEF")


    oldstate = getidagnodestate(getidag(myibnf), idagnodeid)
    if oldstate != newstate
        idagnode = getidagnode(getidag(myibnf), idagnodeid)
        pushstatetoidagnode!(idagnode, newstate; @passtime)
        foreach(getidagnodeparents(getidag(myibnf), idagnodeid)) do idagnodeparent
            updateidagnodestates!(myibnf, idagnodeparent; @passtime)
        end
    end
    return oldstate != newstate
end

"""
$(TYPEDSIGNATURES) 

MA1069 implementation
If far away, think about authorization and permissions.
That's the reason why there are 2 arguments: The first argument should have the authorization.
"""
function requestibnattributegraph_term!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)
    status, response = send_request(remoteibnfhandler, "/api/ibnattributegraph", Dict())
    if status == 200
        return response  
    else
        error("Failed to request IBN Attribute Graph: $(response)")
    end

end

"""
MA1069 implementation
"""
function requestidag_init(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)
    error("not implemented")
end
"""
$(TYPEDSIGNATURES) 

MA1069 implementation

Request spectrum slot availabilities of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""

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


function requestspectrumavailability_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, ge::GlobalEdge)
    
    
    ge_data = serialize_globaledge(ge)
    src_domain = string(myibnf.ibnfid)

    resp = send_request(remoteibnfhandler, HTTPCodes.SPECTRUM_AVAILABILITY, Dict("global_edge" => ge_data, "src_domain" => src_domain))
    
    if resp.status == 200
        return Bool.(JSON.parse(String(resp.body)))
        #return ReturnCodes.SUCCESS
        #return true
    else
        error("Failed to request spectrum availability: $(resp.body)")
    end
    
end

#=function requestspectrumavailability_term!(myibnf::IBNFramework, ge::GlobalEdge)
    
    remoteibnag = getibnag(myibnf)
    #remoteibnag = requestibnattributegraph(myibnf, remoteibnfhandler) 
    #@show remoteibnag 
    # ge = GlobalEdge(
    #     GlobalNode(getibnfid(myibnf), ge_in.src.localnode),
    #     ge_in.dst
    # )
    
    @show src(ge)
    @show dst(ge)
    nodeviewsrc = getnodeview(remoteibnag, src(ge))
    @show nodeviewsrc
    nodeviewdst = getnodeview(remoteibnag, dst(ge))
    @show nodeviewdst
    localnodesrc = something(getlocalnode(remoteibnag, src(ge)))
    @show localnodesrc
    localnodedst = something(getlocalnode(remoteibnag, dst(ge)))
    @show localnodedst
    le = Edge(localnodesrc, localnodedst)
    @show le

    if getibnfid(getglobalnode(getproperties(nodeviewsrc))) == getibnfid(myibnf)
        # src is remote, dst is intra
        return getlinkspectrumavailabilities(something(getoxcview(nodeviewsrc)))[le]
    elseif getibnfid(getglobalnode(getproperties(nodeviewdst))) == getibnfid(myibnf)
        # dst is remote, src is intra
        #Main.@infiltrate
        spa = getlinkspectrumavailabilities(something(getoxcview(nodeviewdst)))[le]
        @show spa
        return spa
    end

    return nothing
end=#

#myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, ge::GlobalEdge

function requestspectrumavailability_term!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, ge::GlobalEdge)
    remoteibnag = getibnag(myibnf)
    nodeviewsrc = getnodeview(remoteibnag, src(ge))
    nodeviewdst = getnodeview(remoteibnag, dst(ge))
    localnodesrc = something(getlocalnode(remoteibnag, src(ge)))
    localnodedst = something(getlocalnode(remoteibnag, dst(ge)))
    le = Edge(localnodesrc, localnodedst)

    if getibnfid(getglobalnode(getproperties(nodeviewsrc))) == getibnfid(remoteibnfhandler)
        # src is remote, dst is intra
        return getlinkspectrumavailabilities(something(getoxcview(nodeviewdst)))[le]
    elseif getibnfid(getglobalnode(getproperties(nodeviewdst))) == getibnfid(remoteibnfhandler)
        # dst is remote, src is intra
        return getlinkspectrumavailabilities(something(getoxcview(nodeviewsrc)))[le]
    end

    return nothing
end

"""
$(TYPEDSIGNATURES) 

MA1069 implementation

Delegates an intent to another domain

Return the id of the new dag node if successful and `nothing` otherwise
"""
# function requestdelegateintent!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, intent::AbstractIntent, internalidagnodeid::UUID)
#     error("not implemented")
# end
# @recvtime function requestdelegateintent!(myibnf::IBNFramework, remoteibnf::IBNFramework, intent::AbstractIntent, internalidagnodeid::UUID)
#     println("requestdelegateintent")
#     remoteintent = RemoteIntent(getibnfid(myibnf), internalidagnodeid, intent, false)
#     remoteintentdagnode = addidagnode!(getidag(remoteibnf), remoteintent; @passtime)
#     return getidagnodeid(remoteintentdagnode)
# end

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
        
        

function requestdelegateintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, intent::AbstractIntent, internalidagnodeid::UUID)
    @show intent
    @show intent.constraints
    @show intent.constraints[1].spectrumslotsrange.start
    src_domain = string(myibnf.ibnfid)
    serialized_intent = serialize_connectivity_intent(intent)
    @show serialized_intent
    resp = send_request(remoteibnfhandler, HTTPCodes.DELEGATE_INTENT, Dict("internalidagnodeid" => string(internalidagnodeid), "src_domain" => src_domain, "intent" => serialized_intent))
    uuid_returned = JSON.parse(String(resp.body))
    @show uuid_returned
    return UUID(uuid_returned["value"])
end

@recvtime function requestdelegateintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, intent::AbstractIntent, internalidagnodeid::UUID)
    println("requestdelegateintent")
    @show typeof(internalidagnodeid)
    @show intent
    if typeof(internalidagnodeid) != UUID
        error("internalidagnodeid must be a UUID, got $(typeof(internalidagnodeid))")
    end
    remoteintent = RemoteIntent(getibnfid(remoteibnfhandler), internalidagnodeid, intent, false)
    #remoteintentdagnode = addidagnode!(getidag(myibnf), remoteintent; @passtime)
    remoteintentdagnode = addidagnode!(myibnf, remoteintent; @passtime)
    @show getidagnodeid(remoteintentdagnode)
    return getidagnodeid(remoteintentdagnode)


    
    # remoteintent = RemoteIntent(getibnfid(myibnf), internalidagnodeid, intent, false)
    # remoteintentdagnode = addidagnode!(getidag(remoteibnf), remoteintent; @passtime)
    # return getidagnodeid(remoteintentdagnode)
end

"""
$(TYPEDSIGNATURES)

MA1069 implementation
"""
function requestavailablecompilationalgorithms_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)

    resp = send_request(remoteibnfhandler, HTTPCodes.COMPILATION_ALGORITHMS, Dict())

    return JSON.parse(String(resp.body))
    
end

function requestavailablecompilationalgorithms_term!()
    compalglist = [KSPFFalg]
    return compalglist
end

"""
$(TYPEDSIGNATURES) 

MA1069 implementation
"""
#=function requestcompileintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, compilationalgorithm::Symbol=:default, compilationalgorithmkey::Tuple=())
    error("not implemented")
end=#
@recvtime function requestcompileintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=(); verbose::Bool = false)
    src_domain = string(myibnf.ibnfid)
    resp = send_request(remoteibnfhandler, HTTPCodes.COMPILE_INTENT, Dict("src_domain" => src_domain, "idagnodeid" => string(idagnodeid), "compilationalgorithmkey" => string(compilationalgorithmkey), "compilationalgorithmargs" => JSON.json(compilationalgorithmargs)))
    @show return_compile_init = JSON.parse(String(resp.body))
    return Symbol(return_compile_init)
    
end

"""
$(TYPEDSIGNATURES) 
MA1069 implementation

The initiator domain `remoteibnf` asks this domain `myibnf` to compile the internal remote intent `idagnodeid` with the specified compilation algorithm
"""
#=function requestcompileintent_term!(remoteibnfhandler::RemoteIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=())
    error("not implemented")
end=#


"""
$(TYPEDSIGNATURES) 

MA1069 implementation

Request to `remoteibnf` whether the `idagnode` is theoretically satisfied
"""
function requestissatisfied(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, idagnode::IntentDAGNode; onlyinstalled::Bool, noextrallis::Bool)
    error("not implemented")
end



function requestcurrentlinkstate_init(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, ge::GlobalEdge)
    #=myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    cls = requestcurrentlinkstate_term(myibnf, remoteibnfhandler, ge)
    @show cls
    return cls=#

    ge_data = serialize_globaledge(ge)
    src_domain = string(myibnf.ibnfid)

    resp = send_request(remoteibnfhandler, HTTPCodes.CURRENT_LINKSTATE, Dict("global_edge" => ge_data, "src_domain" => src_domain))
    
    if resp.status == 200
        #return JSON.parse(String(resp.body))
        return Bool.(JSON.parse(String(resp.body)))
        #return true
    else
        error("Failed to request spectrum availability: $(resp.body)")
    end
end

#= function requestcurrentlinkstate_term(myibnf::IBNFramework, ge::GlobalEdge)
    myibnag = getibnag(myibnf)
    println(" ")
    @show ge
    @show myibnf.ibnfid
    nodeviewsrc = getnodeview(myibnag, src(ge))
    nodeviewdst = getnodeview(myibnag, dst(ge))
    @show nodeviewsrc
    @show nodeviewdst
    localnodesrc = something(getlocalnode(myibnag, src(ge)))
    localnodedst = something(getlocalnode(myibnag, dst(ge)))
    le = Edge(localnodesrc, localnodedst)
    @show le
    println(" ")
    if getibnfid(getglobalnode(getproperties(nodeviewsrc))) == getibnfid(myibnf)
        # src is remote, dst is intra
        return getcurrentlinkstate(something(getoxcview(nodeviewsrc)), le)
    elseif getibnfid(getglobalnode(getproperties(nodeviewdst))) == getibnfid(myibnf)
        #Main.@infiltrate
        # dst is remote, src is intra
        return getcurrentlinkstate(something(getoxcview(nodeviewdst)), le)
    end

    return nothing
end =#