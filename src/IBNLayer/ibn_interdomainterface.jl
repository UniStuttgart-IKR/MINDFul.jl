# Every function in this file should be implemented for all `AbstractIBNFHandler`

"""
$(TYPEDSIGNATURES) 

Request topology information
"""
function requestibnattributegraph(myibnf::IBNFramework, remoteibnf::IBNFramework)
    return getibnag(remoteibnf)
end

"""
$(TYPEDSIGNATURES) 

Request spectrum slot availabilities of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""
function requestspectrumavailability(myibnf::IBNFramework, remoteibnf::IBNFramework, ge::GlobalEdge)
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

Return the id of the new dag node if successful and `nothing` otherwise
"""
function requestdelegateintent!(myibnf::IBNFramework, remoteibnf::IBNFramework, intent::AbstractIntent, internalidagnodeid::UUID)
    remoteintent = RemoteIntent(getibnfid(myibnf), internalidagnodeid, intent, false)
    remoteintentdagnode = addidagnode!(getidag(remoteibnf), remoteintent)
    return getidagnodeid(remoteintentdagnode)
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
function requestcompileintent_init!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=())
    requestcompileintent_term!(myibnf, remoteibnf, idagnodeid, compilationalgorithmkey, compilationalgorithmargs)
end

"""
$(TYPEDSIGNATURES) 

The initiator domain `remoteibnf` asks this domain `myibnf` to compile the internal remote intent `idagnodeid` with the specified compilation algorithm
"""
function requestcompileintent_term!(remoteibnf::IBNFramework, myibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=())
    # get the algorithm
    compilationalgorithm = getcompilationalgorithm(myibnf, compilationalgorithmkey, compilationalgorithmargs)
    return compileintent!(myibnf, idagnodeid, compilationalgorithm)
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
function requestremoteintentstateupdate!(myibnf::IBNFramework, remoteibnf::IBNFramework, idagnodeid::UUID, newstate::IntentState.T)
    oldstate = getidagnodestate(getidag(remoteibnf), idagnodeid)
    if oldstate != newstate
        idagnode = getidagnode(getidag(remoteibnf), idagnodeid)
        pushstatetoidagnode!(idagnode, now(), newstate)
        foreach(getidagnodeparents(getidag(remoteibnf), idagnodeid)) do idagnodeparent
            updateidagnodestates!(remoteibnf, idagnodeparent)
        end
    end
    return oldstate != newstate
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation
If far away, think about authorization and permissions.
That's the reason why there are 2 arguments: The first argument should have the authorization.
"""
function requestibnattributegraph(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)
    error("not implemented")
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation

Request spectrum slot availabilities of the border edge
Need to check whether `ge` is indeed an edge shared with `myibnf`
"""
function requestspectrumavailability(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, ge::GlobalEdge)
    error("not implemented")
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation

Delegates an intent to another domain

Return the id of the new dag node if successful and `nothing` otherwise
"""
function requestdelegateintent!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, intent::AbstractIntent, internalidagnodeid::UUID)
    error("not implemented")
end

"""
$(TYPEDSIGNATURES)

Fabian Gobantes implementation
"""
function requestavailablecompilationalgorithms(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler)
    error("not implemented")
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation
"""
function requestcompileintent_init!(myibnf::IBNFramework, remoteibnfhandler::RemoteIBNFHandler, compilationalgorithm::Symbol=:default, compilationalgorithmkey::Tuple=())
    error("not implemented")
end

"""
$(TYPEDSIGNATURES) 
Fabian Gobantes implementation

The initiator domain `remoteibnf` asks this domain `myibnf` to compile the internal remote intent `idagnodeid` with the specified compilation algorithm
"""
function requestcompileintent_term!(remoteibnfhandler::RemoteIBNFHandler, myibnf::IBNFramework, idagnodeid::UUID, compilationalgorithmkey::Symbol=:default, compilationalgorithmargs::Tuple=())
    error("not implemented")
end

"""
$(TYPEDSIGNATURES) 

Fabian Gobantes implementation

Request to `remoteibnf` whether the `idagnode` is theoretically satisfied
"""
function requestissatisfied(myibnf::IBNFramework, remoteibnf::RemoteIBNFHandler, idagnode::IntentDAGNode; onlyinstalled::Bool, noextrallis::Bool)
    error("not implemented")
end
