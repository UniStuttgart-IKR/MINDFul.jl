"""
$(TYPEDSIGNATURES)
kk
Add a new user intent to the IBN framework and return the id.
"""
@recvtime function addintent!(ibnf::IBNFramework, intent::AbstractIntent, intentissuer::IntentIssuer)
    idagnode =  addidagnode!(ibnf, intent; intentissuer)
    return getidagnodeid(idagnode)
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function removeintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool = false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled)
    return removeidagnode!(getidag(ibnf), idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFramework, idagnodeid::UUID, algorithm::IntentCompilationAlgorithm; verbose::Bool=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled)
    idagnode = getidagnode(getidag(ibnf), idagnodeid)
    return compileintent!(ibnf, idagnode, algorithm; verbose, @passtime)
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:RemoteIntent}, algorithm::IntentCompilationAlgorithm; verbose::Bool = false)
    if !getisinitiator(getintent(idagnode))
        idagnodechild = addidagnode!(ibnf, getintent(getintent(idagnode)); parentid = getidagnodeid(idagnode), intentissuer = MachineGenerated(), @passtime)
        return compileintent!(ibnf, idagnodechild, algorithm; verbose, @passtime)
    else
        return ReturnCodes.FAIL
    end
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function uncompileintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) in [IntentState.Compiled, IntentState.Uncompiled, IntentState.Pending])
    idagnodedescendants = getidagnodedescendants(getidag(ibnf), idagnodeid)
    foreach(idagnodedescendants) do idagnodedescendant
        if getintent(idagnodedescendant) isa RemoteIntent
            ibnfhandler = getibnfhandler(ibnf, getibnfid(getintent(idagnodedescendant)))
            uncompiledflag = requestuncompileintent_init!(ibnf, ibnfhandler, getidagnodeid(getintent(idagnodedescendant)); verbose, @passtime)
            if uncompiledflag == ReturnCodes.SUCCESS
                removeidagnode!(getidag(ibnf), getidagnodeid(idagnodedescendant))
            end
        else
            @returniffalse(verbose, getidagnodestate(idagnodedescendant) in [IntentState.Compiled, IntentState.Uncompiled, IntentState.Pending])
            removeidagnode!(getidag(ibnf), getidagnodeid(idagnodedescendant))
            if getintent(idagnodedescendant) isa LowLevelIntent
                stageunstageleafintent!(ibnf, getintent(idagnodedescendant), false)
            end
        end
    end
    updateidagstates!(ibnf, idagnodeid; @passtime)
    if getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled
        return ReturnCodes.SUCCESS
    else
        return ReturnCodes.FAIL
    end
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function installintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Compiled)
    idagnodeleafs = getidagnodeleafs(getidag(ibnf), idagnodeid; exclusive = false)
    foreach(idagnodeleafs) do idagnodeleaf
            reserveunreserveleafintents!(ibnf, idagnodeleaf, true; verbose, @passtime)
    end
    if getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Installed
        return ReturnCodes.SUCCESS
    else
        return ReturnCodes.FAIL
    end
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function uninstallintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) ∈ [IntentState.Installed, IntentState.Failed])
    idagnodeleafs = getidagnodeleafs(getidag(ibnf), idagnodeid; exclusive = false)
    foreach(idagnodeleafs) do idagnodeleaf
        reserveunreserveleafintents!(ibnf, idagnodeleaf, false; verbose, @passtime)
    end
    if getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Compiled
        return ReturnCodes.SUCCESS
    else
        return ReturnCodes.FAIL
    end
end

"""
$(TYPEDSIGNATURES)

to reserve pass `doinstall=true`, and to unreserve `doinstall=false`
"""
@recvtime function reserveunreserveleafintents!(ibnf::IBNFramework, idagnodeleaf::IntentDAGNode, doinstall::Bool; verbose::Bool=false)
    leafintent = getintent(idagnodeleaf)
    leafid = getidagnodeid(idagnodeleaf)
    if leafintent isa LowLevelIntent
        localnode = getlocalnode(leafintent)
        nodeview = AG.vertex_attr(getibnag(ibnf))[localnode]
        successflag = if leafintent isa TransmissionModuleLLI       
            if doinstall
                reserve!(getsdncontroller(ibnf), nodeview, leafintent, leafid; checkfirst=true, verbose)
            else
                unreserve!(getsdncontroller(ibnf), nodeview, leafid; verbose)
            end
        elseif leafintent isa RouterPortLLI
            if doinstall
                reserve!(getsdncontroller(ibnf), getrouterview(nodeview), leafintent, leafid; checkfirst=true, verbose)
            else
                unreserve!(getsdncontroller(ibnf), getrouterview(nodeview), leafid; verbose)
            end
        elseif leafintent isa OXCAddDropBypassSpectrumLLI
            if doinstall
                reserve!(getsdncontroller(ibnf), getoxcview(nodeview), leafintent, leafid; checkfirst=true, verbose)
            else
                unreserve!(getsdncontroller(ibnf), getoxcview(nodeview), leafid; verbose)
            end
        end
        issuccessfull = issuccess(successflag)
        if doinstall
            if issuccessfull
                pushstatetoidagnode!(getlogstate(idagnodeleaf), IntentState.Installed; @passtime)
                stageunstageleafintent!(ibnf, leafintent, false)
            end
        else
            if issuccessfull
                pushstatetoidagnode!(getlogstate(idagnodeleaf), IntentState.Compiled; @passtime)
                stageunstageleafintent!(ibnf, leafintent, true)
            end
        end
    elseif leafintent isa RemoteIntent
        if getisinitiator(leafintent)
            ibnfhandler = getibnfhandler(ibnf, getibnfid(leafintent))
            if doinstall
                requestinstallintent_init!(ibnf, ibnfhandler, getidagnodeid(leafintent); verbose, @passtime)
            else
                requestuninstallintent_init!(ibnf, ibnfhandler, getidagnodeid(leafintent); verbose, @passtime)
            end
        end
    end
    # call updateidagstates
    return any(getidagnodeparents(getidag(ibnf), idagnodeleaf)) do idagnodeparent
        updateidagnodestates!(ibnf, idagnodeparent; @passtime)
    end
end

"""
$(TYPEDSIGNATURES)

Stage lli as compiled in the equipment and add LLI in the intent DAG.
Staged LLIs are not reserved but used to know that they will be in the future.
"""
@recvtime function stageaddidagnode!(ibnf::IBNFramework, lli::LowLevelIntent; parentid::Union{Nothing, UUID} = nothing, intentissuer = MachineGenerated())
    idagnode = addidagnode!(ibnf, lli; parentid, intentissuer, @passtime)
    stageunstageleafintent!(ibnf, lli, true)
end

"""
$(TYPEDSIGNATURES)
`dostage` `true` for stage, `false` for unstage
"""
function stageunstageleafintent!(ibnf::IBNFramework, lli::LowLevelIntent, dostage::Bool)
    localnode = getlocalnode(lli)
    nodeview = AG.vertex_attr(getibnag(ibnf))[localnode]

    successflag = if lli isa TransmissionModuleLLI       
        if dostage
            stage!(nodeview, lli)
        else
            unstage!(nodeview, lli)
        end
    elseif lli isa RouterPortLLI
        if dostage
            stage!(getrouterview(nodeview), lli)
        else
            unstage!(getrouterview(nodeview), lli)
        end
    elseif lli isa OXCAddDropBypassSpectrumLLI
        if dostage
            stage!(getoxcview(nodeview), lli)
        else
            unstage!(getoxcview(nodeview), lli)
        end
    end
end

"""
$(TYPEDSIGNATURES)

Add a `RemoteIntent` as a child intent and delegate it to the ibn with id `remoteibndif`
"""
@recvtime function remoteintent!(ibnf::IBNFramework, idagnode::IntentDAGNode, remoteibnfid::UUID)
    ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
    internalnextidagnodeid = getidagnextuuidcounter(getidag(ibnf))
    remoteidagnodeid = requestdelegateintent_init!(ibnf, ibnfhandler, getintent(idagnode), internalnextidagnodeid)
    @show remoteidagnodeid
    # add an idagnode `RemoteIntent`
    remoteintent = RemoteIntent(remoteibnfid, remoteidagnodeid, getintent(idagnode), true)

    # add in DAG
    internalidagnode = addidagnode!(ibnf, remoteintent; parentid=getidagnodeid(idagnode), intentissuer=MachineGenerated(), @passtime)
    @assert internalnextidagnodeid == getidagnodeid(internalidagnode)

    return internalidagnode
end

"""
$(TYPEDSIGNATURES)

Get spectrum availabilities along a `path` of nodes as a `BitVector`
"""
function getpathspectrumavailabilities(ibnf::IBNFramework, localnodespath::Vector{LocalNode}; checkfirst::Bool = true)
    alllinkspectrumavailabilities = [getfiberspectrumavailabilities(ibnf, edg; checkfirst) for edg in edgeify(localnodespath)]
    return reduce(.&, alllinkspectrumavailabilities)
end

"""
$(TYPEDSIGNATURES)

Get the spectrum availability slots vector for `edge`
"""
function getfiberspectrumavailabilities(ibnf::IBNFramework, edge::Edge{LocalNode}; checkfirst::Bool = true, verbose::Bool=false)
    @show getibnfid(ibnf)
    @show edge
    ibnag = getibnag(ibnf) 
    edsrc = src(edge)
    nodeviewsrc = getnodeview(ibnag, edsrc)
    eddst = dst(edge)
    nodeviewdst = getnodeview(ibnag, eddst)
    issrcbordernode = isbordernode(ibnf, edsrc)
    isdstbordernode = isbordernode(ibnf, eddst)
    @returniffalse(verbose, !(issrcbordernode && isdstbordernode))
    nodeviews = AG.vertex_attr(getibnag(ibnf))
    if checkfirst
        globaledge = GlobalEdge(getglobalnode(ibnag, edsrc), getglobalnode(ibnag, eddst))
        srclinkspectrumavailabilities = if issrcbordernode  
            remoteibnfid = getibnfid(getglobalnode(ibnag, src(edge)))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            something(requestspectrumavailability_init!(ibnf, ibnfhandler, globaledge))
        else 
            getlinkspectrumavailabilities(getoxcview(nodeviewsrc))[edge]
        end

        dstlinkspectrumavailabilities = if isdstbordernode  
            remoteibnfid = getibnfid(getglobalnode(ibnag, dst(edge)))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            something(requestspectrumavailability_init!(ibnf, ibnfhandler, globaledge))
        else
            getlinkspectrumavailabilities(getoxcview(nodeviewdst))[edge]
        end

        @assert(srclinkspectrumavailabilities == dstlinkspectrumavailabilities)
        return srclinkspectrumavailabilities
    else
        if !issrcbordernode
            return getlinkspectrumavailabilities(getoxcview(nodeviewsrc))[edge]
        elseif !isdstbordernode
            return getlinkspectrumavailabilities(getoxcview(nodeviewdst))[edge]
        end
    end
end

"""
$(TYPEDSIGNATURES)
"""
function getfiberspectrumavailabilities(ibnag::IBNAttributeGraph, edge::Edge{LocalNode}; checkfirst::Bool = true)
    edsrc = src(edge)
    nodeviewsrc = getnodeview(ibnag, edsrc)
    eddst = dst(edge)
    nodeviewdst = getnodeview(ibnag, eddst)
    if checkfirst && isnodeviewinternal(nodeviewsrc) && isnodeviewinternal(nodeviewdst) 
        srclinkspectrumavailabilities = getlinkspectrumavailabilities(getoxcview(nodeviewsrc))[edge]
        dstlinkspectrumavailabilities = getlinkspectrumavailabilities(getoxcview(nodeviewdst))[edge]
        @assert srclinkspectrumavailabilities == dstlinkspectrumavailabilities 
        return srclinkspectrumavailabilities
    else
        if isnodeviewinternal(nodeviewsrc)
            return getlinkspectrumavailabilities(getoxcview(nodeviewsrc))[edge]
        elseif isnodeviewinternal(nodeviewdst)
            return getlinkspectrumavailabilities(getoxcview(nodeviewdst))[edge]
        end
    end
end

"""
$(TYPEDSIGNATURES)
"""
function getcurrentlinkstate(ibnf::IBNFramework, edge::Edge; checkfirst::Bool=true, verbose::Bool=false)
    ibnag = getibnag(ibnf)
    edsrc = src(edge)
    nodeviewsrc = getnodeview(ibnag, edsrc)
    eddst = dst(edge)
    nodeviewdst = getnodeview(ibnag, eddst)
    issrcbordernode = isbordernode(ibnf, edsrc)
    isdstbordernode = isbordernode(ibnf, eddst)
    @returniffalse(verbose, !(issrcbordernode && isdstbordernode))
    if checkfirst
        globaledge = GlobalEdge(getglobalnode(ibnag, edsrc), getglobalnode(ibnag, eddst))
        srclinksstate = if issrcbordernode  
            remoteibnfid = getibnfid(getglobalnode(ibnag, edsrc))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            something(requestcurrentlinkstate_init(ibnf, ibnfhandler, globaledge))
        else 
            getcurrentlinkstate(getoxcview(nodeviewsrc), edge)
        end

        dstlinkstate = if isdstbordernode  
            remoteibnfid = getibnfid(getglobalnode(ibnag, eddst))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            something(requestcurrentlinkstate_init(ibnf, ibnfhandler, globaledge))
        else
            getcurrentlinkstate(getoxcview(nodeviewdst), edge)
        end

        @assert(srclinksstate == dstlinkstate)
        return srclinksstate
    else
        if !issrcbordernode
            return getcurrentlinkstate(getoxcview(nodeviewsrc), edge)
        elseif !isdstbordernode
            return getcurrentlinkstate(getoxcview(nodeviewdst), edge)
        end
    end
end

"""
$(TYPEDSIGNATURES)
"""
function getlinkstates(ibnf::IBNFramework, edge::Edge; checkfirst::Bool=true, verbose::Bool=false)
    ibnag = getibnag(ibnf)
    edsrc = src(edge)
    nodeviewsrc = getnodeview(ibnag, edsrc)
    eddst = dst(edge)
    nodeviewdst = getnodeview(ibnag, eddst)
    issrcbordernode = isbordernode(ibnf, edsrc)
    isdstbordernode = isbordernode(ibnf, eddst)
    @returniffalse(verbose, !(issrcbordernode && isdstbordernode))
    if checkfirst
        globaledge = GlobalEdge(getglobalnode(ibnag, edsrc), getglobalnode(ibnag, eddst))
        srclinksstates = if issrcbordernode  
            remoteibnfid = getibnfid(getglobalnode(ibnag, edsrc))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            something(requestlinkstates_init(ibnf, ibnfhandler, globaledge))
        else 
            getlinkstates(getoxcview(nodeviewsrc), edge)
        end

        dstlinkstates = if isdstbordernode  
            remoteibnfid = getibnfid(getglobalnode(ibnag, eddst))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            something(requestlinkstates_init(ibnf, ibnfhandler, globaledge))
        else
            getlinkstates(getoxcview(nodeviewdst), edge)
        end

        @assert(getindex.(srclinksstates, 2) == getindex.(dstlinkstates, 2))
        return srclinksstates
    else
        if !issrcbordernode
            return getlinkstates(getoxcview(nodeviewsrc), edge)
        elseif !isdstbordernode
            return getlinkstates(getoxcview(nodeviewdst), edge)
        end
    end
end

"""
$(TYPEDSIGNATURES)
Set the link state on both OXCView ends of `edge`
TODO: with recvtime
TODO: toggle OXCLLI to failed
"""
@recvtime function setlinkstate!(ibnf::IBNFramework, edge::Edge, operatingstate::Bool)
    ibnag = getibnag(ibnf)
    edsrc = src(edge)
    nodeviewsrc = getnodeview(ibnag, edsrc)
    eddst = dst(edge)
    nodeviewdst = getnodeview(ibnag, eddst)
    issrcbordernode = isbordernode(ibnf, edsrc)
    isdstbordernode = isbordernode(ibnf, eddst)
    @returniffalse(verbose, !(issrcbordernode && isdstbordernode))
    globaledge = GlobalEdge(getglobalnode(ibnag, edsrc), getglobalnode(ibnag, eddst))

    if issrcbordernode  
        remoteibnfid = getibnfid(getglobalnode(ibnag, edsrc))
        ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
        requestsetlinkstate_init!(ibnf, ibnfhandler, globaledge, operatingstate; @passtime)
    else 
        setlinkstate!(ibnf, getoxcview(nodeviewsrc), edge, operatingstate; @passtime)
    end

    if isdstbordernode  
        remoteibnfid = getibnfid(getglobalnode(ibnag, eddst))
        ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
        requestsetlinkstate_init!(ibnf, ibnfhandler, globaledge, operatingstate; @passtime)
    else
        setlinkstate!(ibnf, getoxcview(nodeviewdst), edge, operatingstate; @passtime)
    end
end

"""
$(TYPEDSIGNATURES)
Get the transmission mode
"""
function gettransmissionmode(ibnf::IBNFramework, idagnode::IntentDAGNode{TransmissionModuleLLI})
    intent = getintent(idagnode)
    return gettransmissionmode(ibnf, intent)
end

"""
$(TYPEDSIGNATURES)
Get the transmission mode
"""
function gettransmissionmodule(ibnf::IBNFramework, intent::TransmissionModuleLLI)
    localnode = getlocalnode(intent)
    nodeview = getnodeview(getibnag(ibnf), localnode)
    transmissionmoduleviewpoolindex = gettransmissionmoduleviewpoolindex(intent)
    return gettransmissionmoduleviewpool(nodeview)[transmissionmoduleviewpoolindex]
end

"""
$(TYPEDSIGNATURES)
Get the transmission mode
"""
function gettransmissionmode(ibnf::IBNFramework, intent::TransmissionModuleLLI)
    transmissionmodesindex = gettransmissionmodesindex(intent)
    reservedtransmissionmodule = gettransmissionmodule(ibnf, intent)
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

Return boolean if `globalnode` belongs to `ibnf`
"""
function isinternalnode(ibnf::IBNFramework, globalnode::GlobalNode)
    return getibnfid(globalnode) == getibnfid(ibnf)
end

"""
$(TYPEDSIGNATURES)

Return boolean if `globalnode` is in `ibnf` as a border node
"""
function isbordernode(ibnf::IBNFramework, globalnode::GlobalNode)
    return getibnfid(globalnode) != getibnfid(ibnf) && globalnode in getglobalnode.(getnodeproperties.(getnodeviews(getibnag(ibnf))))
end

"""
$(TYPEDSIGNATURES)

Return boolean if `localnode` is in `ibnf` as a border node
"""
function isbordernode(ibnf::IBNFramework, localnode::LocalNode)
    return isbordernode(ibnf, getglobalnode(getibnag(ibnf), localnode))
end

"""
$(TYPEDSIGNATURES)

Return all border nodes of `ibnf` with `localnode` representation
"""
function getbordernodesaslocal(ibnf::IBNFramework)
    ibnag = getibnag(ibnf)
    return [
        getlocalnode(getproperties(getnodeview(ibnag, v)))
        for v in vertices(ibnag) if isbordernode(ibnf, v)
    ]
end

"""
$(TYPEDSIGNATURES)

Return the number of local nodes, i.e. not border nodes.
"""
function getlocalnodenum(ibnf::IBNFramework)
    ibnag = getibnag(ibnf)
    return count(x -> !isbordernode(ibnf, x), vertices(ibnag))
end

"""
$(TYPEDSIGNATURES)

Return all border nodes of `ibnf` with `globalnode` representation
"""
function getbordernodesasglobal(ibnf::IBNFramework)
    ibnag = getibnag(ibnf)
    return [
        getglobalnode(getproperties(getnodeview(ibnag, v)))
        for v in vertices(ibnag) if isbordernode(ibnf, v)
    ]
end

"""
$(TYPEDSIGNATURES)

Return all border edges that contain at least one border node as endpoints
"""
function getborderedges(ibnf::IBNFramework)
    ibnag = getibnag(ibnf)
    return filter(collect(edges(ibnag))) do e
        isbordernode(ibnf, src(e)) || isbordernode(ibnf, dst(e))
    end
end

"""
$(TYPEDSIGNATURES)

Return all border edges that contain at least one border node as endpoints as global 
"""
function getborderglobaledges(ibnf::IBNFramework)
    ibnag = getibnag(ibnf)
    [
        GlobalEdge(getglobalnode(ibnag, src(e)), getglobalnode(ibnag, dst(e)))
        for e in edges(ibnag) if isbordernode(ibnf, src(e)) || isbordernode(ibnf, dst(e))
    ]
end

"""
$(TYPEDSIGNATURES)

Return the localnode representation given the global representation.
Return `nothing` if not found
"""
function getlocalnode(ibnag::IBNAttributeGraph, globalnode::GlobalNode)
    for nodeproperties in getnodeproperties.(getnodeviews(ibnag))  
        if getglobalnode(nodeproperties) == globalnode
            return getlocalnode(nodeproperties)
        end
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Return the index given the global representation.
Return `nothing` if not found
"""
function getnodeindex(ibnag::IBNAttributeGraph, globalnode::GlobalNode)
    count = 0
    for nodeproperties in getnodeproperties.(getnodeviews(ibnag))  
        count += 1
        if getglobalnode(nodeproperties) == globalnode
            return count
        end
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Return the global representation given the local representation.
Return `nothing` if not found
"""
function getglobalnode(ibnag::IBNAttributeGraph, localnode::LocalNode)
    nodeproperties = getnodeproperties(getnodeview(ibnag, localnode))  
    return getglobalnode(nodeproperties)
end

"""
$(TYPEDSIGNATURES)
"""
function gettransmissionmodule(ibnag::IBNAttributeGraph, oxclli::TransmissionModuleLLI)
    nodeview = getnodeview(ibnag, getlocalnode(oxclli))
    index = gettransmissionmoduleviewpoolindex(oxclli)
    return gettransmissionmoduleviewpool(nodeview)[index]
end

"""
$(TYPEDSIGNATURES)
"""
function gettransmissionmode(ibnag::IBNAttributeGraph, oxclli::TransmissionModuleLLI)
    transmodule = gettransmissionmodule(ibnag, oxclli)
    modeindex = gettransmissionmodesindex(oxclli)
    return gettransmissionmodes(transmodule)[modeindex]
end

"""
$(TYPEDSIGNATURES) 

Get the `OpticalInitiateConstraint` for the current intent DAG.
If the compilation is not optically terminated return `nothing`.

To me this has all the logic needed to be type stable but the compiler fails.
"""
function getopticalinitiateconstraint(ibnf::IBNFramework, idagnodeid::UUID)
    ibnag = getibnag(ibnf)
    logicallliorder::Vector{LowLevelIntent} = getlogicallliorder(ibnf, idagnodeid; onlyinstalled=false)

    isempty(logicallliorder) && return nothing

    lasttransmdlliidx = findlast(x -> x isa TransmissionModuleLLI, logicallliorder)
    isnothing(lasttransmdlliidx) && return nothing
    lasttransmodlli::TransmissionModuleLLI = logicallliorder[lasttransmdlliidx]

    oxcllis::Vector{OXCAddDropBypassSpectrumLLI} = [logicallliorder[i] for i in (lasttransmdlliidx+1):length(logicallliorder)]
    all(x -> x isa OXCAddDropBypassSpectrumLLI, oxcllis) || return nothing
    lastoxclli = last(oxcllis)

    globalnode_input = getglobalnode(ibnag, getlocalnode(lastoxclli))
    spectrumslotsrange = getspectrumslotsrange(lastoxclli)

    # transmission mode
    lasttransmode = gettransmissionmode(getibnag(ibnf), lasttransmodlli)
    rate = getrate(lasttransmode)
    spectrumslotsneeded = getspectrumslotsneeded(lasttransmode)
    nodepath = [getlocalnode(oxclli) for oxclli in oxcllis]
    push!(nodepath, getlocalnode_output(lastoxclli))
    distancecovered = sum(getdistance(getedgeview(ibnag, e)) for e in edgeify(nodepath))
    newopticalreach = getopticalreach(lasttransmode) - distancecovered

    # transmission module
    name = getname(gettransmissionmodule(getibnag(ibnf), lasttransmodlli))

    # transmissionmodulecompat
    transmdlcompat = TransmissionModuleCompatibility(rate, spectrumslotsneeded, name)

    return OpticalInitiateConstraint(globalnode_input, spectrumslotsrange, newopticalreach, transmdlcompat)
end

"""
$(TYPEDSIGNATURES)
"""
function displayavailablecompilationalgorithmsinfo(myibnf::IBNFramework, remoteibnfhandler)
    foreach(requestavailablecompilationalgorithms(myibnf, remoteibnfhandler)) do keywordsymbol
        display(keywordsymbol)
        display(Base.doc(getcompilationalgorithm(Val(keywordsymbol))))
    end
end

"""
$(TYPEDSIGNATURES)
"""
function getnumberofparameters(::T) where {T<:IntentCompilationAlgorithm}
    return getnumberofparameters(T)
end

"""
$(TYPEDSIGNATURES)
"""
function getnumberofparameters(::Type{T}) where {T<:IntentCompilationAlgorithm}
    return fieldcount(T)
end

function getcompilationalgorithm(ibnf::IBNFramework, compilationalgorithmkey::Symbol, compilationalgorithmargs::Tuple)
    compilationalgorithmkey2use = compilationalgorithmkey == :default ? getdefaultcompilationalgorithm(ibnf) : compilationalgorithmkey
    compilationalgorithmtype = getcompilationalgorithmtype(Val(compilationalgorithmkey2use))
    compilationalgorithmargs2use = getnumberofparameters(compilationalgorithmtype) != length(compilationalgorithmargs) ? getdefaultcompilationalgorithmargs(Val(compilationalgorithmkey2use)) : compilationalgorithmargs
    return compilationalgorithmtype(compilationalgorithmargs2use...)
end


"""
$(TYPEDSIGNATURES)

Return true if at least source or destination is internal.
"""
function isinternalorborderintent(ibnf::IBNFramework, connectivityintent::ConnectivityIntent)
    sourceglobalnode = getsourcenode(connectivityintent)
    destinationglobalnode = getdestinationnode(connectivityintent)
    return getibnfid(ibnf) == getibnfid(sourceglobalnode) || getibnfid(ibnf) == getibnfid(destinationglobalnode)
end

"""
$(TYPEDSIGNATURES)
"""
function getpathdistance(ibnag::IBNAttributeGraph, path::Vector{Int})
    ws = getweights(ibnag)
    return sum([getindex(ws, nodepair...) for nodepair in zip(path[1:end-1], path[2:end])])
end

