# general behavior
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
function reserve!(resourceview::ReservableResourceView, dagnodeid::UUID, lowlevelintent::LowLevelIntent; checkfirst::Bool=false, verbose::Bool=false)
    checkfirst && !canreserve(resourceview, lowlevelintent, verbose) && return false
    insertreservation!(resourceview, dagnodeid, lowlevelintent)
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function unreserve!(resourceview::ReservableResourceView, dagnodeid::UUID)
    deletereservation!(resourceview, dagnodeid)
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
                spectrumslotintersection = intersection(getspectrumslotsrange(registeredoxcswitchentry), getspectrumslotsrange(oxcswitchreservationentry))
                @returniffalse(verbose, length(spectrumslotintersection) > 0)
            end
        end
    end
    return true
end

"""
$(TYPEDSIGNATURES)

Set `verbose=true` to see where the reservation fails
"""
function canreserve(nodeview::NodeView, transmissionmodulereservationentry::TransmissionModuleLLI; verbose::Bool=false)
    transmissionmodulereservations = values(getreservations(nodeview))

    ## is transmissionmoduleviewpoolindex available ?
    transmissionmodueviewpool = gettransmissionmoduleviewpool(nodeview)

    reserve2do_transmissionmoduleviewpoolindex = gettransmissionmoduleviewpoolindex(transmissionmodulereservationentry) 
    # is the transmission module already in use ?
    @returniffalse(verbose, reserve2do_transmissionmoduleviewpoolindex ∉ gettransmissionmoduleviewpoolindex.(transmissionmodulereservations))
    # does the transmission module exist ?
    @returniffalse(verbose, reserve2do_transmissionmoduleviewpoolindex <= length(transmissionmodueviewpool))

    ## is transmissionmodesindex available ?
    @returniffalse(verbose, gettransmissionmodesindex(transmissionmodulereservationentry) < length(gettransmissionmodes(transmissionmodueviewpool[reserve2do_transmissionmoduleviewpoolindex])))

    # is routerportindex available ?
    @returniffalse(verbose, canreserve(getrouterview(nodeview), getrouterportindex(transmissionmodulereservationentry); verbose))
    # routerportindex = getrouterportindex(

    # is oxcadddropportindex available ?
    oxcswitchentry = newoxcentry_adddropallocation(getoxcadddropportindex(transmissionmodulereservationentry))
    @returniffalse(verbose, canreserve(getoxcview(nodeview), oxcswitchentry; verbose))

    return true
end

"""
$(TYPEDSIGNATURES)
"""
function reserve!(nodeview::NodeView, dagnodeid::UUID, transmissionmodulereservationentry::TransmissionModuleLLI; checkfirst=false, verbose::Bool=true)
    checkfirst && !canreserve(nodeview, transmissionmodulereservationentry, verbose) && return false
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
    return OXCAddDropBypassSpectrumLLI(0, port, 0, spectrumslotsrange)
end

"""
$(TYPEDSIGNATURES)

Checks if this reservation only reserves the add/drop port, i.e., it's (0, x, 0).
"""
function isadddropportallocation(oxcswitchentry::OXCAddDropBypassSpectrumLLI)
    return iszero(getlocalnode_input(oxcswitchentry)) && !iszero(getport_adddrop(oxcswitchentry)) && iszero(getlocalnode_output(oxcswitchentry)) 
end

function isreservationvalid(oxcswitchreservationentry::OXCAddDropBypassSpectrumLLI, verbose::Bool=true)
    @returniffalse(verbose,  !(!iszero(getlocalnode_input(oxcswitchreservationentry)) && !iszero(getport_adddrop(oxcswitchreservationentry)) && !iszero(getlocalnode_output(oxcswitchreservationentry))) )
    spectrumslotsrange = getspectrumslotsrange(oxcswitchreservationentry)   
    @returniffalse(verbose,  spectrumslotsrange.start >= 0 && spectrumslotsrange.stop >= 0)
    return true
end
