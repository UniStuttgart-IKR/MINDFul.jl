# general behavior

"""
$(TYPEDSIGNATURES)

Implement this function to do custom actions per specific `ReservableResourceView`
"""
function insertreservationhook!(resourceview::ReservableResourceView, dagnodeid::UUID, reservationdescription; verbose::Bool = false)
    return true
end

"""
$(TYPEDSIGNATURES)

Implement this function to do custom actions per specific `ReservableResourceView`
"""
function deletereservationhook!(resourceview::ReservableResourceView, dagnodeid::UUID; verbose::Bool = false)
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function insertreservation!(resourceview::ReservableResourceView, dagnodeid::UUID, reservationdescription; verbose::Bool = false)
    insertreservationhook!(resourceview, dagnodeid, reservationdescription; verbose) || return false
    reservationsdict = getreservations(resourceview)
    @returniffalse(verbose, !haskey(reservationsdict, dagnodeid))
    reservationsdict[dagnodeid] = reservationdescription
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function deletereservation!(resourceview::ReservableResourceView, dagnodeid::UUID; verbose)
    deletereservationhook!(resourceview, dagnodeid; verbose) || return false
    reservationsdict = getreservations(resourceview)
    return delete!(reservationsdict, dagnodeid)
end

"""
$(TYPEDSIGNATURES)
TODO: put reservations on the OXC edges
"""
function reserve!(resourceview::ReservableResourceView, lowlevelintent::LowLevelIntent, dagnodeid::UUID; checkfirst::Bool = false, verbose::Bool = false)
    checkfirst && !canreserve(resourceview, lowlevelintent; verbose) && return false
    return insertreservation!(resourceview, dagnodeid, lowlevelintent; verbose)
end

"""
$(TYPEDSIGNATURES)
"""
function unreserve!(resourceview::ReservableResourceView, dagnodeid::UUID; verbose::Bool = false)
    deletereservation!(resourceview, dagnodeid; verbose)
    return true
end

# specific behabior

"""
$(TYPEDSIGNATURES)

Check if router port exists and whether it is already used

Set `verbose=true` to see where the reservation fails
"""
function canreserve(routerview::RouterView, routerportlli::RouterPortLLI; verbose::Bool = false)
    # router port exist?
    @returniffalse(verbose, getrouterportindex(routerportlli) <= getportnumber(routerview))
    # router port in use?
    @returniffalse(verbose, getrouterportindex(routerportlli) ∉ getrouterportindex.(values(getreservations(routerview))))
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function insertreservationhook!(oxcview::OXCView, dagnodeid::UUID, reservationdescription::OXCAddDropBypassSpectrumLLI; verbose::Bool = false)
    return setoxcviewlinkavailabilities!(oxcview, reservationdescription, false; verbose)
end

"""
$(TYPEDSIGNATURES)
"""
function deletereservationhook!(oxcview::OXCView, dagnodeid::UUID; verbose::Bool = false)
    switchreservations = getreservations(oxcview)
    @returniffalse(verbose, haskey(switchreservations, dagnodeid))
    reservationdescription = switchreservations[dagnodeid]
    return setoxcviewlinkavailabilities!(oxcview, reservationdescription, true; verbose)
end


"""
$(TYPEDSIGNATURES)

Check whether
- add/drop port exists
- add/drop port already in use
- spectrum in fibers in use

Set `verbose=true` to see where the reservation fails
"""
function canreserve(oxcview::OXCView, oxcswitchreservationentry::OXCAddDropBypassSpectrumLLI; verbose::Bool = false)
    @returniffalse(verbose, isreservationvalid(oxcswitchreservationentry))
    @returniffalse(verbose, getport_adddrop(oxcswitchreservationentry) <= getadddropportnumber(oxcview))
    # further check the spectrum
    for registeredoxcswitchentry in values(getreservations(oxcview))
        if getlocalnode_input(registeredoxcswitchentry) == getlocalnode_input(oxcswitchreservationentry) &&
                getport_adddrop(registeredoxcswitchentry) == getport_adddrop(oxcswitchreservationentry) &&
                getlocalnode_output(registeredoxcswitchentry) == getlocalnode_output(oxcswitchreservationentry)
            spectrumslotintersection = intersect(getspectrumslotsrange(registeredoxcswitchentry), getspectrumslotsrange(oxcswitchreservationentry))
            @returniffalse(verbose, length(spectrumslotintersection) <= 0)
        end
    end
    return true
end

"""
$(TYPEDSIGNATURES)

Set `verbose=true` to see where the reservation fails
"""
function canreserve(nodeview::NodeView, transmissionmodulelli::TransmissionModuleLLI; verbose::Bool = false)
    transmissionmodulereservations = values(getreservations(nodeview))

    transmissionmoduleviewpool = gettransmissionmoduleviewpool(nodeview)
    reserve2do_transmissionmoduleviewpoolindex = gettransmissionmoduleviewpoolindex(transmissionmodulelli)

    # is the transmission module already in use ?
    @returniffalse(verbose, reserve2do_transmissionmoduleviewpoolindex ∉ gettransmissionmoduleviewpoolindex.(transmissionmodulereservations))
    # does the transmission module exist ?
    @returniffalse(verbose, reserve2do_transmissionmoduleviewpoolindex <= length(transmissionmoduleviewpool))
    ## is transmissionmodesindex available ?
    @returniffalse(verbose, gettransmissionmodesindex(transmissionmodulelli) < length(gettransmissionmodes(transmissionmoduleviewpool[reserve2do_transmissionmoduleviewpoolindex])))

    return true
end

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
    return iszero(getlocalnode_input(oxcswitchentry)) && !iszero(getport_adddrop(oxcswitchentry)) && !iszero(getlocalnode_output(oxcswitchentry))
end

"""
$(TYPEDSIGNATURES)

Checks if this reservation reserves the drop port, i.e., it's (x, y, 0).
"""
function isdropportallocation(oxcswitchentry::OXCAddDropBypassSpectrumLLI)
    return !iszero(getlocalnode_input(oxcswitchentry)) && !iszero(getport_adddrop(oxcswitchentry)) && iszero(getlocalnode_output(oxcswitchentry))
end

"""
$(TYPEDSIGNATURES)
"""
function isreservationvalid(oxcswitchreservationentry::OXCAddDropBypassSpectrumLLI, verbose::Bool = true)
    @returniffalse(verbose, !(!iszero(getlocalnode_input(oxcswitchreservationentry)) && !iszero(getport_adddrop(oxcswitchreservationentry)) && !iszero(getlocalnode_output(oxcswitchreservationentry))))
    spectrumslotsrange = getspectrumslotsrange(oxcswitchreservationentry)
    @returniffalse(verbose, spectrumslotsrange.start >= 0 && spectrumslotsrange.stop >= 0)
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
        getopticalreach(transmode) > demanddistance && getrate(transmode) >= demandrate && return sp
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
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function getavailabletransmissionmoduleviewindex(nodeview::NodeView)
    reservedtransmoduleviewidx = gettransmissionmoduleviewpoolindex.(values(getreservations(nodeview)))
    allidx = eachindex(gettransmissionmoduleviewpool(nodeview))
    # pick out all indices that are not reserved
    return filter(!∈(reservedtransmoduleviewidx), allidx)
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
    for routerportindex in 1:getportnumber(routerview)
        routerportindex ∉ reservedrouterports && return routerportindex
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
    reservedoxcadddropports = getadddropportnumber.(values(getreservations(oxcview)))
    for adddropport in 1:getadddropportnumber(oxcview)
        adddropport ∉ reservedoxcadddropports && return adddropport
    end
    return nothing
end


"""
$(TYPEDSIGNATURES)
"""
function generatelightpathoxcadddropbypassspectrumlli(path::Vector{LocalNode}, sourceadddropport::Int, destadddropport::Int, spectrumslotsrange::UnitRange{Int})
    oxcadddropbypassspectrumllis = OXCAddDropBypassSpectrumLLI[]
    for idx in eachindex(path)
        if idx == 1
            push!(oxcadddropbypassspectrumllis, OXCAddDropBypassSpectrumLLI(path[idx], 0, sourceadddropport, path[idx + 1], spectrumslotsrange))
        elseif idx == length(path)
            push!(oxcadddropbypassspectrumllis, OXCAddDropBypassSpectrumLLI(path[idx], path[idx - 1], destadddropport, 0, spectrumslotsrange))
        else
            push!(oxcadddropbypassspectrumllis, OXCAddDropBypassSpectrumLLI(path[idx], path[idx - 1], 0, path[idx + 1], spectrumslotsrange))
        end
    end
    return oxcadddropbypassspectrumllis
end
