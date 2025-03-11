function getname(s)
    return s.name
end

function getdistance(s)
    return s.distance
end

function getdistance(s::EdgeView)
    return getdistance(getproperties(s))
end

function getspectrumslots(s)
    return s.spectrumslots
end

function getspectrumavailability(s)
    return s.spectrumavailability
end

function getportnumber(s)
    return s.portnumber
end

"$(TYPEDSIGNATURES)"
function getreservations(routerview::RouterView)
    return routerview.portreservations
end

"$(TYPEDSIGNATURES)"
function getreservations(oxcview::OXCView)
    return oxcview.switchreservations
end

"$(TYPEDSIGNATURES)"
function getadddropportnumber(oxcview::OXCView)
    return oxcview.adddropportnumber
end

"""
$(TYPEDSIGNATURES)
"""
function getlinkspectrumavailabilities(oxcview::OXCView)
    return oxcview.linkspectrumavailabilities
end

"$(TYPEDSIGNATURES)"
function getlocalnode_input(oxcswitchreservationentry::OXCAddDropBypassSpectrumLLI)
    return oxcswitchreservationentry.localnode_input
end

"$(TYPEDSIGNATURES)"
function getport_adddrop(oxcswitchentry::OXCAddDropBypassSpectrumLLI)
    return oxcswitchentry.adddropport
end

"$(TYPEDSIGNATURES)"
function getlocalnode_output(oxcswitchentry::OXCAddDropBypassSpectrumLLI)
    return oxcswitchentry.localnode_output
end

"$(TYPEDSIGNATURES)"
function getspectrumslotsrange(oxcswitchentry::OXCAddDropBypassSpectrumLLI)
    return oxcswitchentry.spectrumslotsrange
end

"$(TYPEDSIGNATURES)"
function getreservations(nodeview::NodeView)
    return nodeview.transmissionmodulereservations
end


"$(TYPEDSIGNATURES)"
function getopticalreach(tm::TransmissionMode)
    return tm.opticalreach
end

"$(TYPEDSIGNATURES)"
function getrate(tm::TransmissionMode)
    return tm.rate
end

"$(TYPEDSIGNATURES)"
function getspectrumslotsneeded(tm::TransmissionMode)
    return tm.spectrumslotsneeded
end

"$(TYPEDSIGNATURES)"
function getcost(s)
    return s.cost
end

# TransmissionModuleView
"$(TYPEDSIGNATURES)"
function getunderlyingequipment(s::TransmissionModuleView)
    return s.transmissionmodule
end

"$(TYPEDSIGNATURES)"
function gettransmissionmodes(s::TransmissionModuleView)
    return s.transmissionmodes
end

"$(TYPEDSIGNATURES)"
function gettransmissionmode(s::TransmissionModuleView, transmissionmodeidx::Int)
    return gettransmissionmodes(s)[transmissionmodeidx]
end

# NodeView
"$(TYPEDSIGNATURES)"
function getnodeproperties(s::NodeView)
    return s.nodeproperties
end

"$(TYPEDSIGNATURES)"
function getproperties(s::NodeView)
    return s.nodeproperties
end

"$(TYPEDSIGNATURES)"
function getproperties(s::EdgeView)
    return s.edgeproperties
end

"$(TYPEDSIGNATURES)"
function getrouterview(s::NodeView)
    return something(s.routerview)
end

"$(TYPEDSIGNATURES)"
function getoxcview(s::NodeView)
    return something(s.oxcview)
end

"$(TYPEDSIGNATURES)"
function gettransmissionmoduleviewpool(s::NodeView)
    return something(s.transmissionmoduleviewpool)
end

"$(TYPEDSIGNATURES)"
function gettransmissionmodulereservations(s::NodeView)
    return something(s.transmissionmodulereservations)
end

"""
$(TYPEDSIGNATURES)
"""
function getlatitude(np::NodeProperties)
    return np.latitude
end

"""
$(TYPEDSIGNATURES)
"""
function getlongitude(np::NodeProperties)
    return np.longitude
end

"$(TYPEDSIGNATURES)"
function getinneighbors(np::NodeProperties)
    return np.inneighbors
end

"$(TYPEDSIGNATURES)"
function getoutneighbors(np::NodeProperties)
    return np.outneighbors
end

"$(TYPEDSIGNATURES)"
function getlocalnode(s)
    return s.localnode
end

"$(TYPEDSIGNATURES)"
function getglobalnode(s)
    return s.globalnode
end

# TransmissionModuleReservationEntry
"$(TYPEDSIGNATURES)"
function gettransmissionmoduleviewpoolindex(s::TransmissionModuleLLI)
    return s.transmissionmoduleviewpoolindex
end

"$(TYPEDSIGNATURES)"
function gettransmissionmodesindex(s::TransmissionModuleLLI)
    return s.transmissionmodesindex
end

"$(TYPEDSIGNATURES)"
function getrouterportindex(s::RouterPortLLI)
    return s.routerportindex
end

"$(TYPEDSIGNATURES)"
function getoxcadddropportindex(s::OXCAddDropBypassSpectrumLLI)
    return s.adddropport
end
