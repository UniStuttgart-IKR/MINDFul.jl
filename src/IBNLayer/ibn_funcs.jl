"""
$(TYPEDSIGNATURES)

Add a new user intent to the IBN framework.
"""
function addintent!(ibnf::IBNFramework, intent::AbstractIntent, intentissuer::IntentIssuer)
    intentdag = getidag(ibnf)
    idagnode =  addidagnode!(intentdag, intent; intentissuer)
    return getidagnodeid(idagnode)
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
function compileintent!(ibnf::IBNFramework, idagnodeid::UUID, algorithm::IntentCompilationAlgorithm; verbose::Bool=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled)
    idagnode = getidagnode(getidag(ibnf), idagnodeid)
    return compileintent!(ibnf, idagnode, algorithm)
end

"""
$(TYPEDSIGNATURES)
"""
function compileintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:RemoteIntent}, algorithm::IntentCompilationAlgorithm)
    if !getisinitiator(getintent(idagnode))
        idagnodechild = addidagnode!(getidag(ibnf), getintent(getintent(idagnode)); parentid = getidagnodeid(idagnode), intentissuer = MachineGenerated())
        return compileintent!(ibnf, idagnodechild, algorithm)
    else
        return false
    end
end

"""
$(TYPEDSIGNATURES)
"""
function uncompileintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Compiled)
    idagnodedescendants = getidagnodedescendants(getidag(ibnf), idagnodeid)
    foreach(idagnodedescendants) do idagnodedescendant
        if getintent(idagnodedescendant) isa RemoteIntent
            ibnfhandler = getibnfhandler(ibnf, getibnfid(getintent(idagnodedescendant)))
            uncompiledflag = requestuncompileintent_init!(ibnf, ibnfhandler, getidagnodeid(getintent(idagnodedescendant)); verbose)
            uncompiledflag && removeidagnode!(getidag(ibnf), getidagnodeid(idagnodedescendant))
        else
            removeidagnode!(getidag(ibnf), getidagnodeid(idagnodedescendant))
        end
    end
    updateidagstates!(ibnf, idagnodeid)
    return getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Uncompiled
end

"""
$(TYPEDSIGNATURES)
"""
function installintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Compiled)
    idagnodeleafs = getidagnodeleafs(getidag(ibnf), idagnodeid; exclusive = false)
    foreach(idagnodeleafs) do idagnodeleaf
        reserveunreserveleafintents!(ibnf, idagnodeleaf, true; verbose)
    end
    return getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Installed
end

"""
$(TYPEDSIGNATURES)
"""
function uninstallintent!(ibnf::IBNFramework, idagnodeid::UUID; verbose::Bool=false)
    @returniffalse(verbose, getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Installed)
    idagnodeleafs = getidagnodeleafs(getidag(ibnf), idagnodeid; exclusive = false)
    foreach(idagnodeleafs) do idagnodeleaf
        reserveunreserveleafintents!(ibnf, idagnodeleaf, false; verbose)
    end
    return getidagnodestate(getidag(ibnf), idagnodeid) == IntentState.Compiled
end

"""
$(TYPEDSIGNATURES)

to reserve pass `doinstall=true`, and to unreserve `doinstall=false`
"""
function reserveunreserveleafintents!(ibnf::IBNFramework, idagnodeleaf::IntentDAGNode, doinstall::Bool; verbose::Bool=false)
    leafintent = getintent(idagnodeleaf)
    leafid = getidagnodeid(idagnodeleaf)
    if leafintent isa LowLevelIntent
        localnode = getlocalnode(leafintent)
        nodeview = AG.vertex_attr(getibnag(ibnf))[localnode]
        if leafintent isa TransmissionModuleLLI       
            if doinstall
                reserve!(nodeview, leafintent, leafid; checkfirst=true, verbose)
            else
                unreserve!(nodeview, leafid; verbose)
            end
        elseif leafintent isa RouterPortLLI
            if doinstall
                reserve!(getrouterview(nodeview), leafintent, leafid; checkfirst=true, verbose)
            else
                unreserve!(getrouterview(nodeview), leafid; verbose)
            end
        elseif leafintent isa OXCAddDropBypassSpectrumLLI
            if doinstall
                reserve!(getoxcview(nodeview), leafintent, leafid; checkfirst=true, verbose)
            else
                unreserve!(getoxcview(nodeview), leafid; verbose)
            end
        end
        if doinstall
            pushstatetoidagnode!(getlogstate(idagnodeleaf), now(), IntentState.Installed)
        else
            pushstatetoidagnode!(getlogstate(idagnodeleaf), now(), IntentState.Compiled)
        end
    elseif leafintent isa RemoteIntent
        if getisinitiator(leafintent)
            ibnfhandler = getibnfhandler(ibnf, getibnfid(leafintent))
            if doinstall
                requestinstallintent_init!(ibnf, ibnfhandler, getidagnodeid(leafintent); verbose)
            else
                requestuninstallintent_init!(ibnf, ibnfhandler, getidagnodeid(leafintent); verbose)
            end
        end
    end
    # call updateidagstates
    return any(getidagnodeparents(getidag(ibnf), idagnodeleaf)) do idagnodeparent
        updateidagnodestates!(ibnf, idagnodeparent)
    end
end

"""
$(TYPEDSIGNATURES)

Add a `RemoteIntent` as a child intent and delegate it to the ibn with id `remoteibndif`
"""
function remoteintent!(ibnf::IBNFramework, idagnode::IntentDAGNode, remoteibnfid::UUID)
    ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
    internalnextidagnodeid = getidagnextuuidcounter(getidag(ibnf))
    remoteidagnodeid = requestdelegateintent!(ibnf, ibnfhandler, getintent(idagnode), internalnextidagnodeid)

    # add an idagnode `RemoteIntent`
    remoteintent = RemoteIntent(remoteibnfid, remoteidagnodeid, getintent(idagnode), true)

    # add in DAG
    internalidagnode = addidagnode!(getidag(ibnf), remoteintent; parentid=getidagnodeid(idagnode), intentissuer=MachineGenerated())
    @assert internalnextidagnodeid == getidagnodeid(internalidagnode)

    return internalidagnode
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
    #TODO-now: check with remotespectrum request
    ibnag = getibnag(ibnf) 
    nodeviews = AG.vertex_attr(getibnag(ibnf))
    if checkfirst
        srclinkspectrumavailabilities = if isbordernode(ibnf, src(edge))  
            remoteibnfid = getibnfid(getglobalnode(ibnag, src(edge)))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            globaledge = GlobalEdge(getglobalnode(ibnag, src(edge)), getglobalnode(ibnag, dst(edge)))
            something(requestspectrumavailability(ibnf, ibnfhandler, globaledge))
            # getlinkspectrumavailabilities(getoxcview(nodeviews[dst(edge)]))[edge]
        else 
            getlinkspectrumavailabilities(getoxcview(nodeviews[src(edge)]))[edge]
        end

        dstlinkspectrumavailabilities = if isbordernode(ibnf, dst(edge))  
            remoteibnfid = getibnfid(getglobalnode(ibnag, dst(edge)))
            ibnfhandler = getibnfhandler(ibnf, remoteibnfid)
            globaledge = GlobalEdge(getglobalnode(ibnag, src(edge)), getglobalnode(ibnag, dst(edge)))
            something(requestspectrumavailability(ibnf, ibnfhandler, globaledge))
            # getlinkspectrumavailabilities(getoxcview(nodeviews[dst(edge)]))[edge]
        else
            getlinkspectrumavailabilities(getoxcview(nodeviews[dst(edge)]))[edge]
        end

        @assert(srclinkspectrumavailabilities == dstlinkspectrumavailabilities)
    end
    #TODO-now: pick that one that is internal
    return getlinkspectrumavailabilities(getoxcview(nodeviews[src(edge)]))[edge]
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
    compilationalgorithmargs2use = getnumberofparameters(compilationalgorithmtype) != length(compilationalgorithmargs) ? getdefaultcompilationalgorithmargs(compilationalgorithmkey2use) : compilationalgorithmargs
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

