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
function requestibnattributegraph_init(myibnf::IBNFramework, remoteibnf::IBNFramework)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestibnattributegraph_term!(myibnfhandler, remoteibnf)
end

function requestibnattributegraph_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_IBNAGRAPH, Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid))
    if resp.status == 200
        return deserialize(IOBuffer(resp.body))
    else
        error("Failed to get IBNAttributeGraph: $(resp.body)")
    end
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

Request the handlers of the handler
"""
function requestibnfhandlers_init(myibnf::IBNFramework, remoteibnf::IBNFramework)
    myibnfhandler = getibnfhandler(remoteibnf)
    return requestibnfhandlers_term(myibnfhandler, remoteibnf)
end

function requestibnfhandlers_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_REQUESTHANDLERS, Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid))
    
    if resp.status == 200
        ibnfhandlers = [RemoteHTTPHandler(UUID(d[HTTPMessages.KEY_IBNFID][HTTPMessages.KEY_VALUE]), 
                        d[HTTPMessages.KEY_BASEURL], 
                        d[HTTPMessages.KEY_PERMISSION], 
                        d[HTTPMessages.KEY_GENTOKEN],
                        d[HTTPMessages.KEY_RECVTOKEN]) for d in JSON.parse(String(resp.body))]
        return ibnfhandlers
    else
        error("Failed to get IBNFHandlers: $(JSON.parse(String(resp.body)))")
    end
    
end

function requestibnfhandlers_term(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework)
    return getibnfhandlers(myibnf)
end

"""
$(TYPEDSIGNATURES)

Request logical low level intent sequence
"""
function requestlogicallliorder_init(myibnf::IBNFramework, remoteibnf::IBNFramework, intentuuid::UUID; onlyinstalled = true, verbose::Bool = false)
    myibnfhandler = getibnfhandler(remoteibnf)
    return requestlogicallliorder_term(myibnfhandler, remoteibnf, intentuuid; onlyinstalled, verbose)
end

function requestlogicallliorder_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, intentuuid::UUID; onlyinstalled = true, verbose::Bool = false)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_LOGICALORDER, 
        Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_ONLYINSTALLED => onlyinstalled, 
        HTTPMessages.KEY_VERBOSE => verbose, 
        HTTPMessages.KEY_INTENTUUID => string(intentuuid)))
    
    if resp.status == 200
        parsedjson = JSON.parse(String(resp.body))
        logicalorder = [deserializelowlevelintent(d) for d in parsedjson]
        return logicalorder
    else
        error("Failed to get logical low level intent sequence: $parsedjson")
    end
        
    
end

function requestlogicallliorder_term(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, intentuuid::UUID; onlyinstalled = true, verbose::Bool = false)
    return getlogicallliorder(myibnf, intentuuid; onlyinstalled, verbose)
end

"""
$(TYPEDSIGNATURES) 

Request spectrum slot availabilities of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""
function requestspectrumavailability_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, ge::GlobalEdge)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestspectrumavailability_term!(myibnfhandler, remoteibnf, ge)
end

"""
$(TYPEDSIGNATURES) 

Request the path that is implementing intent `intentuuid` in the remote IBN framework as global node vector
"""
function requestintentglobalpath_init(myibnf::IBNFramework, remoteibnf::IBNFramework, intentuuid::UUID; onlyinstalled::Bool = true)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestintentglobalpath_term(myibnfhandler, remoteibnf, intentuuid; onlyinstalled)
end

function requestintentglobalpath_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, intentuuid::UUID; onlyinstalled::Bool = true)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_INTENTGLOBALPATH, 
        Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_INTENTUUID => string(intentuuid), 
        HTTPMessages.KEY_ONLYINSTALLED => onlyinstalled))

    if resp.status == 200
        parsedjson = JSON.parse(String(resp.body))
        intentglobalpath = [GlobalNode(UUID(path[HTTPMessages.KEY_IBNFID]), path[HTTPMessages.KEY_LOCALNODE]) for path in parsedjson]
        return intentglobalpath
    else
        error("Failed to get intent global path: $parsedjson")
    end
    
    
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

function requestglobalnodeelectricalpresence_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, intentuuid::UUID; onlyinstalled::Bool = true)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_ELECTRICALPRESENCE, 
        Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_INTENTUUID => string(intentuuid), 
        HTTPMessages.KEY_ONLYINSTALLED => onlyinstalled))
    
    if resp.status == 200
        parsedjson = JSON.parse(String(resp.body))
        electricalpresence = [GlobalNode(UUID(path[HTTPMessages.KEY_IBNFID]), path[HTTPMessages.KEY_LOCALNODE]) for path in parsedjson]
        return electricalpresence
    else
        error("Failed to get global node electrical presence: $parsedjson")
    end
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

function requestintentgloballightpaths_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, intentuuid::UUID; onlyinstalled::Bool = true)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_LIGHTPATHS, 
        Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_INTENTUUID => string(intentuuid), 
        HTTPMessages.KEY_ONLYINSTALLED => onlyinstalled))
    
    if resp.status == 200
        parsedjson = JSON.parse(String(resp.body))
        lightpaths = [GlobalNode[GlobalNode(UUID(node[HTTPMessages.KEY_IBNFID]), node[HTTPMessages.KEY_LOCALNODE]) for node in path] for path in parsedjson]
        return lightpaths
    else
        error("Failed to get intent global light paths: $parsedjson")
    end
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
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestlinkstates_term(myibnfhandler, remoteibnf, ge)
end

function requestlinkstates_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, ge::GlobalEdge)
    gedata = serializeglobaledge(ge)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_REQUESTLINKSTATES, 
        Dict(HTTPMessages.KEY_GLOBALEDGE => gedata, HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid))

    if resp.status == 200
        parsed = JSON.parse(String(resp.body))
        result = [(DateTime(item[HTTPMessages.KEY_LINKDATETIME]), Bool(item[HTTPMessages.KEY_LINKSTATE])) for item in parsed]
        return result
    else
        error("Failed to set link state: $parsed")
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
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestsetlinkstate_term!(myibnfhandler, remoteibnf, ge, operatingstate; @passtime)
end

@recvtime function requestsetlinkstate_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, ge::GlobalEdge, operatingstate::Bool)
    gedata = serializeglobaledge(ge)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_SETLINKSTATE, 
        Dict(HTTPMessages.KEY_GLOBALEDGE => gedata, 
        HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_OPERATINGSTATE => operatingstate); @passtime)

    if resp.status == 200
        return Symbol(JSON.parse(String(resp.body)))
    else
        error("Failed to set link state: $(JSON.parse(String(resp.body)))")
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
    compilationalgorithm = getcompilationalgorithm(myibnf, compilationalgorithmkey, compilationalgorithmargs)
    return compileintent!(myibnf, idagnodeid, compilationalgorithm; verbose, @passtime)
end

"""
$(TYPEDSIGNATURES) 
"""
@recvtime function requestinstallintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestinstallintent_term!(myibnfhandler, remoteibnf, idagnodeid; verbose=false, @passtime)
end

@recvtime function requestinstallintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, idagnodeid::UUID; verbose::Bool=false)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_INSTALLINTENT, 
        Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_IDAGNODEID => string(idagnodeid), 
        HTTPMessages.KEY_VERBOSE => verbose); @passtime)

    if resp.status == 200
        return JSON.parse(String(resp.body))
    else
        error("Failed to install intent: $(JSON.parse(String(resp.body)))")
    end
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
    return requestuninstallintent_term!(myibnfhandler, remoteibnf, idagnodeid; verbose, @passtime)
end

@recvtime function requestuninstallintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, idagnodeid::UUID; verbose::Bool=false)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_UNINSTALLINTENT, 
        Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_IDAGNODEID => string(idagnodeid), 
        HTTPMessages.KEY_VERBOSE => verbose); @passtime)

    if resp.status == 200
        return JSON.parse(String(resp.body))
    else
        error("Failed to uninstall intent: $(JSON.parse(String(resp.body)))")
    end
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

@recvtime function requestuncompileintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, idagnodeid::UUID; verbose::Bool=false)
    initiatoribnfid = string(getibnfid(myibnf))
    
    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_UNCOMPILEINTENT, 
        Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_IDAGNODEID => string(idagnodeid), 
        HTTPMessages.KEY_VERBOSE => verbose); @passtime)
    returncompileinit = JSON.parse(String(resp.body))

    if resp.status == 200
        return Symbol(returncompileinit)
    else
        error("Failed to uncompile intent: $returncompileinit")
    end
    
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
function requestissatisfied_init(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID; onlyinstalled::Bool=true, noextrallis::Bool=true)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    return requestissatisfied_term!(myibnfhandler, remoteibnf, idagnodeid; onlyinstalled, noextrallis)
end

"""
$(TYPEDSIGNATURES) 

Request the initiator `remoteibnf` to update the state of its mirrored remote intent
"""
@recvtime function requestremoteintentstateupdate_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID, newstate::IntentState.T)
    myibnfhandler = getibnfhandler(remoteibnf, getibnfid(myibnf))
    requestremoteintentstateupdate_term!(myibnfhandler, remoteibnf, idagnodeid, newstate; @passtime)
end

@recvtime function requestremoteintentstateupdate_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, idagnodeid::UUID, newstate::IntentState.T)   
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_REMOTEINTENTSTATEUPDATE, 
        Dict(HTTPMessages.KEY_IDAGNODEID => string(idagnodeid), 
        HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_NEWSTATE => string(newstate)); @passtime)

    if resp.status == 200
        return Bool.(JSON.parse(String(resp.body)))
    else
        error("Failed to update remote intent state: $(JSON.parse(String(resp.body)))")
    end
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
function requestidag_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_REQUESTIDAG, Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid))

    if resp.status == 200
        idag = deserialize(IOBuffer(resp.body))
        return idag
    else
        error("Failed to get IBNAttributeGraph: $(JSON.parse(String(resp.body)))")
    end
    
end
"""
$(TYPEDSIGNATURES) 

MA1069 implementation

Request spectr /um slot availabilities of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""
function requestspectrumavailability_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, ge::GlobalEdge)
    gedata = serializeglobaledge(ge)
    initiatoribnfid = string(getibnfid(myibnf))
    
    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_SPECTRUMAVAILABILITY, 
        Dict(HTTPMessages.KEY_GLOBALEDGE => gedata, HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid))

    if resp.status == 200
        return Bool.(JSON.parse(String(resp.body)))
    else
        error("Failed to request spectrum availability: $(JSON.parse(String(resp.body)))")
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

Delegates an intent to another domain

Return the id of the new dag node if successful and `nothing` otherwise
"""
@recvtime function requestdelegateintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, intent::AbstractIntent, internalidagnodeid::UUID)
    initiatoribnfid = string(getibnfid(myibnf))
    serializedintent = serializeconnectivityintent(intent)
    
    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_DELEGATEINTENT, 
        Dict(HTTPMessages.KEY_INTERNALIDAGNODEID => string(internalidagnodeid), 
        HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_INTENT => serializedintent); @passtime)

    if resp.status == 200
        uuidreturned = JSON.parse(String(resp.body))
        return UUID(uuidreturned[HTTPMessages.KEY_VALUE])
    else
        error("Failed to delegate intent: $uuidreturned")
    end
end

@recvtime function requestdelegateintent_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, intent::AbstractIntent, internalidagnodeid::UUID)
    remoteintent = RemoteIntent(getibnfid(remoteibnfhandler), internalidagnodeid, intent, false)
    remoteintentdagnode = addidagnode!(myibnf, remoteintent; @passtime)
    return getidagnodeid(remoteintentdagnode)
end

"""
$(TYPEDSIGNATURES)

MA1069 implementation
"""
function requestavailablecompilationalgorithms_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_COMPILATIONALGORITHMS, Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid))

    if resp.status == 200
        return JSON.parse(String(resp.body))
    else
        error("Failed to get available compilation algorithms: $(JSON.parse(String(resp.body)))")
    end
end

function requestavailablecompilationalgorithms_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework)
    compalglist = [KSPFFalg]
    return compalglist
end

"""
$(TYPEDSIGNATURES) 

MA1069 implementation
"""
@recvtime function requestcompileintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=(); verbose::Bool = false)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_COMPILEINTENT, 
        Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_IDAGNODEID => string(idagnodeid), 
        HTTPMessages.KEY_COMPILATIONKEY => string(compilationalgorithmkey), 
        HTTPMessages.KEY_COMPILATIONARGS => JSON.json(compilationalgorithmargs)); @passtime)

    if resp.status == 200
        returncompileinit = JSON.parse(String(resp.body))
        return Symbol(returncompileinit)
    else
        error("Failed to compile intent: $returncompileinit")
    end
end

"""
$(TYPEDSIGNATURES) 

MA1069 implementation

Request to `remoteibnf` whether the `idagnode` is theoretically satisfied
"""
function requestissatisfied_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, idagnodeid::UUID; onlyinstalled::Bool=true, noextrallis::Bool=true)
    initiatoribnfid = string(getibnfid(myibnf))
    
    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_ISSATISFIED, 
        Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, 
        HTTPMessages.KEY_IDAGNODEID => string(idagnodeid), 
        HTTPMessages.KEY_ONLYINSTALLED => onlyinstalled, 
        HTTPMessages.KEY_NOEXTRALLIS => noextrallis))

    issatisfiedreturn = JSON.parse(String(resp.body))
    if resp.status == 200
        if issatisfiedreturn == true
            return true
        elseif issatisfiedreturn == false
            return false
        else
            return Symbol(issatisfiedreturn)
        end
    else
        error("Failed to check if intent is satisfied: $issatisfiedreturn")
    end
    
end

function requestissatisfied_term!(remoteibnfhandler::AbstractIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID; onlyinstalled::Bool, noextrallis::Bool)
    return issatisfied(myibnf, idagnodeid; onlyinstalled, noextrallis)
end


function requestcurrentlinkstate_init(myibnf::IBNFramework, remoteibnfhandler::RemoteHTTPHandler, ge::GlobalEdge)
    gedata = serializeglobaledge(ge)
    initiatoribnfid = string(getibnfid(myibnf))

    resp = sendrequest(remoteibnfhandler, HTTPMessages.URI_CURRENTLINKSTATE, 
    Dict(HTTPMessages.KEY_GLOBALEDGE => gedata, 
    HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid))
    
    if resp.status == 200
        return Bool.(JSON.parse(String(resp.body)))
    else
        error("Failed to request current link state: $(JSON.parse(String(resp.body)))")
    end
end


function handshake_init(initiatoribnfid::String, remoteibnfhandler::RemoteHTTPHandler)
    myibnfid = string(initiatoribnfid)
    url = getbaseurl(remoteibnfhandler) * HTTPMessages.URI_HANDSHAKE

    if getibnfhandlerperm(remoteibnfhandler) == "none"
        availablefunctions = HTTPMessages.KEY_NOTHING
    elseif getibnfhandlerperm(remoteibnfhandler) == "full"
        availablefunctions = HTTPMessages.LIST_ALLFUNCTIONS
    else
        availablefunctions = HTTPMessages.LIST_LIMITEDFUNCTIONS 
    end 
    
    generatedtoken = string(uuid4())
    remoteibnfhandler.gentoken = generatedtoken
    
    data = Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid, HTTPMessages.KEY_TOKEN => generatedtoken, HTTPMessages.KEY_AVAILABLEFUNCTIONS => availablefunctions)
    body = JSON.json(data)  
    headers = Dict("Content-Type" => "application/json")

    response = HTTP.post(url, headers, body; keepalive=false, require_ssl_verification=false)

    if response.status == 200
        parsedresponse = JSON.parse(String(response.body))
        functions = parsedresponse[HTTPMessages.KEY_AVAILABLEFUNCTIONS]
        remoteibnfid = string(getibnfid(remoteibnfhandler))
        # println("\nDomain $myibnfid has access to the following functions in remote domain $remoteibnfid: $functions \n")
        recievedtoken = parsedresponse[HTTPMessages.KEY_TOKEN]
        remoteibnfhandler.recvtoken = recievedtoken
        return recievedtoken
    else
        error("Handshake failed with $remoteibnfhandler: $(response.status)")
    end
end


function handshake_term(initiatoribnfid::String, remoteibnfhandler::RemoteHTTPHandler)
    url = getbaseurl(remoteibnfhandler) * HTTPMessages.URI_HANDSHAKE

    if getibnfhandlerperm(remoteibnfhandler) == "none"
        availablefunctions = HTTPMessages.KEY_NOTHING
    elseif getibnfhandlerperm(remoteibnfhandler) == "full"
        availablefunctions = HTTPMessages.LIST_ALLFUNCTIONS
    else
        availablefunctions = HTTPMessages.LIST_LIMITEDFUNCTIONS
    end 
    
    generatedtoken = string(uuid4())
    remoteibnfhandler.gentoken = generatedtoken

    return generatedtoken, availablefunctions
end
