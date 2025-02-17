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
    intentdag = getidag(ibnf)
    intentdagstate = getidagnodestate(intentdag, idagnodeid)
    @returniffalse(verbose, intentdagstate == IntentState.Uncompiled)
    return removeidagnode!(intentdag, idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function compileintent!(ibnf::IBNFramework, idagnodeid::UUID, algorithm::IntentCompilationAlgorithm)
    intent = getidagnode(getidag(ibnf), UUID(1))
    compileintent!(ibnf, intent, algorithm)
    return updateidagstates!(getidag(ibnf), idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function uncompileintent!(ibnf::IBNFramework, idagnodeid::UUID)
end

"""
$(TYPEDSIGNATURES)
"""
function installintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Compiled)
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
        idagnode = getidagnode(getidag(ibnf), llid)
        pushstatetoidagnode!(getlogstate(idagnodelli), now(), IntentState.Installed)
    end
    updateidagstates!(getidag(ibnf), idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function uninstallintent!(ibnfid::IBNFramework, idagnodeid::UUID, verbose=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Compiled)
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

