"""
$(TYPEDSIGNATURES)

Add a new user intent to the IBN framework.
"""
function addintent!(ibnf::IBNFramework, intent::AbstractIntent, intentissuer::IntentIssuer)
    intentdag = getidag(ibnf)
    return addidagnode!(intentdag, intent; intentissuer)
end

"""
$(TYPEDSIGNATURES)
"""
function removeintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool = false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled)
    return removeidagnode!(getidag(ibnf), idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function compileintent!(ibnf::IBNFramework, idagnodeid::UUID, algorithm::IntentCompilationAlgorithm)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled)
    intent = getidagnode(getidag(ibnf), UUID(1))
    compileintent!(ibnf, intent, algorithm)
    return updateidagstates!(getidag(ibnf), idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function uncompileintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Compiled)
    idagnodedescendants = getidagnodedescendants(getidag(ibnf), idagnodeid)
    foreach(idagnodedescendants) do idagnodedescendant
        removeidagnode!(getidag(ibnf), getidagnodeid(idagnodedescendant))
    end
    return updateidagstates!(getidag(ibnf), idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function installintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Compiled)
    # duplicate code with `@ref uninstallintent!`
    idagnodellis = getidagnodellis(getidag(ibnf), idagnodeid; exclusive = false)
    foreach(idagnodellis) do idagnodelli
        llintent = getintent(idagnodelli)
        llid = getidagnodeid(idagnodelli)
        localnode = getlocalnode(llintent)
        ibnag = getibnag(ibnf)
        nodeview = AG.vertex_attr(getibnag(ibnf))[localnode]
        if llintent isa TransmissionModuleLLI       
            reserve!(nodeview, llintent, llid; checkfirst=true, verbose)
        elseif llintent isa RouterPortLLI
            reserve!(getrouterview(nodeview), llintent, llid; checkfirst=true, verbose)
        elseif llintent isa OXCAddDropBypassSpectrumLLI
            reserve!(getoxcview(nodeview), llintent, llid; checkfirst=true, verbose)
        end
        pushstatetoidagnode!(getlogstate(idagnodelli), now(), IntentState.Installed)
    end
    return updateidagstates!(getidag(ibnf), idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function uninstallintent!(ibnf::IBNFramework, idagnodeid::UUID, verbose=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Installed)
    # duplicate code with `@ref installintent!`
    idagnodellis = getidagnodellis(getidag(ibnf), idagnodeid; exclusive = false)
    foreach(idagnodellis) do idagnodelli
        llintent = getintent(idagnodelli)
        llid = getidagnodeid(idagnodelli)
        localnode = getlocalnode(llintent)
        ibnag = getibnag(ibnf)
        nodeview = AG.vertex_attr(getibnag(ibnf))[localnode]
        if llintent isa TransmissionModuleLLI       
            unreserve!(nodeview, llid; verbose)
        elseif llintent isa RouterPortLLI
            unreserve!(getrouterview(nodeview), llid; verbose)
        elseif llintent isa OXCAddDropBypassSpectrumLLI
            unreserve!(getoxcview(nodeview), llid; verbose)
        end
        pushstatetoidagnode!(getlogstate(idagnodelli), now(), IntentState.Compiled)
    end
    return updateidagstates!(getidag(ibnf), idagnodeid)
end

"""
$(TYPEDSIGNATURES)

Get spectrum availabilities along a `path` of nodes as a `BitVector`
"""
function getpathspectrumavailabilities(ibnf::IBNFramework, localnodespath::Vector{LocalNode}; checkfirst::Bool = true)
    alllinkspectrumavailabilities = [getfiberspectrumavailabilities(ibnf, edg) for edg in edgeify(localnodespath)]
    return reduce(.&, alllinkspectrumavailabilities)
end

"""
$(TYPEDSIGNATURES)

Get the spectrum availability slots vector for `edge`
"""
function getfiberspectrumavailabilities(ibnf, edge::Edge{LocalNode}; checkfirst::Bool = true)
    nodeviews = AG.vertex_attr(getibnag(ibnf))
    if checkfirst
        @assert(
            getlinkspectrumavailabilities(getoxcview(nodeviews[src(edge)]))[edge] ==
                getlinkspectrumavailabilities(getoxcview(nodeviews[dst(edge)]))[edge]
        )
    end
    return getlinkspectrumavailabilities(getoxcview(nodeviews[src(edge)]))[edge]
end

"""
$(TYPEDSIGNATURES)
Get the transmission mode
"""
function gettransmissionmode(ibnf::IBNFramework, idagnode::IntentDAGNode{TransmissionModuleLLI})
    idagnodeid = getidagnodeid(idagnode)
    intent = getintent(idagnode)
    return gettransmissionmode(ibng, intent)
end

"""
$(TYPEDSIGNATURES)
Get the transmission mode
"""
function gettransmissionmode(ibnf::IBNFramework, intent::TransmissionModuleLLI)
    localnode = getlocalnode(intent)
    nodeview = getnodeview(getibnag(ibnf), localnode)
    transmissionmodesindex = gettransmissionmodesindex(intent)
    transmissionmoduleviewpoolindex = gettransmissionmoduleviewpoolindex(intent)
    reservedtransmissionmodule = gettransmissionmoduleviewpool(nodeview)[transmissionmoduleviewpoolindex]
    return gettransmissionmode(reservedtransmissionmodule, transmissionmodesindex)
end

"""
$(TYPEDSIGNATURES)
Get the reserved transmission mode
"""
function getreservedtransmissionmode(ibnf::IBNFramework, idagnode::IntentDAGNode{TransmissionModuleLLI}; verbose::Bool = false)
    idagnodeid = getidagnodeid(idagnode)
    intent = getintent(idagnode)
    localnode = getlocalnode(intent)
    nodeview = getnodeview(getibnag(ibnf), localnode)
    transmissionmodulereservations = getreservations(nodeview)
    @returniffalse(verbose, haskey(transmissionmodulereservations, idagnodeid))
    @returniffalse(verbose, transmissionmodulereservations[idagnodeid] == intent)
    transmissionmodesindex = gettransmissionmodesindex(intent)
    transmissionmoduleviewpoolindex = gettransmissionmoduleviewpoolindex(intent)
    reservedtransmissionmodule = gettransmissionmoduleviewpool(nodeview)[transmissionmoduleviewpoolindex]
    return gettransmissionmode(reservedtransmissionmodule, transmissionmodesindex)
end


"""
$(TYPEDSIGNATURES)

Convenience function that returns the `findfirst` for the global node 
"""
function findindexglobalnode(ibnag::IBNAttributeGraph, globalnode::GlobalNode)
    return findfirst(getnodeviews(ibnag)) do  nodeview
        getglobalnode(getnodeproperties(nodeview)) == globalnode
    end
end

"""
$(TYPEDSIGNATURES)

Return boolean if `globalnode` is in `ibnf` as a border node
"""
function isbordernode(globalnode::GlobalNode, ibnf::IBNFramework)
    return globalnode in getglobalnode.(getnodeproperties.(getnodeviews(getibnag(ibnf))))
end
