# general behavior

"""
$(TYPEDSIGNATURES)
"""
function newoxcentry_adddropallocation(port::Int, spectrumslotsrange::UnitRange{Int} = 0:0)
    return OXCAddDropBypassSpectrumLLI(0, port, 0, spectrumslotsrange)
end

"""
$(TYPEDSIGNATURES)

Checks if this reservation reserves the add port, i.e., it's (0, x, y).
"""
function isaddportallocation(oxcswitchentry::OXCAddDropBypassSpectrumLLI)
    return iszero(getlocalnode_input(oxcswitchentry)) && !iszero(getadddropport(oxcswitchentry)) && !iszero(getlocalnode_output(oxcswitchentry))
end

"""
$(TYPEDSIGNATURES)

Checks if this reservation reserves the drop port, i.e., it's (x, y, 0).
"""
function isdropportallocation(oxcswitchentry::OXCAddDropBypassSpectrumLLI)
    return !iszero(getlocalnode_input(oxcswitchentry)) && !iszero(getadddropport(oxcswitchentry)) && iszero(getlocalnode_output(oxcswitchentry))
end

"""
$(TYPEDSIGNATURES)
"""
function isreservationvalid(oxcswitchreservationentry::OXCAddDropBypassSpectrumLLI, verbose::Bool = true)
    @returniffalse(verbose, !(!iszero(getlocalnode_input(oxcswitchreservationentry)) && !iszero(getadddropport(oxcswitchreservationentry)) && !iszero(getlocalnode_output(oxcswitchreservationentry))))
    spectrumslotsrange = getspectrumslotsrange(oxcswitchreservationentry)
    @returniffalse(verbose, spectrumslotsrange.start >= 0 && spectrumslotsrange.stop >= 0)
    return true
end

"""
$(TYPEDSIGNATURES)

Return a integer tuple `(Int, Int)` denoting the first available and compatible transmission module index and its transmission mode index.
If non found return `nothing`.
"""
function getfirstcompatibletransmoduleidxandmodeidx(transmissionmoduleviewpool::Vector{<:TransmissionModuleView}, availtransmdlidxs::Vector{Int}, transmissionmodulecompat::TransmissionModuleCompatibility)
    for availtransmdlidx in availtransmdlidxs
        transmissionmoduleview = transmissionmoduleviewpool[availtransmdlidx] 
        transmissionmodes = gettransmissionmodes(transmissionmoduleview)
        for transmodeidx in eachindex(transmissionmodes)
            if istransmissionmoduleandmodecompatible(transmissionmoduleview, transmodeidx, transmissionmodulecompat)
                return (availtransmdlidx, transmodeidx)
            end
        end
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Return true if `transmissionmoduleview` can support with its modes the `transmissionmodulecompat`
"""
function istransmissionmodulecompatible(transmissionmoduleview::TransmissionModuleView, transmissionmodulecompat::TransmissionModuleCompatibility)
    getname(transmissionmoduleview) == getname(transmissionmodulecompat) || return false
    for transmissionmodesindex in eachindex(gettransmissionmodes(transmissionmoduleview))
        istransmissionmoduleandmodecompatible(transmissionmoduleview, transmissionmodesindex, transmissionmodulecompat) && return true
    end
    return false
end

"""
$(TYPEDSIGNATURES)

Return true if the `transmissionmoduleview` and mode support the `transmissionmodulecompat`
If `onlymodecheck = true` is passed then the disaggregation/protocol (aka name) will not be checked.
"""
function istransmissionmoduleandmodecompatible(transmissionmoduleview::TransmissionModuleView, transmissionmodesindex::Int,  transmissionmodulecompat::TransmissionModuleCompatibility)
    getname(transmissionmoduleview) == getname(transmissionmodulecompat) || return false
    transmissionmode = gettransmissionmodes(transmissionmoduleview)[transmissionmodesindex]
    getrate(transmissionmode) == getrate(transmissionmodulecompat) || return false
    getspectrumslotsneeded(transmissionmode) == getspectrumslotsneeded(transmissionmodulecompat) || return false
    return true
end

"""
$(TYPEDSIGNATURES)

Return true if the `transmissionmoduleview` and mode support the `transmissionmodulecompat`
If `onlymodecheck = true` is passed then the disaggregation/protocol (aka name) will not be checked.
"""
function istransmissionmoduleandmodecompatible(transmissionmoduleview::TransmissionModuleView, transmissionmode::TransmissionMode,  transmissionmodulecompat::TransmissionModuleCompatibility)
    getname(transmissionmoduleview) == getname(transmissionmodulecompat) || return false
    getrate(transmissionmode) == getrate(transmissionmodulecompat) || return false
    getspectrumslotsneeded(transmissionmode) == getspectrumslotsneeded(transmissionmodulecompat) || return false
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function aretransmissionmodulescompatible(tmv1::TransmissionModuleView, tmv2::TransmissionModuleView)
    return getname(tmv1) == getname(tmv2)
end

"""
$(TYPEDSIGNATURES)

Checks if the transmission module can get deployed for the given demand rate and distance
"""
function istransmissionmoduleappropriate(transmissionmoduleview::TransmissionModuleView, demandrate::GBPSf, demanddistance::KMf)
    for transmode in gettransmissionmodes(transmissionmoduleview)
        getopticalreach(transmode) > demanddistance && getrate(transmode) >= demandrate && return true
    end
    return false
end

"""
$(TYPEDSIGNATURES)

Return the index with the lowest GBPS rate that can get deployed for the given demand rate and distance.
If non is find return `nothing`.
"""
function getlowestratetransmissionmode(transmissionmoduleview::TransmissionModuleView, demandrate::GBPSf, demanddistance::KMf)
    transmodes = gettransmissionmodes(transmissionmoduleview)
    sps = sortperm(transmodes; by = getrate)
    for sp in sps
        transmode = transmodes[sp]
        getopticalreach(transmode) >= demanddistance && getrate(transmode) >= demandrate && return sp
    end
    return nothing
end


"""
$(TYPEDSIGNATURES)

Set the link spectrum availabilities of the `oxcview` based on the OXC low level intent to `setflags`
"""
function setoxcviewlinkavailabilities!(oxcview::OXCView, oxcadddropbypassspectrumlli::OXCAddDropBypassSpectrumLLI, setflag::Bool; verbose::Bool = false)
    localnode = getlocalnode(oxcadddropbypassspectrumlli)
    localnode_input = getlocalnode_input(oxcadddropbypassspectrumlli)
    localnode_output = getlocalnode_output(oxcadddropbypassspectrumlli)
    spectrumslotsrange = getspectrumslotsrange(oxcadddropbypassspectrumlli)
    linkspectrumavailabilities = getlinkspectrumavailabilities(oxcview)
    if !iszero(localnode_input)
        ed = Edge(localnode_input, localnode)
        @returniffalse(verbose, haskey(linkspectrumavailabilities, ed))
        linkspectrumavailabilities[ed][spectrumslotsrange] .= setflag
    end
    if !iszero(localnode_output)
        ed = Edge(localnode, localnode_output)
        @returniffalse(verbose, haskey(linkspectrumavailabilities, ed))
        linkspectrumavailabilities[ed][spectrumslotsrange] .= setflag
    end
    return ReturnCodes.SUCCESS
end

"""
$(TYPEDSIGNATURES)
Set the operating state of the edge in `oxcview` and trigger the state update of the relevant low level intents.
"""
@recvtime function setlinkstate!(ibnf::IBNFramework, oxcview::OXCView, edge::Edge, operatingstate::Bool)
    setlinkstate!(getsdncontroller(ibnf), oxcview, edge::Edge, operatingstate)
    if getcurrentlinkstate(oxcview, edge) != operatingstate
        linkstates = getlinkstates(oxcview)[edge]
        push!(linkstates, (@logtime, operatingstate))
        # update LLIs
        for (lliid, oxclli) in getreservations(oxcview)
            if oxcllicontainsedge(oxclli, edge)
                if operatingstate
                    updateidagstates!(ibnf, lliid, IntentState.Installed; @passtime)
                else
                    updateidagstates!(ibnf, lliid, IntentState.Failed; @passtime)
                end
            end
        end
    end
    return ReturnCodes.SUCCESS
end

"""
$(TYPEDSIGNATURES)
"""
function getavailabletransmissionmoduleviewindex(nodeview::NodeView)
    reservedtransmoduleviewidx = gettransmissionmoduleviewpoolindex.(values(getreservations(nodeview)))
    stagedtransmoduleviewidx = gettransmissionmoduleviewpoolindex.(getstaged(nodeview))
    allidx = eachindex(gettransmissionmoduleviewpool(nodeview))
    # pick out all indices that are not reserved
    return filter( x -> x ∉ reservedtransmoduleviewidx && x ∉ stagedtransmoduleviewidx, allidx)
end

"""
$(TYPEDSIGNATURES)
"""
function getfirstavailablerouterportindex(nodeview::NodeView)
    return getfirstavailablerouterportindex(getrouterview(nodeview))
end

"""
$(TYPEDSIGNATURES)

Return the first available router port index and `nothing` if non available.
"""
function getfirstavailablerouterportindex(routerview::RouterView)
    reservedrouterports = getrouterportindex.(values(getreservations(routerview)))
    stagedrouterports = getrouterportindex.(getreservations(routerview))
    for routerportindex in 1:getportnumber(routerview)
        routerportindex ∉ reservedrouterports && routerportindex ∉ stagedrouterports && return routerportindex
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)
"""
function getfirstavailableoxcadddropport(nodeview::NodeView)
    return getfirstavailableoxcadddropport(getoxcview(nodeview))
end

"""
$(TYPEDSIGNATURES)

Return the first available oxc add/drop port and `nothing` if none found
"""
function getfirstavailableoxcadddropport(oxcview::OXCView)
    reservedoxcadddropports = getadddropport.(values(getreservations(oxcview)))
    stagedoxcadddropports = getadddropport.(getreservations(oxcview))
    for adddropport in 1:getadddropportnumber(oxcview)
        adddropport ∉ reservedoxcadddropports && adddropport ∉ stageddoxcadddropports && return adddropport
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)
Return a list of (@ref)[OXCAddDropBypassSpectrumLLI] that constitute a lightpath.
According to the arguments a "starting lightpath", an "ending lightpath", or a "lightpath segment" can be created.
The arguments are the following:
- `sourceadddropport`: `nothing` for a starting lightpath and an `Integer` denating the add/drop port otherwise
- `opticalinitincomingnode` : the (@ref)[LocalNode] denoting the incoming optical connection from the specified node for a starting lightpath. Set to `nothing` if not a starting lightpath
- `destadddropport`: `nothing` for an ending lightpath and an `Integer` denating the add/drop port otherwise
Note: not both `sourceadddropport` and `opticalinitincomingnode` can be nothing or have a values at the same time.
"""
function generatelightpathoxcadddropbypassspectrumlli(path::Vector{LocalNode}, spectrumslotsrange::UnitRange{Int}; sourceadddropport=nothing, opticalinitincomingnode=nothing, destadddropport=nothing)
    oxcadddropbypassspectrumllis = OXCAddDropBypassSpectrumLLI[]
    for idx in eachindex(path)
        if idx == 1
            if !isnothing(sourceadddropport) && isnothing(opticalinitincomingnode)
                push!(oxcadddropbypassspectrumllis, OXCAddDropBypassSpectrumLLI(path[idx], 0, sourceadddropport, path[idx + 1], spectrumslotsrange))
            elseif isnothing(sourceadddropport) && !isnothing(opticalinitincomingnode)
                if length(path) == 1 
                    # need to finish where it starts
                    if !isnothing(destadddropport)
                        push!(oxcadddropbypassspectrumllis, OXCAddDropBypassSpectrumLLI(path[idx], opticalinitincomingnode, destadddropport, 0, spectrumslotsrange))
                    end
                else
                    push!(oxcadddropbypassspectrumllis, OXCAddDropBypassSpectrumLLI(path[idx], opticalinitincomingnode, 0, path[idx + 1], spectrumslotsrange))
                end
            end
        elseif idx == length(path)
            if !isnothing(destadddropport)
                push!(oxcadddropbypassspectrumllis, OXCAddDropBypassSpectrumLLI(path[idx], path[idx - 1], destadddropport, 0, spectrumslotsrange))
            end
        else
            push!(oxcadddropbypassspectrumllis, OXCAddDropBypassSpectrumLLI(path[idx], path[idx - 1], 0, path[idx + 1], spectrumslotsrange))
        end
    end
    return oxcadddropbypassspectrumllis
end

"""
$(TYPEDSIGNATURES)
"""
function oxcllicontainsedge(oxclli::OXCAddDropBypassSpectrumLLI, edge::Edge)
    return (getlocalnode(oxclli) == src(edge) && getlocalnode_output(oxclli) == dst(edge)) || (getlocalnode_input(oxclli) == src(edge) && getlocalnode(oxclli) == dst(edge))
end

"""
$(TYPEDSIGNATURES)
"""
function isnodeviewinternal(nv::NodeView)
    return !isnothing(nv.routerview) && !isnothing(nv.oxcview) && !isnothing(nv.transmissionmoduleviewpool) && !isnothing(nv.transmissionmodulereservations) && !isnothing(nv.transmissionmodulestaged)
end

"""
$(TYPEDSIGNATURES)
"""
function stage!(resourceview::ReservableResourceView, lli::LowLevelIntent)
    stagedset = getstaged(resourceview)
    push!(stagedset, lli)
    return ReturnCodes.SUCCESS
end

"""
$(TYPEDSIGNATURES)
"""
function unstage!(resourceview::ReservableResourceView, lli::LowLevelIntent)
    stagedset = something(getstaged(resourceview))
    return delete!(stagedset, lli)
end

