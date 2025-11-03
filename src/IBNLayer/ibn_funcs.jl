"""
$(TYPEDSIGNATURES)
using Base: source_path
kk
Add a new user intent to the IBN framework and return the id.
"""
@recvtime function addintent!(ibnf::IBNFramework, intent::AbstractIntent, intentissuer::IntentIssuer)
    idagnode = addidagnode!(ibnf, intent; intentissuer, @passtime)
    return ReturnUUIDTime(getidagnodeid(idagnode), @logtime)
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function removeintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returnwtimeiffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled)
    @returnwtimeiffalse(verbose, length(getidagnodechildren(getidag(ibnf), idagnodeid)) == 0)
    returncode = removeidagnode!(getidag(ibnf), idagnodeid)
    return ReturnCodeTime(returncode, @logtime)
end

"""
$(TYPEDSIGNATURES)

THIS SHOULD BE THE ENTRY FUNCTION. DO NOT USE DIRECTLY THE `idagnode` ONES.
"""
@recvtime function compileintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returnwtimeiffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled)
    getintcompalg(ibnf) isa IntentCompilationAlgorithmWithMemory && setdatetime!(getbasicalgmem(getintcompalg(ibnf)), @logtime)
    updatelogintentcomp!(ibnf; @passtime)
    idagnode = getidagnode(getidag(ibnf), idagnodeid)
    returncode = compileintent!(ibnf, idagnode; verbose, @passtime)
    return ReturnCodeTime(returncode, @logtime)
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:RemoteIntent}; verbose::Bool=false)
    if !getisinitiator(getintent(idagnode))
        idagnodechild = addidagnode!(ibnf, getintent(getintent(idagnode)); parentids=[getidagnodeid(idagnode)], intentissuer=MachineGenerated(), @passtime)
        returncode = compileintent!(ibnf, idagnodechild; verbose, @passtime)
    else
        returncode = ReturnCodes.FAIL
    end
    return returncode
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:LightpathIntent}; verbose::Bool=false)
    lpintent = getintent(idagnode)
    idagnodeid = getidagnodeid(idagnode)
    for endnodeallocations in [getsourcenodeallocations(lpintent), getdestinationnodeallocations(lpintent)]
        if !isonlyoptical(endnodeallocations)
            routerportlli = getrouterlli(endnodeallocations)
            stageaddidagnode!(ibnf, routerportlli; parentid=idagnodeid, intentissuer=MachineGenerated(), @passtime)
            transmdllli = gettrasmissionmodulelli(endnodeallocations)
            stageaddidagnode!(ibnf, transmdllli; parentid=idagnodeid, intentissuer=MachineGenerated(), @passtime)
        end
    end

    oxcadddropbypassspectrumllis = generatelightpathoxcadddropbypassspectrumlli(
        getpath(lpintent),
        getspectrumslotsrange(lpintent);
        sourceadddropport=getadddropport(getsourcenodeallocations(lpintent)),
        opticalinitincomingnode=getlocalnode_input(getsourcenodeallocations(lpintent)),
        destadddropport=getadddropport(getdestinationnodeallocations(lpintent))
    )

    for lli in oxcadddropbypassspectrumllis
        stageaddidagnode!(ibnf, lli; parentid=idagnodeid, intentissuer=MachineGenerated(), @passtime)
    end

    return ReturnCodes.SUCCESS
end


"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ProtectedLightpathIntent}; verbose::Bool=false)
    prlpintent = getintent(idagnode)
    prlpidagnodeid = getidagnodeid(idagnode)

    for (sourcenodeallocations, destinationnodeallocations, spectrumslotsrange, path) in zip(getprsourcenodeallocations(prlpintent), getprdestinationnodeallocations(prlpintent), getprspectrumslotsrange(prlpintent), getprpath(prlpintent))
        lpintent = LightpathIntent(sourcenodeallocations, destinationnodeallocations, spectrumslotsrange, path)
        lpidagnode = addidagnode!(ibnf, lpintent; parentids=[prlpidagnodeid], intentissuer=MachineGenerated(), @passtime)
        lpidagnodeid = getidagnodeid(lpidagnode)

        # same code as compileintent! for LightpathIntent
        for endnodeallocations in [getsourcenodeallocations(lpintent), getdestinationnodeallocations(lpintent)]
            if !isonlyoptical(endnodeallocations)
                routerportlli = getrouterlli(endnodeallocations)
                groomifllichildexists!(getidag(ibnf), idagnode, lpidagnode, routerportlli) || stageaddidagnode!(ibnf, routerportlli; parentid=lpidagnodeid, intentissuer=MachineGenerated(), @passtime)
                transmdllli = gettrasmissionmodulelli(endnodeallocations)
                groomifllichildexists!(getidag(ibnf), idagnode, lpidagnode, transmdllli) || stageaddidagnode!(ibnf, transmdllli; parentid=lpidagnodeid, intentissuer=MachineGenerated(), @passtime)
            end
        end

        oxcadddropbypassspectrumllis = generatelightpathoxcadddropbypassspectrumlli(
            getpath(lpintent),
            getspectrumslotsrange(lpintent);
            sourceadddropport=getadddropport(getsourcenodeallocations(lpintent)),
            opticalinitincomingnode=getlocalnode_input(getsourcenodeallocations(lpintent)),
            destadddropport=getadddropport(getdestinationnodeallocations(lpintent))
        )

        for lli in oxcadddropbypassspectrumllis
            groomifllichildexists!(getidag(ibnf), idagnode, lpidagnode, lli) || stageaddidagnode!(ibnf, lli; parentid=lpidagnodeid, intentissuer=MachineGenerated(), @passtime)
        end
    end

    # return ReturnCodes.FAIL
    return ReturnCodes.SUCCESS
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function uncompileintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returnwtimeiffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) in [IntentState.Compiled, IntentState.Uncompiled, IntentState.Pending, IntentState.Installing])
    updatelogintentcomp!(ibnf; @passtime)
    deleteedgesuntilgroomingfound!(getidag(ibnf), idagnodeid)
    idagnodedescendants = getidagnodedescendants(getidag(ibnf), idagnodeid; parentsfirst=false)
    foreach(idagnodedescendants) do idagnodedescendant
        if getintent(idagnodedescendant) isa RemoteIntent
            ibnfhandler = getibnfhandler(ibnf, getibnfid(getintent(idagnodedescendant)))
            uncompiledflag = requestuncompileintent_init!(ibnf, ibnfhandler, getidagnodeid(getintent(idagnodedescendant)); verbose, @passtime)
            if uncompiledflag == ReturnCodes.SUCCESS
                removeidagnode!(getidag(ibnf), getidagnodeid(idagnodedescendant))
            end
        else
            @returnwtimeiffalse(verbose, getidagnodestate(idagnodedescendant) in [IntentState.Compiled, IntentState.Uncompiled, IntentState.Pending])
            @assert iszero(hasidagnodechildren(getidag(ibnf), idagnodedescendant))
            removeidagnode!(getidag(ibnf), getidagnodeid(idagnodedescendant))
            if getintent(idagnodedescendant) isa LowLevelIntent
                stageunstageleafintent!(ibnf, getintent(idagnodedescendant), false)
            end
        end
    end
    updateidagstates!(ibnf, idagnodeid; @passtime)
    if getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled
        returncode = ReturnCodes.SUCCESS
    else
        returncode = ReturnCodes.FAIL
    end
    return ReturnCodeTime(returncode, @logtime)
end

"""
$(TYPEDSIGNATURES)
Delete all nodes and edges until the grooming node is found.
If no grooming node is found, delete nothing.
Start from `idagnodeid`
"""
function deletenodesedgesuntilgroomingfound(idag::IntentDAG, idagnodeid::UUID)
    idagnodeid2dlt = UUID[]
    idagedge2dlt = UUID[]
    for idagnode in getidagnodechildren(idag, idagnodeid)
        nidagnodeid = getidagnodeid(idagnode)
        groomingfound = _rec_deletenodesedgesuntilgroomingfound!(idag, nidagnodeid, idagnodeid2dlt)
        groomingfound && push!(idagedge2dlt, nidagnodeid)
    end
    for idagnodeedgedst2dlt in idagedge2dlt
        removeidagedge!(idag, idagnodeid, idagnodeedgedst2dlt)
    end
    for idagnodeid in idagnodeid2dlt
        removeidagnode!(idag, idagnodeid)
    end
    return
end

"""
$(TYPEDSIGNATURES)
Delete edges towards grooming nodes.
"""
function deleteedgesuntilgroomingfound!(idag::IntentDAG, idagnodeid::UUID)
    for idagnode in getidagnodechildren(idag, idagnodeid)
        nidagnodeid = getidagnodeid(idagnode)
        if isgroomingnode(idag, nidagnodeid)
            removeidagedge!(idag, idagnodeid, nidagnodeid)
        end
    end
    for idagnode in getidagnodechildren(idag, idagnodeid)
        nidagnodeid = getidagnodeid(idagnode)
        deleteedgesuntilgroomingfound!(idag, nidagnodeid)
    end
    return
end

function isgroomingnode(idag::IntentDAG, idagnodeid::UUID)
    idagnodeidx = getidagnodeidx(idag, idagnodeid)
    if length(Graphs.inneighbors(idag, idagnodeidx)) > 1
        if length(getidagnoderoots(idag, idagnodeid)) > 1
            return true
        end
    end
    return false
end

function deletenodesedgesuntilgroomingfound_fake(idag::IntentDAG, idagnodeid::UUID)
    idagnodeid2dlt = UUID[]
    idagedge2dlt = UUID[]
    for idagnode in getidagnodechildren(idag, idagnodeid)
        nidagnodeid = getidagnodeid(idagnode)
        groomingfound = _rec_deletenodesedgesuntilgroomingfound!(idag, nidagnodeid, idagnodeid2dlt)
        groomingfound && push!(idagedge2dlt, nidagnodeid)
    end
    for idagnodeedgedst2dlt in idagedge2dlt
        @info "deleting edge", idagnodeid, idagnodeedgedst2dlt
    end
    for idagnodeid in idagnodeid2dlt
        @info "deleteing node", idagnodeid
    end
    return
end

"""
$(TYPEDSIGNATURES)

Returns true if grooming is found and the `idagnodeid` to delete
"""
function _rec_deletenodesedgesuntilgroomingfound!(idag::IntentDAG, idagnodeid::UUID, idagnodeid2dlt::Vector{UUID})
    idagnodeidx = getidagnodeidx(idag, idagnodeid)
    if length(Graphs.inneighbors(idag, idagnodeidx)) > 1
        if length(getidagnoderoots(idag, idagnodeid)) > 1
            return true
        end
    end
    allgroomingfound = true
    investigatedchildren = false
    for idagnode in getidagnodechildren(idag, idagnodeid)
        investigatedchildren = true
        nidagnodeid = getidagnodeid(idagnode)
        # all children must be grooming in order to delete the parent. Because otherwise more need to be deleted.
        allgroomingfound &= _rec_deletenodesedgesuntilgroomingfound!(idag, nidagnodeid, idagnodeid2dlt)
    end
    allgroomingfound &= investigatedchildren
    allgroomingfound && push!(idagnodeid2dlt, idagnodeid)

    return allgroomingfound
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function installintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returnwtimeiffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) ∈ [IntentState.Compiled, IntentState.Installing, IntentState.Failed])
    startingstate = getidagnodestate(getidag(ibnf), idagnodeid)
    # unblock from the Compiled state. needed due to grooming which locks parents intents from getting installed if all LLIs are installed.
    idagnodeleafs = getidagnodeleafs2install(ibnf, idagnodeid)
    # @returnwtimeiffalse(verbose, !isempty(idagnodeleafs))
    if isempty(idagnodeleafs)
        updateidagstates!(ibnf, idagnodeid, IntentState.Failed; @passtime)
        return ReturnCodeTime(ReturnCodes.FAIL, @logtime)
    end

    startingstate == IntentState.Failed && uninstallintent!(ibnf, idagnodeid; verbose, @passtime, forceinstallable=true)
    updateidagstates!(ibnf, idagnodeid, IntentState.Installing; @passtime)
    # run once to sync with idag
    foreach(idagnodeleafs) do idagnodeleaf
        if getidagnodestate(idagnodeleaf) == IntentState.Installing # || (startingstate == IntentState.Failed && getidagnodestate(idagnodeleaf) == IntentState.Compiled)
            reserveunreserveleafintents!(ibnf, idagnodeleaf, true; verbose, @passtime)
        end
    end

    for idagnodex in getidagnodedescendants(getidag(ibnf), idagnodeid; includeroot=true)
        if getidagnodestate(idagnodex) == IntentState.Installing
            if getintent(idagnodex) isa LowLevelIntent
                updateidagstates!(ibnf, getidagnodeid(idagnodex), IntentState.Compiled; @passtime)
            else
                updateidagstates!(ibnf, getidagnodeid(idagnodex); @passtime)
            end
        end
    end

    if getintcompalg(ibnf) isa IntentCompilationAlgorithmWithMemory
        lg = @logtime
        setdatetime!(getbasicalgmem(getintcompalg(ibnf)), lg)
    end
    if getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Installed
        updateintcompalginstallation!(ibnf, idagnodeid)
        returncode = ReturnCodes.SUCCESS
    else
        returncode = ReturnCodes.FAIL
    end
    return ReturnCodeTime(returncode, @logtime)
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function uninstallintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false, forceinstallable=false)
    @returnwtimeiffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) ∈ [IntentState.Installing, IntentState.Installed, IntentState.Failed, IntentState.Pending])
    finalstate = forceinstallable ? IntentState.Installing : IntentState.Compiled
    # this check is for grooming cases, such that LLIs don't get uninstalled as long as a parent is installed
    if forceinstallable || all(x -> getidagnodestate(x) !== IntentState.Failed && getidagnodestate(x) !== IntentState.Installed, getidagnodeparents(getidag(ibnf), idagnodeid))
        idagnodechildren = getidagnodechildren(getidag(ibnf), idagnodeid)
        if length(idagnodechildren) == 0
            reserveunreserveleafintents!(ibnf, getidagnode(getidag(ibnf), idagnodeid), false; verbose, @passtime, forceinstallable)
        else
            updateidagstates!(ibnf, idagnodeid, finalstate; @passtime)
            for idagnodechild in idagnodechildren
                uninstallintent!(ibnf, getidagnodeid(idagnodechild); verbose, @passtime, forceinstallable)
            end
        end
    end

    if getidagnodestate(getidag(ibnf), idagnodeid) == finalstate
        returncode = ReturnCodes.SUCCESS
    else
        returncode = ReturnCodes.FAIL
    end
    return ReturnCodeTime(returncode, @logtime)
end

"""
$(TYPEDSIGNATURES)

to reserve pass `doinstall=true`, and to unreserve `doinstall=false`
"""
@recvtime function reserveunreserveleafintents!(ibnf::IBNFramework, idagnodeleaf::IntentDAGNode, doinstall::Bool; verbose::Bool=false, forceinstallable=false)
    finalstate = forceinstallable ? IntentState.Installing : IntentState.Compiled
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
                if getintent(idagnodeleaf) isa OXCAddDropBypassSpectrumLLI
                    if isoxcllifail(ibnf, getintent(idagnodeleaf))
                        pushstatetoidagnode!(getlogstate(idagnodeleaf), IntentState.Failed; @passtime)
                    else
                        pushstatetoidagnode!(getlogstate(idagnodeleaf), IntentState.Installed; @passtime)
                    end
                else
                    pushstatetoidagnode!(getlogstate(idagnodeleaf), IntentState.Installed; @passtime)
                end
                stageunstageleafintent!(ibnf, leafintent, false; about2install=true)
            end
        else
            if issuccessfull
                pushstatetoidagnode!(getlogstate(idagnodeleaf), finalstate; @passtime)
                stageunstageleafintent!(ibnf, leafintent, true)
            end
        end
    elseif leafintent isa RemoteIntent
        if getisinitiator(leafintent)
            ibnfhandler = getibnfhandler(ibnf, getibnfid(leafintent))
            if doinstall
                requestinstallintent_init!(ibnf, ibnfhandler, getidagnodeid(leafintent); verbose, @passtime)
            else
                requestuninstallintent_init!(ibnf, ibnfhandler, getidagnodeid(leafintent); verbose, @passtime, forceinstallable)
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
@recvtime function stageaddidagnode!(ibnf::IBNFramework, lli::LowLevelIntent; parentid::Union{Nothing,UUID}=nothing, intentissuer=MachineGenerated())
    parentids = isnothing(parentid) ? UUID[] : [parentid]
    idagnode = addidagnode!(ibnf, lli; parentids, intentissuer, @passtime)
    stageunstageleafintent!(ibnf, lli, true)
end

"""
$(TYPEDSIGNATURES)
`dostage` `true` for stage, `false` for unstage
`about2install = true` only when `dostage=false` for unstaging when groing to installed state. This is only used to not deallocate the spectrum.
"""
function stageunstageleafintent!(ibnf::IBNFramework, lli::LowLevelIntent, dostage::Bool; about2install::Bool=false)
    localnode = getlocalnode(lli)
    nodeview = AG.vertex_attr(getibnag(ibnf))[localnode]

    return successflag = if lli isa TransmissionModuleLLI
        if dostage
            stage!(nodeview, lli)
        else
            unstage!(nodeview, lli; about2install)
        end
    elseif lli isa RouterPortLLI
        if dostage
            stage!(getrouterview(nodeview), lli)
        else
            unstage!(getrouterview(nodeview), lli; about2install)
        end
    elseif lli isa OXCAddDropBypassSpectrumLLI
        if dostage
            stage!(getoxcview(nodeview), lli)
        else
            unstage!(getoxcview(nodeview), lli; about2install)
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
    remoteidagnodeid = requestdelegateintent_init!(ibnf, ibnfhandler, getintent(idagnode), internalnextidagnodeid; @passtime)

    # add an idagnode `RemoteIntent`
    remoteintent = RemoteIntent(remoteibnfid, remoteidagnodeid, getintent(idagnode), true)

    # add in DAG
    internalidagnode = addidagnode!(ibnf, remoteintent; parentids=[getidagnodeid(idagnode)], intentissuer=MachineGenerated(), @passtime)
    @assert internalnextidagnodeid == getidagnodeid(internalidagnode)

    return internalidagnode
end

"""
$(TYPEDSIGNATURES)

Get spectrum availabilities along a `path` of nodes as a `BitVector`
"""
function getpathspectrumavailabilities(ibnf::IBNFramework, localnodespath::Vector{LocalNode}; checkfirst::Bool=true)
    len::Int = length(first(values(getlinkspectrumavailabilities(getoxcview(first(getnodeviews(getibnag(ibnf))))))))
    pathavailabilities = fill(true, len)
    for (i,edg) in enumerate(edgeify(localnodespath))
        pathavailabilities .&= getfiberspectrumavailabilities(ibnf, edg; checkfirst)
    end
    return pathavailabilities
end

"""
$(TYPEDSIGNATURES)

Get the spectrum availability slots vector for `edge`
"""
function getfiberspectrumavailabilities(ibnf::IBNFramework, edge::Edge{LocalNode}; checkfirst::Bool=true, verbose::Bool=false)
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
function getfiberspectrumavailabilities(ibnag::IBNAttributeGraph, edge::Edge{LocalNode}; checkfirst::Bool=true)
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

Same as `getcurrentlinkstate(ibnf::IBNFramework)` but doesn't send a request to other domains.
"""
function getcurrentlinkstate(ibnag::IBNAttributeGraph, edge::Edge; checkfirst::Bool=true, verbose::Bool=false)
    edsrc = src(edge)
    nodeviewsrc = getnodeview(ibnag, edsrc)
    eddst = dst(edge)
    nodeviewdst = getnodeview(ibnag, eddst)
    issrcbordernode = isbordernode(ibnag, edsrc)
    isdstbordernode = isbordernode(ibnag, eddst)
    @returniffalse(verbose, !(issrcbordernode && isdstbordernode))
    if checkfirst
        globaledge = GlobalEdge(getglobalnode(ibnag, edsrc), getglobalnode(ibnag, eddst))
        srclinksstate = if issrcbordernode
            nothing
        else
            getcurrentlinkstate(getoxcview(nodeviewsrc), edge)
        end

        dstlinkstate = if isdstbordernode
            nothing
        else
            getcurrentlinkstate(getoxcview(nodeviewdst), edge)
        end

        @assert(srclinksstate == dstlinkstate && !isnothing(srclinksstate))
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
"""
@recvtime function setlinkstate!(ibnf::IBNFramework, edge::Edge, operatingstate::Bool; verbose=false)
    ibnag = getibnag(ibnf)
    edsrc = src(edge)
    nodeviewsrc = getnodeview(ibnag, edsrc)
    eddst = dst(edge)
    nodeviewdst = getnodeview(ibnag, eddst)
    issrcbordernode = isbordernode(ibnf, edsrc)
    isdstbordernode = isbordernode(ibnf, eddst)
    @returnwtimeiffalse(verbose, !(issrcbordernode && isdstbordernode))
    globaledge = GlobalEdge(getglobalnode(ibnag, edsrc), getglobalnode(ibnag, eddst))

    idagnodeids = getidagnodeid.(getnetworkoperatornremotenotinitidagnodes(getidag(ibnf)))
    rootintentstatesbefore = getidagnodestate.(getnetworkoperatornremotenotinitidagnodes(getidag(ibnf)))

    # first do whatever is intra 

    if issrcbordernode
        if isdstbordernode
            remoteibnfid = getibnfid(getglobalnode(ibnag, eddst))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            requestsetlinkstate_init!(ibnf, ibnfhandler, globaledge, operatingstate; @passtime)
        else
            setlinkstate!(ibnf, getoxcview(nodeviewdst), edge, operatingstate; @passtime)
        end
        remoteibnfid = getibnfid(getglobalnode(ibnag, edsrc))
        ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
        requestsetlinkstate_init!(ibnf, ibnfhandler, globaledge, operatingstate; @passtime)
    else
        setlinkstate!(ibnf, getoxcview(nodeviewsrc), edge, operatingstate; @passtime)
        if isdstbordernode
            remoteibnfid = getibnfid(getglobalnode(ibnag, eddst))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            requestsetlinkstate_init!(ibnf, ibnfhandler, globaledge, operatingstate; @passtime)
        else
            setlinkstate!(ibnf, getoxcview(nodeviewdst), edge, operatingstate; @passtime)
        end
    end

    rootintentstatesafter = getidagnodestate.(getnetworkoperatornremotenotinitidagnodes(getidag(ibnf)))

    for (idnid, risb, risa) in zip(idagnodeids, rootintentstatesbefore, rootintentstatesafter)
        # risnow = getidagnodestate(getidag(ibnf), idnid)
        # if risnow !== IntentState.Installed
            if any(x -> getintent(x) isa ProtectedLightpathIntent, getidagnodedescendants(getidag(ibnf), idnid))
                # reinstall in case there is protection deployed
                if risb == IntentState.Installed && risa == IntentState.Failed
                    installintent!(ibnf, idnid; @passtime)
                elseif risb == risa == IntentState.Failed && !isempty(getidagnodeleafs2install(ibnf, idnid))
                    # because maybe repaired link is in the other branch of the protection
                    installintent!(ibnf, idnid; @passtime)
                end
            end
        # end
    end

    return ReturnCodeTime(ReturnCodes.SUCCESS, @logtime)
end

"""
$(TYPEDSIGNATURES)
Get the router port
"""
function getrouterport(ibnf::IBNFramework, intent::RouterPortLLI)
    localnode = getlocalnode(intent)
    routerview = getrouterview(getnodeview(getibnag(ibnf), localnode))
    return getrouterport(routerview, getrouterportindex(intent))
end

"""
$(TYPEDSIGNATURES)
Get the router port
"""
function getrouterportrate(ibnf::IBNFramework, intent::RouterPortLLI)
    localnode = getlocalnode(intent)
    routerview = getrouterview(getnodeview(getibnag(ibnf), localnode))
    return getrate(getrouterport(routerview, getrouterportindex(intent)))
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
function getreservedtransmissionmode(ibnf::IBNFramework, idagnode::IntentDAGNode{TransmissionModuleLLI}; verbose::Bool=false)
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
    return findfirst(getnodeviews(ibnag)) do nodeview
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

Return boolean if `localnode` is in `ibnf` as a border node
"""
function isbordernode(ibnag::IBNAttributeGraph, localnode::LocalNode)
    nodeview = getnodeview(ibnag, localnode)
    return !isnodeviewinternal(nodeview)
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
    return [
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
    # TODO : perf: don't use lowlevelintents  but LightPtah and ProtectedLightpath
    idnchildren = getidagnodechildren(getidag(ibnf), idagnodeid)
    if length(idnchildren) == 1
        idnchildintent = getintent(first(idnchildren))
        if idnchildintent isa LightpathIntent
            return getopticalinitiateconstraint(ibnf, idagnodeid, idnchildintent)
        elseif idnchildintent isa ProtectedLightpathIntent
            return getopticalinitiateconstraint(ibnf, idagnodeid, idnchildintent)
        end
    end

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

function getopticalinitiateconstraint(ibnf::IBNFramework, idagnodeidparent::UUID, lpintent::LightpathIntent)
    @assert isonlyoptical(getdestinationnodeallocations(lpintent))
    path = getpath(lpintent)
    @assert getibnfid(getglobalnode(getibnag(ibnf), path[end])) !== getibnfid(ibnf)

    globalnode_input = getglobalnode(getibnag(ibnf), path[end-1])
    spectrumslotsrange = getspectrumslotsrange(lpintent)
    sourcenodeallocations = getsourcenodeallocations(lpintent)

    ibnagweights = getibnagweights(getcachedresults(getintcompalg(ibnf)))
    if !isonlyoptical(sourcenodeallocations)
        transmodule = gettransmissionmodule(ibnf, sourcenodeallocations)
        mode = gettransmissionmodes(transmodule)[gettransmissionmodesindex(sourcenodeallocations)]
        rate = getrate(mode)
        name = getname(transmodule)
        transmdlcompat = TransmissionModuleCompatibility(rate, length(spectrumslotsrange), name)

        lastopticalreach = getopticalreach(mode)
        distancecovered = getpathdistance3(ibnagweights, path)

        newopticalreach = lastopticalreach - distancecovered

        return OpticalInitiateConstraint(globalnode_input, spectrumslotsrange, newopticalreach, transmdlcompat)
    else
        previousopticalinitiateconstraint = something(getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getidagnode(ibnf, idagnodeidparent))))
        lastopticalreach = getopticalreach(previousopticalinitiateconstraint)
        distancecovered = getpathdistance3(ibnagweights, path)
        newopticalreach = lastopticalreach - distancecovered
        transmdlcompat = gettransmissionmodulecompat(previousopticalinitiateconstraint)
        return OpticalInitiateConstraint(globalnode_input, spectrumslotsrange, newopticalreach, transmdlcompat)
    end
end

function getopticalinitiateconstraint(ibnf::IBNFramework, idagnodeidparent::UUID, lpintent::ProtectedLightpathIntent)
    @assert all(destinationnodeallocation -> isonlyoptical(destinationnodeallocation), getprdestinationnodeallocations(lpintent))
    prpath = getprpath(lpintent)
    @assert all(path -> getibnfid(getglobalnode(getibnag(ibnf), path[end])) !== getibnfid(ibnf), prpath)

    # we always have up to 2 lightpath protections anyhow..
    # TODO : change if more protection is needed
    @assert length(prpath) == 2
    globalnode_input_1 = getglobalnode(getibnag(ibnf), prpath[1][end-1])
    globalnode_input_2 = getglobalnode(getibnag(ibnf), prpath[2][end-1])
    # TODO: this will break if more internal nodes lead to border node (fow now just avoid this use case)
    @assert globalnode_input_1 == globalnode_input_2

    prspectrumslotsrange = getprspectrumslotsrange(lpintent)
    @assert prspectrumslotsrange[1] == prspectrumslotsrange[2]

    prsourcenodeallocations = getprsourcenodeallocations(lpintent)
    sourcenodeallocations1 = prsourcenodeallocations[1]
    sourcenodeallocations2 = prsourcenodeallocations[2]

    ibnagweights = getibnagweights(getcachedresults(getintcompalg(ibnf)))
    if !isonlyoptical(sourcenodeallocations1) && !isonlyoptical(sourcenodeallocations2)
        transmodule1 = gettransmissionmodule(ibnf, sourcenodeallocations1)
        transmodule2 = gettransmissionmodule(ibnf, sourcenodeallocations2)

        mode1 = gettransmissionmodes(transmodule1)[gettransmissionmodesindex(sourcenodeallocations1)]
        mode2 = gettransmissionmodes(transmodule2)[gettransmissionmodesindex(sourcenodeallocations2)]

        rate1 = getrate(mode1)
        rate2 = getrate(mode2)
        newrate = max(rate1, rate2)

        name1 = getname(transmodule1)
        name2 = getname(transmodule2)

        # TODO : will not check that name1 == name2 although I should


        transmdlcompat = TransmissionModuleCompatibility(newrate, length(prspectrumslotsrange[1]), name1)

        lastopticalreach1 = getopticalreach(mode1)
        lastopticalreach2 = getopticalreach(mode2)
        newlastopticalreach = min(lastopticalreach1, lastopticalreach2)

        distancecovered1 = getpathdistance3(ibnagweights, prpath[1])
        distancecovered2 = getpathdistance3(ibnagweights, prpath[2])

        newopticalreach1 = lastopticalreach1 - distancecovered1
        newopticalreach2 = lastopticalreach2 - distancecovered2
        newopticalreach = min(newopticalreach1, newopticalreach2)

        return OpticalInitiateConstraint(globalnode_input_1, prspectrumslotsrange[1], newopticalreach, transmdlcompat)
    else
        previousopticalinitiateconstraint = something(getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getidagnode(ibnf, idagnodeidparent))))
        lastopticalreach = getopticalreach(previousopticalinitiateconstraint)
        distancecovered1 = getpathdistance3(ibnagweights, prpath[1])
        distancecovered2 = getpathdistance3(ibnagweights, prpath[2])

        newopticalreach1 = lastopticalreach - distancecovered1
        newopticalreach2 = lastopticalreach - distancecovered2
        newopticalreach = min(newopticalreach1, newopticalreach2)
        transmdlcompat = gettransmissionmodulecompat(previousopticalinitiateconstraint)
        return OpticalInitiateConstraint(globalnode_input_1, prspectrumslotsrange[1], newopticalreach, transmdlcompat)
    end
end


"""
$(TYPEDSIGNATURES)

Return true if at least source or destination is internal.
Pass `; noremoteintent=true` to check whether there is an `OpticalTerminateConstraint` or an `OpticalInitiateConstraint` such that no `RemoteIntent` is needed.
"""
function isinternalorborderintent(ibnf::IBNFramework, connectivityintent::ConnectivityIntent; noremoteintent=false)
    sourceglobalnode = getsourcenode(connectivityintent)
    destinationglobalnode = getdestinationnode(connectivityintent)
    if noremoteintent
        if !isinternalnode(ibnf, sourceglobalnode)
            if !(isbordernode(ibnf, sourceglobalnode) && any(x -> x isa OpticalInitiateConstraint, getconstraints(connectivityintent)))
                return false
            end
        end
        if !isinternalnode(ibnf, destinationglobalnode)
            if !(isbordernode(ibnf, destinationglobalnode) && any(x -> x isa OpticalTerminateConstraint, getconstraints(connectivityintent)))
                return false
            end
        end
        return true
    else
        return getibnfid(ibnf) == getibnfid(sourceglobalnode) || getibnfid(ibnf) == getibnfid(destinationglobalnode)
    end
end

"""
$(TYPEDSIGNATURES)

Return true if source node belongs to `ibnf` and destination node to another domain that is NOT a border node.
"""
function isvalidexternalintent(ibnf::IBNFramework, connectivityintent::ConnectivityIntent)
    sourceglobalnode = getsourcenode(connectivityintent)
    destinationglobalnode = getdestinationnode(connectivityintent)
    if isinternalnode(ibnf, sourceglobalnode) 
        if !isbordernode(ibnf, destinationglobalnode) && !isinternalnode(ibnf, destinationglobalnode)
            return true
        end
    end
    return false
end

"""
$(TYPEDSIGNATURES)
"""
function getpathdistance(ibnag::IBNAttributeGraph, path::Vector{Int})
    @warn "You are using an underoptimized version of `getpathdistance` that is not approprite for hot loops. Consider passing the `weights` directly."
    ws = getweights(ibnag)
    return sum([getindex(ws, nodepair...) for nodepair in zip(path[1:(end-1)], path[2:end])])
end

"""
$(TYPEDSIGNATURES)
"""
function getpathdistance(ws::Matrix, path::Vector{Int})
    return sum([getindex(ws, nodepair...) for nodepair in zip(path[1:(end-1)], path[2:end])])
end

"""
$(TYPEDSIGNATURES)
"""
function getpathdistance2(ws::Matrix, path::Vector{Int})
    mysum = zero(eltype(ws))
    for nodepair in zip(path[1:(end-1)], path[2:end])
        mysum += ws[nodepair...]
    end
    return mysum
end

"""
$(TYPEDSIGNATURES)
"""
function getpathdistance3(ws::Matrix, path::Vector{Int})
    mysum = zero(eltype(ws))
    # for nodepair in zip(path[1:(end-1)], path[2:end])
    for i in eachindex(path)
        i == length(path) && break
        mysum += ws[path[i], path[i+1]]
    end
    return mysum
end

function addtoinstalledlightpaths!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:CrossLightpathIntent})
    lpidagnode = (getfirst(x -> getintent(x) isa LightpathIntent, getidagnodechildren(getidag(ibnf), getidagnodeid(idagnode))))
    if !isnothing(lpidagnode)
        lightpathrepresentation = createlightpathrepresentation(ibnf, lpidagnode; overwritedestinationnode = getdestinationnode(getremoteconnectivityintent(getintent(idagnode))))
        installedlightpaths = getinstalledlightpaths(getidaginfo(getidag(ibnf)))
        installedlightpaths[getidagnodeid(idagnode)] = lightpathrepresentation
        return true
    else
        plpidagnode = (getfirst(x -> getintent(x) isa ProtectedLightpathIntent, getidagnodechildren(getidag(ibnf), getidagnodeid(idagnode))))
        if !isnothing(plpidagnode)
            lightpathrepresentation = createlightpathrepresentation(ibnf, plpidagnode; overwritedestinationnode = getdestinationnode(getremoteconnectivityintent(getintent(idagnode))))
            installedlightpaths = getinstalledlightpaths(getidaginfo(getidag(ibnf)))
            installedlightpaths[getidagnodeid(idagnode)] = lightpathrepresentation
            return true
        end
    end
    return false
end

"""
$(TYPEDSIGNATURES)

If `idagnode` represents a direct parent of LLIs that are a lightpath, add representation to the IntentDAGInfo
Return `true` if done. Otherwise `false`
"""
function addtoinstalledlightpaths!(ibnf::IBNFramework, idagnode::IntentDAGNode{LightpathIntent})
    lightpathrepresentation = createlightpathrepresentation(ibnf, idagnode)
    installedlightpaths = getinstalledlightpaths(getidaginfo(getidag(ibnf)))
    installedlightpaths[getidagnodeid(idagnode)] = lightpathrepresentation
    return true
end

function createlightpathrepresentation(ibnf::IBNFramework, idagnode::IntentDAGNode{LightpathIntent}; overwritedestinationnode=nothing)
    lpintent = getintent(idagnode)
    path = getpath(lpintent)
    startsoptically = isonlyoptical(getsourcenodeallocations(lpintent))
    terminatesoptically = isonlyoptical(getdestinationnodeallocations(lpintent))
    lightpathidagnodeid = getidagnodeid(idagnode)
    # totalbandwidth
    totalbandwidth = GBPSf(0)
    if !startsoptically
        nodeview = getnodeview(getibnag(ibnf), getlocalnode(getsourcenodeallocations(lpintent)))
        transmissionmodule = gettransmissionmoduleviewpool(nodeview)[gettransmissionmoduleviewpoolindex(getsourcenodeallocations(lpintent))]
        transmissionmode = gettransmissionmodes(transmissionmodule)[gettransmissionmodesindex(getsourcenodeallocations(lpintent))]
        totalbandwidth = getrate(transmissionmode)
    elseif !terminatesoptically
        nodeview = getnodeview(getibnag(ibnf), getlocalnode(getdestinationnodeallocations(lpintent)))
        transmissionmodule = gettransmissionmoduleviewpool(nodeview)[gettransmissionmoduleviewpoolindex(getdestinationnodeallocations(lpintent))]
        transmissionmode = gettransmissionmodes(transmissionmodule)[gettransmissionmodesindex(getdestinationnodeallocations(lpintent))]
        totalbandwidth = getrate(transmissionmode)
    else
        # starts and terminates optically meaning it will have a parent intent with IntiateOpticalConstraint with TransmissionModuleCompatibility
        idagnoderoots = getidagnoderoots(getidag(ibnf), getidagnodeid(idagnode))
        for idnr in idagnoderoots
            if getintent(idnr) isa RemoteIntent
                optinitconstraint = getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getintent(getintent(idnr))))
                if !isnothing(optinitconstraint)
                    totalbandwidth = getrate(gettransmissionmodulecompat(optinitconstraint))
                end
            elseif getintent(idnr) isa ConnectivityIntent
                optinitconstraint = getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getintent(idnr)))
                if !isnothing(optinitconstraint)
                    totalbandwidth = getrate(gettransmissionmodulecompat(optinitconstraint))
                end
            end
        end
    end
    if isnothing(overwritedestinationnode)
        lightpathrepresentation = LightpathRepresentation([path], startsoptically, terminatesoptically, totalbandwidth, getglobalnode(getibnag(ibnf), path[end]))
    else
        lightpathrepresentation = LightpathRepresentation([path], startsoptically, terminatesoptically, totalbandwidth, overwritedestinationnode)
    end
    return lightpathrepresentation
end

"""
$(TYPEDSIGNATURES)
"""
function addtoinstalledlightpaths!(ibnf::IBNFramework, idagnode::IntentDAGNode{ProtectedLightpathIntent})
    lightpathrepresentation = createlightpathrepresentation(ibnf, idagnode)
    installedlightpaths = getinstalledlightpaths(getidaginfo(getidag(ibnf)))
    installedlightpaths[getidagnodeid(idagnode)] = lightpathrepresentation
    return true
end

function createlightpathrepresentation(ibnf::IBNFramework, idagnode::IntentDAGNode{ProtectedLightpathIntent}; overwritedestinationnode=nothing)
    lpintents::Vector{LightpathIntent} = getintent.(getidagnodechildren(getidag(ibnf), idagnode))

    paths = getpath.(lpintents)
    @assert all(p -> paths[1][end] == p[end], paths)

    startsopticallys = [isonlyoptical(getsourcenodeallocations(lpintent)) for lpintent in lpintents]
    @assert all(so -> so == startsopticallys[1], startsopticallys)
    startsoptically = startsopticallys[1]
    terminatesopticallys = [isonlyoptical(getdestinationnodeallocations(lpintent)) for lpintent in lpintents]
    @assert all(to -> to == terminatesopticallys[1], terminatesopticallys)
    terminatesoptically = terminatesopticallys[1]

    lightpathidagnodeid = getidagnodeid(idagnode)
    # totalbandwidth
    totalbandwidth = GBPSf(0)
    if !startsoptically
        for lpintent in lpintents
            nodeview = getnodeview(getibnag(ibnf), getlocalnode(getsourcenodeallocations(lpintent)))
            transmissionmodule = gettransmissionmoduleviewpool(nodeview)[gettransmissionmoduleviewpoolindex(getsourcenodeallocations(lpintent))]
            transmissionmode = gettransmissionmodes(transmissionmodule)[gettransmissionmodesindex(getsourcenodeallocations(lpintent))]
            totalbandwidth_i = getrate(transmissionmode)
            if totalbandwidth == GBPSf(0) || totalbandwidth_i < totalbandwidth
                totalbandwidth = totalbandwidth_i
            end
        end
    elseif !terminatesoptically
        for lpintent in lpintents
            nodeview = getnodeview(getibnag(ibnf), getlocalnode(getdestinationnodeallocations(lpintent)))
            transmissionmodule = gettransmissionmoduleviewpool(nodeview)[gettransmissionmoduleviewpoolindex(getdestinationnodeallocations(lpintent))]
            transmissionmode = gettransmissionmodes(transmissionmodule)[gettransmissionmodesindex(getdestinationnodeallocations(lpintent))]
            totalbandwidth_i = getrate(transmissionmode)
            if totalbandwidth == GBPSf(0) || totalbandwidth_i < totalbandwidth
                totalbandwidth = totalbandwidth_i
            end
        end
    else
        # I doubt ProtectedLightpathIntent ever comes here. Code is copied from the Lightpath/CrossLightpath use case
        # starts and terminates optically meaning it will have a parent intent with IntiateOpticalConstraint with TransmissionModuleCompatibility
        idagnoderoots = getidagnoderoots(getidag(ibnf), getidagnodeid(idagnode))
        for idnr in idagnoderoots
            if getintent(idnr) isa RemoteIntent
                optinitconstraint = getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getintent(getintent(idnr))))
                if !isnothing(optinitconstraint)
                    totalbandwidth = getrate(gettransmissionmodulecompat(optinitconstraint))
                end
            elseif getintent(idnr) isa ConnectivityIntent
                optinitconstraint = getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getintent(idnr)))
                if !isnothing(optinitconstraint)
                    totalbandwidth = getrate(gettransmissionmodulecompat(optinitconstraint))
                end
            end
        end
    end
    if isnothing(overwritedestinationnode)
        return LightpathRepresentation(paths, startsoptically, terminatesoptically, totalbandwidth, getglobalnode(getibnag(ibnf), paths[1][end]))
    else
        return LightpathRepresentation(paths, startsoptically, terminatesoptically, totalbandwidth, overwritedestinationnode)
    end
end

"""
$(TYPEDSIGNATURES)

If `idagnode` represents a direct parent of LLIs that are a lightpath, add representation to the IntentDAGInfo
Return `true` if done. Otherwise `false`
"""
function addtoinstalledlightpaths!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent})
    # should be the direct intent DAG
    lliidagnodechildren = getidagnodechildren(getidag(ibnf), idagnode)
    all(idn -> getintent(idn) isa LowLevelIntent, lliidagnodechildren) || return false
    lollis = getlogicallliorder(ibnf, idagnode; onlyinstalled=true)
    if logicalorderissinglelightpath(lollis)
        startoptically = first(lollis) isa OXCAddDropBypassSpectrumLLI ? true : false
        terminatesoptically = last(lollis) isa OXCAddDropBypassSpectrumLLI ? true : false
        path = logicalordergetlightpaths(lollis)[] # first is unique
        # totalbandwidth
        if lollis[2] isa TransmissionModuleLLI
            totalbandwidth = getrate(gettransmissionmode(ibnf, lollis[2]))
        elseif lollis[end-1] isa TransmissionModuleLLI
            totalbandwidth = getrate(gettransmissionmode(ibnf, lollis[end-1]))
        else # search it in the whole DAG (slow but should be seldom)
            # search on source or destination
            searchallidagfortransmissionrate(ibnf, lollis)
        end
        lightpathrepresentation = LightpathRepresentation([path], startoptically, terminatesoptically, totalbandwidth, getidagnodeid.(lliidagnodechildren))
        installedlightpaths = getinstalledlightpaths(getidaginfo(getidag(ibnf)))
        installedlightpaths[getidagnodeid(idagnode)] = lightpathrepresentation
    end
    return true
end

"""
$(TYPEDSIGNATURES)

Remove from the installedlightpaths representation if exists
Return `true` if done. Otherwise `false`
"""
function removefrominstalledlightpaths!(ibnf::IBNFramework, idagnode::IntentDAGNode)
    installedlightpaths = getinstalledlightpaths(getidaginfo(getidag(ibnf)))
    idagnodeid = getidagnodeid(idagnode)
    if haskey(installedlightpaths, idagnodeid)
        delete!(installedlightpaths, idagnodeid)
        return true
    end
    return false
end

"""
$(TYPEDSIGNATURES)

Return 0 GBPS if invalid intent
"""
function getresidualbandwidth(ibnf::IBNFramework, intentuuid::UUID; onlyinstalled=false)
    idagnode = getidagnode(getidag(ibnf), intentuuid)
    return getresidualbandwidth(ibnf, idagnode; onlyinstalled)
end

function getresidualbandwidth(ibnf::IBNFramework, idagnode::IntentDAGNode; onlyinstalled=false)
    intentuuid = getidagnodeid(idagnode)
    intent = getintent(idagnode)
    if intent isa LightpathIntent || intent isa CrossLightpathIntent
        installedlightpaths = getinstalledlightpaths(getidaginfo(getidag(ibnf)))
        residualbandwidth = gettotalbandwidth(installedlightpaths[intentuuid])
        return getresidualbandwidth(ibnf, intentuuid, residualbandwidth; onlyinstalled)
    elseif intent isa RemoteIntent{<:ConnectivityIntent}
        optinitconstraint = getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getintent(intent)))
        if !isnothing(optinitconstraint)
            residualbandwidth = getrate(gettransmissionmodulecompat(optinitconstraint))
            return getresidualbandwidth(ibnf, intentuuid, residualbandwidth; onlyinstalled)
        end
    end
    return GBPSf(0)
end

function getresidualbandwidth(ibnf::IBNFramework, lightpathuuid::UUID, lightpathRepresentation::LightpathRepresentation; onlyinstalled=false)
    residualbandwidth = gettotalbandwidth(lightpathRepresentation)
    return getresidualbandwidth(ibnf, lightpathuuid, residualbandwidth; onlyinstalled)
end
"""
$(TYPEDSIGNATURES)

Return how much bandwidth is left unused in the lightpath
"""
function getresidualbandwidth(ibnf::IBNFramework, lightpathuuid::UUID, residualbandwidth::GBPSf; onlyinstalled=false)
    for idn in getidagnoderoots(getidag(ibnf), lightpathuuid)
        onlyinstalled && getidagnodestate(idn) != IntentState.Installed && continue
        intent = getintent(idn)
        if intent isa ConnectivityIntent
            subrate = getrate(intent)
        elseif intent isa RemoteIntent{ConnectivityIntent}
            subrate = getrate(getintent(getintent(intent)))
        else
            subrate = GBPSf(0)
        end
        residualbandwidth -= subrate
    end
    # get topmost intents
    return residualbandwidth
end

"""
$(TYPEDSIGNATURES)
"""
function getrouterlli(ena::EndNodeAllocations)
    return RouterPortLLI(getlocalnode(ena), getrouterportindex(ena))
end

"""
$(TYPEDSIGNATURES)
"""
function gettrasmissionmodulelli(ena::EndNodeAllocations)
    return TransmissionModuleLLI(getlocalnode(ena), gettransmissionmoduleviewpoolindex(ena), gettransmissionmodesindex(ena), getrouterportindex(ena), getadddropport(ena))
end

function areintentsequal(conintent1::ConnectivityIntent, conintent2::ConnectivityIntent)
    getsourcenode(conintent1) == getsourcenode(conintent2) || return false
    getdestinationnode(conintent1) == getdestinationnode(conintent2) || return false
    getrate(conintent1) == getrate(conintent2) || return false
    length(getconstraints(conintent1)) == length(getconstraints(conintent1)) || return false
    return all(zip(getconstraints(conintent1), getconstraints(conintent2))) do (c1, c2)
        c1 == c2
    end
end

function setforopticalinitiate!(mena::MutableEndNodeAllocations)
    setrouterportindex!(mena, nothing)
    settransmissionmoduleviewpoolindex!(mena, nothing)
    settransmissionmodesindex!(mena, nothing)
end

"""
$(TYPEDSIGNATURES) 

Return the leaf idagnodes to install. Code is very similar to getidagnodeleafs(::IntentDAG) but suited for exactly the isntallation scenario
If installation is not possible return empty.
"""
function getidagnodeleafs2install(ibnf::IBNFramework, idagnodeid::UUID)
    idag = getidag(ibnf)
    idns = IntentDAGNode[]

    _leafs_recu2install!(idns, ibnf, getidagnode(idag, idagnodeid))

    return idns
end

function _leafs_recu2install!(vidns::Vector{IntentDAGNode}, ibnf::IBNFramework, idn::IntentDAGNode)
    dag = getidag(ibnf)
    if hasidagnodechildren(dag, idn)
        if getintent(idn) isa ProtectedLightpathIntent
            chidns = getidagnodechildren(dag, idn)

            chidnshavenofailchildren = [
                let
                    chidnchidns = getidagnodechildren(dag, chidn)
                    !any(chidnchidn -> getintent(chidnchidn) isa OXCAddDropBypassSpectrumLLI && isoxcllifail(ibnf, getintent(chidnchidn)), chidnchidns)
                end
                for chidn in chidns]

            if all(!, chidnshavenofailchildren)
                empty!(vidns)
                return true
            end

            for chidn in chidns[chidnshavenofailchildren]
                killswitch = _leafs_recu2install!(vidns, ibnf, chidn)
                killswitch && return true
                break
            end
        else
            for chidn in getidagnodechildren(dag, idn)
                killswitch = _leafs_recu2install!(vidns, ibnf, chidn)
                killswitch && return true
            end
        end
    else
        any(x -> x === idn, vidns) || push!(vidns, idn)
    end
    return false
end


function gettransmissionmodule(ibnf::IBNFramework, endnodeallocations::EndNodeAllocations)
    localnode = getlocalnode(endnodeallocations)
    nodeview = getnodeview(getibnag(ibnf), localnode)
    transmissionmoduleviewpoolindex = gettransmissionmoduleviewpoolindex(endnodeallocations)
    return gettransmissionmoduleviewpool(nodeview)[transmissionmoduleviewpoolindex]
end

function gettransmissionmode(ibnf::IBNFramework, endnodeallocations::EndNodeAllocations)
    transmodule = gettransmissionmodule(ibnf, endnodeallocations)
    modeindex = gettransmissionmodesindex(endnodeallocations)
    return gettransmissionmodes(transmodule)[modeindex]
end
