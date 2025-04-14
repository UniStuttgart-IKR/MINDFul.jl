
"""
$(TYPEDSIGNATURES)

Implement this function to do custom actions per specific `ReservableResourceView`
"""
function insertreservationhook!(sdn::AbstractSDNController, resourceview::ReservableResourceView, dagnodeid::UUID, reservationdescription; verbose::Bool = false)
    return true
end

"""
$(TYPEDSIGNATURES)

Implement this function to do custom actions per specific `ReservableResourceView`
"""
function deletereservationhook!(sdn::AbstractSDNController, resourceview::ReservableResourceView, dagnodeid::UUID; verbose::Bool = false)
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function insertreservation!(sdn::AbstractSDNController, resourceview::ReservableResourceView, dagnodeid::UUID, reservationdescription; verbose::Bool = false)
    insertreservationhook!(sdn, resourceview, dagnodeid, reservationdescription; verbose) || return false
    reservationsdict = getreservations(resourceview)
    @returniffalse(verbose, !haskey(reservationsdict, dagnodeid))
    reservationsdict[dagnodeid] = reservationdescription
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function deletereservation!(sdn::AbstractSDNController, resourceview::ReservableResourceView, dagnodeid::UUID; verbose)
    deletereservationhook!(sdn, resourceview, dagnodeid; verbose) || return false
    reservationsdict = something(getreservations(resourceview))
    return delete!(reservationsdict, dagnodeid)
end

"""
$(TYPEDSIGNATURES)
TODO: put reservations on the OXC edges
"""
function reserve!(sdn::AbstractSDNController, resourceview::ReservableResourceView, lowlevelintent::LowLevelIntent, dagnodeid::UUID; checkfirst::Bool = false, verbose::Bool = false)
    checkfirst && !canreserve(sdn, resourceview, lowlevelintent; verbose) && return false
    return insertreservation!(sdn, resourceview, dagnodeid, lowlevelintent; verbose)
end

"""
$(TYPEDSIGNATURES)
"""
function unreserve!(sdn::AbstractSDNController, resourceview::ReservableResourceView, dagnodeid::UUID; verbose::Bool = false)
    deletereservation!(sdn, resourceview, dagnodeid; verbose)
    return true
end

# specific behabior

"""
$(TYPEDSIGNATURES)

Check if router port exists and whether it is already used

Set `verbose=true` to see where the reservation fails
"""
function canreserve(sdn::AbstractSDNController, routerview::RouterView, routerportlli::RouterPortLLI; verbose::Bool = false)
    # router port exist?
    @returniffalse(verbose, getrouterportindex(routerportlli) <= getportnumber(routerview))
    # router port in use?
    @returniffalse(verbose, getrouterportindex(routerportlli) ∉ getrouterportindex.(values(getreservations(routerview))))
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function insertreservationhook!(sdn::AbstractSDNController, oxcview::OXCView, dagnodeid::UUID, reservationdescription::OXCAddDropBypassSpectrumLLI; verbose::Bool = false)
    return setoxcviewlinkavailabilities!(oxcview, reservationdescription, false; verbose)
end

"""
$(TYPEDSIGNATURES)
"""
function deletereservationhook!(sdn::AbstractSDNController, oxcview::OXCView, dagnodeid::UUID; verbose::Bool = false)
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
function canreserve(sdn::AbstractSDNController, oxcview::OXCView, oxcswitchreservationentry::OXCAddDropBypassSpectrumLLI; verbose::Bool = false)
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
function canreserve(sdn::AbstractSDNController, nodeview::NodeView, transmissionmodulelli::TransmissionModuleLLI; verbose::Bool = false)
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
