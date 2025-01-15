"""
$(TYPEDSIGNATURES)

Check if router port exists and whether it is already used
"""
function canreserve(routerview::RouterView, routerportindex::Int)
    # router port exist?
    routerportindex > getportnumber(routerview) && return false
    # router port in use?
    routerportindex in values(getreservations(routerview)) && return false
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function insertreservation!(resourceview::ReservableResourceView, dagnodeid::UUID, reservationdescription)
    reservationsdict = getreservations(resourceview)
    reservationsdict[dagnodeid] = reservationdescription
end

"""
$(TYPEDSIGNATURES)
"""
function deletereservation!(resourceview::ReservableResourceView, dagnodeid::UUID)
    reservationsdict = getreservations(resourceview)
    delete!(reservationsdict, dagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function reserve!(resourceview::ReservableResourceView, dagnodeid::UUID, reservationdescription; checkfirst::Bool=false)
    checkfirst && !canreserve(resourceview, reservationdescription) && return false
    insertreservation!(resourceview, dagnodeid, reservationdescription)
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function unreserve!(resourceview::ReservableResourceView, dagnodeid::UUID)
    deletereservation!(resourceview, dagnodeid)
    return true
end

"""
$(TYPEDSIGNATURES)

Check whether
- add/drp port exists
- add/drp port already in use
- spectrum in fibers in use
"""
function canreserve(oxcview::OXCView, oxcswitchreservationentry::OXCSwitchReservationEntry)
    switchreservations = getreservations(oxcview)
    getport_adddrop(oxcswitchreservationentry) > getadddropportnumber(oxcview) && return false
    # further check the spectrum
    if !isadddropallocation(oxcswitchreservationentry)
        for registeredoxcswitchentry in values(getreservations(oxcview))
            if getlocalnode_input(registeredoxcswitchentry) == getlocalnode_input(oxcswitchreservationentry) && 
                    getport_adddrop(registeredoxcswitchentry) == getport_adddrop(oxcswitchreservationentry) && 
                    getlocalnode_output(registeredoxcswitchentry) == getlocalnode_output(oxcswitchreservationentry)
                spectrumslotintersection = intersection(getspectrumslotsrange(registeredoxcswitchentry), getspectrumslotsrange(oxcswitchreservationentry))
                length(spectrumslotintersection) > 0 && return false
            end
        end
    end
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function canreserve(nodeview::NodeView, transmissionmodulereservationentry::TransmissionModuleReservationEntry)
    transmissionmodulereservations = values(getreservations(nodeview))

    ## is transmissionmoduleviewpoolindex available ?
    transmissionmodueviewpool = gettransmissionmoduleviewpool(nodeview)

    reserve2do_transmissionmoduleviewpoolindex = gettransmissionmoduleviewpoolindex(transmissionmodulereservationentry) 
    # is the transmission module already in use ?
    reserve2do_transmissionmoduleviewpoolindex in gettransmissionmoduleviewpoolindex.(transmissionmodulereservations) && return false
    # does the transmission module exist ?
    reserve2do_transmissionmoduleviewpoolindex > length(transmissionmodueviewpool) && return false

    ## is transmissionmodesindex available ?
    gettransmissionmodesindex(transmissionmodulereservationentry) > length(gettransmissionmodes(transmissionmodueviewpool[reserve2do_transmissionmoduleviewpoolindex])) && return false

    # is routerportindex available ?
    canreserve(getrouterview(nodeview), getrouterportindex(transmissionmodulereservationentry)) || return false
    # routerportindex = getrouterportindex(

    # is oxcadddropportindex available ?
    oxcswitchentry = newoxcentry_adddropallocation(getoxcadddropportindex(transmissionmodulereservationentry))
    canreserve(getoxcview(nodeview), oxcswitchentry) || return false

    return true
end

"""
$(TYPEDSIGNATURES)
"""
function reserve!(nodeview::NodeView, dagnodeid::UUID, transmissionmodulereservationentry::TransmissionModuleReservationEntry; checkfirst=false)
    checkfirst && !canreserve(nodeview, transmissionmodulereservationentry) && return false
    insertreservation!(nodeview, dagnodeid, transmissionmodulereservationentry)

    insertreservation!(getrouterview(nodeview), dagnodeid, getrouterportindex(transmissionmodulereservationentry))

    oxcswitchentry = newoxcentry_adddropallocation(getoxcadddropportindex(transmissionmodulereservationentry))
    insertreservation!(getoxcview(nodeview), dagnodeid, oxcswitchentry)

    return true
end

"""
$(TYPEDSIGNATURES)
"""
function unreserve!(nodeview::NodeView, dagnodeid::UUID)
    deletereservation!(getrouterview(nodeview), dagnodeid)
    deletereservation!(getoxcview(nodeview), dagnodeid)
    deletereservation!(nodeview, dagnodeid)
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function newoxcentry_adddropallocation(port::Int, spectrumslotsrange::UnitRange{Int} = 0:0)
    return OXCSwitchReservationEntry(0, port, 0, spectrumslotsrange)
end

"""
$(TYPEDSIGNATURES)
"""
function isadddropallocation(oxcswitchentry::OXCSwitchReservationEntry)
    return getlocalnode_input(oxcswitchentry) == 0 && getport_adddrop(oxcswitchentry) != 0 && getlocalnode_output(oxcswitchentry) == 0
end
