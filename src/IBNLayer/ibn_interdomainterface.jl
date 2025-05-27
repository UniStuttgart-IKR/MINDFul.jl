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
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestibnattributegraph_term!(myibnfhandler, remoteibnf)
end

function requestibnattributegraph(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)
    initiator_ibnfid = string(myibnf.ibnfid)
    resp = send_request(remoteibnfhandler, HTTPMessages.IBNAGRAPH, Dict(HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid))
    
    #return JSON.parse(string(resp.body))
    return deserialize(IOBuffer(resp.body))
    #return getibnag(remoteibnf)
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
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestspectrumavailability_term!(myibnfhandler, remoteibnf, ge)

    #=remoteibnag = getibnag(remoteibnf)
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

    return nothing=#
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

Request the path that is implementing intent `intentuuid` in the remote IBN framework as global node vector
"""
function requestglobalnodeelectricalpresence_init(myibnf::IBNFramework, remoteibnf::IBNFramework, intentuuid::UUID; onlyinstalled::Bool = true)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestglobalnodeelectricalpresence_term(myibnfhandler, remoteibnf, intentuuid; onlyinstalled)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestglobalnodeelectricalpresence_term(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, intentuuid::UUID; onlyinstalled::Bool = true)
    localnodeelectricalpresence = logicalordergetelectricalpresence(getlogicallliorder(myibnf, intentuuid; onlyinstalled))
    globalnodepaelectricalpresence = map(ln -> getglobalnode(getibnag(myibnf), ln), localnodeelectricalpresence)
    return globalnodepaelectricalpresence
end

"""
$(TYPEDSIGNATURES) 
Request the path that is implementing intent `intentuuid` in the remote IBN framework as global node vector
"""
function requestintentgloballightpaths_init(myibnf::IBNFramework, remoteibnf::IBNFramework, intentuuid::UUID; onlyinstalled::Bool = true)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestintentgloballightpaths_term(myibnfhandler, remoteibnf, intentuuid; onlyinstalled)
end

"""
$(TYPEDSIGNATURES) 
"""
function requestintentgloballightpaths_term(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, intentuuid::UUID; onlyinstalled::Bool = true)
    localnodelightpaths = logicalordergetlightpaths(getlogicallliorder(myibnf, intentuuid; onlyinstalled))
    globalnodelightpaths = [map(ln -> getglobalnode(getibnag(myibnf), ln), localnodelightpath) for localnodelightpath in localnodelightpaths]
    return globalnodelightpaths
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
    myibnag = getibnag(myibnf)
    nodeviewsrc = getnodeview(myibnag, src(ge))
    nodeviewdst = getnodeview(myibnag, dst(ge))
    localnodesrc = something(getlocalnode(myibnag, src(ge)))
    localnodedst = something(getlocalnode(myibnag, dst(ge)))
    le = Edge(localnodesrc, localnodedst)
 

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
    #println("requestlinkstates_init")
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestlinkstates_term(myibnfhandler, remoteibnf, ge)
end

function requestlinkstates_init(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, ge::GlobalEdge)
    ge_data = serialize_globaledge(ge)
    initiator_ibnfid = string(myibnf.ibnfid)

    resp = send_request(remoteibnfhandler, HTTPMessages.REQ_LINKSTATES, Dict(HTTPMessages.GLOBAL_EDGE => ge_data, HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid))
    if resp.status == 200
        parsed = JSON.parse(String(resp.body))
        result = [(DateTime(item[HTTPMessages.LINK_DATETIME]), Bool(item[HTTPMessages.LINK_STATE])) for item in parsed]
        #@show result
        return result
    else
        error("Failed to set link state: $(resp.body)")
    end
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
    #println("requestsetlinkstate_init")
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestsetlinkstate_term!(myibnfhandler, remoteibnf, ge, operatingstate; @passtime)
end

@recvtime function requestsetlinkstate_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, ge::GlobalEdge, operatingstate::Bool)
    ge_data = serialize_globaledge(ge)
    initiator_ibnfid = string(myibnf.ibnfid)

    resp = send_request(remoteibnfhandler, HTTPMessages.SET_LINKSTATE, Dict(HTTPMessages.GLOBAL_EDGE => ge_data, HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid, HTTPMessages.OPERATINGSTATE => operatingstate))
    if resp.status == 200
        return Symbol(JSON.parse(String(resp.body)))
    else
        error("Failed to set link state: $(resp.body)")
    end
end

"""
$(TYPEDSIGNATURES) 
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
        return setlinkstate!(myibnf, something(getoxcview(nodeviewsrc)), le, operatingstate; @passtime)
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
end



"""
$(TYPEDSIGNATURES)

Compilation algorithms are given as symbols because they might not be available programmatically to different IBN frameworks
"""
function requestavailablecompilationalgorithms(myibnf::IBNFramework, remoteibnf::IBNFramework{<:AbstractOperationMode})
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestavailablecompilationalgorithms_term!(myibnfhandler, remoteibnf)
end

"""
$(TYPEDSIGNATURES) 

The initiator domain `myibnf` asks `remoteibnf` to compile the external remote intent `idagnodeid` with the specified compilation algorithm
"""
@recvtime function requestcompileintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=(); verbose::Bool = false)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    requestcompileintent_term!(myibnfhandler, remoteibnf, idagnodeid, compilationalgorithmkey, compilationalgorithmargs; verbose, @passtime)
end

"""
$(TYPEDSIGNATURES) 

The initiator domain `remoteibnf` asks this domain `myibnf` to compile the internal remote intent `idagnodeid` with the specified compilation algorithm
"""
@recvtime function requestcompileintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=(); verbose::Bool = false)
    # get the algorithm
    compilationalgorithm = getcompilationalgorithm(myibnf, compilationalgorithmkey, compilationalgorithmargs)
    intent_return = compileintent!(myibnf, idagnodeid, compilationalgorithm; verbose, @passtime)
    #@show intent_return
    return intent_return
end

"""
$(TYPEDSIGNATURES) 
"""
@recvtime function requestinstallintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestinstallintent_term!(myibnfhandler, remoteibnf, idagnodeid; verbose=false, @passtime)
end

@recvtime function requestinstallintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, idagnodeid::UUID; verbose::Bool=false)
    initiator_ibnfid = string(myibnf.ibnfid)
    resp = send_request(remoteibnfhandler, HTTPMessages.INSTALL_INTENT, Dict(HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid, HTTPMessages.IDAGNODEID => string(idagnodeid), HTTPMessages.VERBOSE => verbose))
    return JSON.parse(String(resp.body))
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
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestuninstallintent_term!(myibnfhandler, remoteibnf, idagnodeid; verbose=false, @passtime)
end

@recvtime function requestuninstallintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, idagnodeid::UUID; verbose::Bool=false)
    initiator_ibnfid = string(myibnf.ibnfid)
    resp = send_request(remoteibnfhandler, HTTPMessages.UNINSTALL_INTENT, Dict(HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid, HTTPMessages.IDAGNODEID => string(idagnodeid), HTTPMessages.VERBOSE => verbose))
    return JSON.parse(String(resp.body))
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
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestuncompileintent_term!(myibnfhandler, remoteibnf, idagnodeid; verbose=false, @passtime)
end

@recvtime function requestuncompileintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, idagnodeid::UUID; verbose::Bool=false)
    initiator_ibnfid = string(myibnf.ibnfid)
    resp = send_request(remoteibnfhandler, HTTPMessages.UNCOMPILE_INTENT, Dict(HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid, HTTPMessages.IDAGNODEID => string(idagnodeid), HTTPMessages.VERBOSE => verbose))
    return_compile_init = JSON.parse(String(resp.body))
    return Symbol(return_compile_init)
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
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestissatisfied_term!(myibnfhandler, remoteibnf, idagnodeid; onlyinstalled, noextrallis)
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
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    requestremoteintentstateupdate_term!(myibnfhandler, remoteibnf, idagnodeid, newstate; @passtime)
end

@recvtime function requestremoteintentstateupdate_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, idagnodeid::UUID, newstate::IntentState.T)   
    initiator_ibnfid = string(myibnf.ibnfid)
    resp = send_request(remoteibnfhandler, HTTPMessages.REMOTEINTENT_STATEUPDATE, Dict(HTTPMessages.IDAGNODEID => string(idagnodeid), HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid, HTTPMessages.NEWSTATE => string(newstate)); @passtime)
    return Bool.(JSON.parse(String(resp.body)))
end

@recvtime function requestremoteintentstateupdate_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID, newstate::IntentState.T)
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
function requestibnattributegraph_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework)
    return getibnag(myibnf)
end

"""
MA1069 implementation
"""
function requestidag_init(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)
    resp = send_request(remoteibnfhandler, HTTPMessages.IDAG, Dict(HTTPMessages.INITIATOR_IBNFID => string(myibnf.ibnfid)))
    #resp_body = JSON.parse(String(resp.body))
    #@show resp_body
    #return resp_body
    #return JSON.parse(String(resp.body))

    
    idag = deserialize(IOBuffer(resp.body))
    #idag = deserialize(resp.body)
    #@show idag
    return idag
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
    initiator_ibnfid = string(myibnf.ibnfid)
    
    resp = send_request(remoteibnfhandler, HTTPMessages.SPECTRUM_AVAILABILITY, Dict(HTTPMessages.GLOBAL_EDGE => ge_data, HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid))
    if resp.status == 200
        return Bool.(JSON.parse(String(resp.body)))
    else
        error("Failed to request spectrum availability: $(resp.body)")
    end
    
end

function requestspectrumavailability_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, ge::GlobalEdge)
    myibnag = getibnag(myibnf)
    nodeviewsrc = getnodeview(myibnag, src(ge))
    nodeviewdst = getnodeview(myibnag, dst(ge))
    localnodesrc = something(getlocalnode(myibnag, src(ge)))
    localnodedst = something(getlocalnode(myibnag, dst(ge)))
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
"""

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
        
        
"""
$(TYPEDSIGNATURES) 

MA1069 implementation

Delegates an intent to another domain

Return the id of the new dag node if successful and `nothing` otherwise
"""
function requestdelegateintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, intent::AbstractIntent, internalidagnodeid::UUID)
    initiator_ibnfid = string(myibnf.ibnfid)
    serialized_intent = serialize_connectivity_intent(intent)
    
    resp = send_request(remoteibnfhandler, HTTPMessages.DELEGATE_INTENT, Dict(HTTPMessages.INTERNAL_IDAGNODEID => string(internalidagnodeid), HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid, HTTPMessages.INTENT => serialized_intent))
    uuid_returned = JSON.parse(String(resp.body))
    
    return UUID(uuid_returned["value"])
end

@recvtime function requestdelegateintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, intent::AbstractIntent, internalidagnodeid::UUID)
    remoteintent = RemoteIntent(getibnfid(remoteibnfhandler), internalidagnodeid, intent, false)
    #remoteintentdagnode = addidagnode!(getidag(myibnf), remoteintent; @passtime)
    remoteintentdagnode = addidagnode!(myibnf, remoteintent; @passtime)
    
    return getidagnodeid(remoteintentdagnode)
end

"""
$(TYPEDSIGNATURES)

MA1069 implementation
"""
function requestavailablecompilationalgorithms_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)
    initiator_ibnfid = string(myibnf.ibnfid)
    resp = send_request(remoteibnfhandler, HTTPMessages.COMPILATION_ALGORITHMS, Dict(HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid))
    return JSON.parse(String(resp.body))
end

function requestavailablecompilationalgorithms_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework)
    compalglist = [KSPFFalg]
    return compalglist
end

"""
$(TYPEDSIGNATURES) 

MA1069 implementation
"""

@recvtime function requestcompileintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=(); verbose::Bool = false)
    initiator_ibnfid = string(myibnf.ibnfid)
    resp = send_request(remoteibnfhandler, HTTPMessages.COMPILE_INTENT, 
        Dict(HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid, 
        HTTPMessages.IDAGNODEID => string(idagnodeid), 
        HTTPMessages.COMPILATION_KEY => string(compilationalgorithmkey), 
        HTTPMessages.COMPILATION_ARGS => JSON.json(compilationalgorithmargs)); @passtime)

    return_compile_init = JSON.parse(String(resp.body))
    return Symbol(return_compile_init)
    
end

"""
$(TYPEDSIGNATURES) 

MA1069 implementation

Request to `remoteibnf` whether the `idagnode` is theoretically satisfied
""" #before, here it was idagnode::IntentDAGNode, i dont know if it was an error
function requestissatisfied(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, idagnodeid::UUID; onlyinstalled::Bool, noextrallis::Bool)
    initiator_ibnfid = string(myibnf.ibnfid)
    resp = send_request(remoteibnfhandler, HTTPMessages.IS_SATISFIED, Dict(HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid, HTTPMessages.IDAGNODEID => string(idagnodeid), HTTPMessages.ONLY_INSTALLED => onlyinstalled, HTTPMessages.NOEXTRALLIS => noextrallis))
    return JSON.parse(String(resp.body))
end

function requestissatisfied_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID; onlyinstalled::Bool, noextrallis::Bool)
    return issatisfied(myibnf, idagnodeid; onlyinstalled, noextrallis)
end



function requestcurrentlinkstate_init(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, ge::GlobalEdge)
    ge_data = serialize_globaledge(ge)
    initiator_ibnfid = string(myibnf.ibnfid)

    resp = send_request(remoteibnfhandler, HTTPMessages.CURRENT_LINKSTATE, Dict(HTTPMessages.GLOBAL_EDGE => ge_data, HTTPMessages.INITIATOR_IBNFID => initiator_ibnfid))
    
    if resp.status == 200
        return Bool.(JSON.parse(String(resp.body)))
    else
        error("Failed to request current link state: $(resp.body)")
    end
end
