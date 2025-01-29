# general behavior

"""
$(TYPEDSIGNATURES)

Implement this function to do custom actions per specific `ReservableResourceView`
"""
function insertreservationhook!(resourceview::ReservableResourceView, dagnodeid::UUID, reservationdescription; verbose::Bool=false)
    return true
end

"""
$(TYPEDSIGNATURES)

Implement this function to do custom actions per specific `ReservableResourceView`
"""
function deletereservationhook!(resourceview::ReservableResourceView, dagnodeid::UUID; verbose::Bool=false)
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function insertreservation!(resourceview::ReservableResourceView, dagnodeid::UUID, reservationdescription; verbose::Bool=false)
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
    delete!(reservationsdict, dagnodeid)
end

"""
$(TYPEDSIGNATURES)
TODO: put reservations on the OXC edges
"""
function reserve!(resourceview::ReservableResourceView, lowlevelintent::LowLevelIntent, dagnodeid::UUID; checkfirst::Bool=false, verbose::Bool=false)
    checkfirst && !canreserve(resourceview, lowlevelintent; verbose) && return false
    return insertreservation!(resourceview, dagnodeid, lowlevelintent; verbose)
end

"""
$(TYPEDSIGNATURES)
"""
function unreserve!(resourceview::ReservableResourceView, dagnodeid::UUID; verbose::Bool=false)
    deletereservation!(resourceview, dagnodeid; verbose)
    return true
end

# specific behabior

"""
$(TYPEDSIGNATURES)

Check if router port exists and whether it is already used

Set `verbose=true` to see where the reservation fails
"""
function canreserve(routerview::RouterView, routerportlli::RouterPortLLI; verbose::Bool=false)
    # router port exist?
    @returniffalse(verbose, getrouterportindex(routerportlli) <= getportnumber(routerview))
    # router port in use?
    @returniffalse(verbose, getrouterportindex(routerportlli) ∉ getrouterportindex.(values(getreservations(routerview))) )
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function insertreservationhook!(oxcview::OXCView, dagnodeid::UUID, reservationdescription::OXCAddDropBypassSpectrumLLI; verbose::Bool=false)
    return setoxcviewlinkavailabilities!(oxcview, reservationdescription, false; verbose)
end

"""
$(TYPEDSIGNATURES)
"""
function deletereservationhook!(oxcview::OXCView, dagnodeid::UUID; verbose::Bool=false)
    switchreservations = getreservations(oxcview)
    @returniffalse(verbose, haskey(switchreservations, dagnodeid))
    reservationdescription = switchreservations[dagnodeid] 
    return setoxcviewlinkavailabilities!(oxcview, reservationdescription, true; verbose)
end


"""
$(TYPEDSIGNATURES)

Check whether
- add/drp port exists
- add/drp port already in use
- spectrum in fibers in use

Set `verbose=true` to see where the reservation fails
"""
function canreserve(oxcview::OXCView, oxcswitchreservationentry::OXCAddDropBypassSpectrumLLI; verbose::Bool=false)
    @returniffalse(verbose, isreservationvalid(oxcswitchreservationentry))
    @returniffalse(verbose, getport_adddrop(oxcswitchreservationentry) <= getadddropportnumber(oxcview))
    # further check the spectrum
    if !isadddropportallocation(oxcswitchreservationentry)
        for registeredoxcswitchentry in values(getreservations(oxcview))
            if getlocalnode_input(registeredoxcswitchentry) == getlocalnode_input(oxcswitchreservationentry) && 
                    getport_adddrop(registeredoxcswitchentry) == getport_adddrop(oxcswitchreservationentry) && 
                    getlocalnode_output(registeredoxcswitchentry) == getlocalnode_output(oxcswitchreservationentry)
                spectrumslotintersection = intersect(getspectrumslotsrange(registeredoxcswitchentry), getspectrumslotsrange(oxcswitchreservationentry))
                @returniffalse(verbose, length(spectrumslotintersection) <= 0)
            end
        end
    end
    return true
end

"""
$(TYPEDSIGNATURES)

Set `verbose=true` to see where the reservation fails
"""
function canreserve(nodeview::NodeView, transmissionmodulelli::TransmissionModuleLLI; verbose::Bool=false)
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

Checks if this reservation only reserves the add/drop port, i.e., it's (0, x, 0).
"""
function isadddropportallocation(oxcswitchentry::OXCAddDropBypassSpectrumLLI)
    return iszero(getlocalnode_input(oxcswitchentry)) && !iszero(getport_adddrop(oxcswitchentry)) && iszero(getlocalnode_output(oxcswitchentry)) 
end

"""
$(TYPEDSIGNATURES)
"""
function isreservationvalid(oxcswitchreservationentry::OXCAddDropBypassSpectrumLLI, verbose::Bool=true)
    @returniffalse(verbose,  !(!iszero(getlocalnode_input(oxcswitchreservationentry)) && !iszero(getport_adddrop(oxcswitchreservationentry)) && !iszero(getlocalnode_output(oxcswitchreservationentry))) )
    spectrumslotsrange = getspectrumslotsrange(oxcswitchreservationentry)   
    @returniffalse(verbose,  spectrumslotsrange.start >= 0 && spectrumslotsrange.stop >= 0)
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
        getopticalreach(mode) > demanddistance && getrate(transmode) >= demandrate && return true
    end
    return false
end

"""
$(TYPEDSIGNATURES)

Return the index with the lowest GBPS rate that can get deployed for the given demand rate and distance.
If non is find return `0`.
"""
function getlowestratetransmissionmode(transmissionmoduleview::TransmissionModuleView, demandrate::GBPSf, demanddistance::KMf)
    transmodes = gettransmissionmodes(transmissionmoduleview)
    sps = sortperm(transmodes; by = getrate)
    for sp in sps
        transmode = transmodes[sp]
        getopticalreach(transmode) > demanddistance && getrate(transmode) >= demandrate && return sp
    end
    return 0
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
