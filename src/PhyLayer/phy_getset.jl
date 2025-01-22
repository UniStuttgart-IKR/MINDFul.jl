function getdistance(s)
    return s.distance
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
    return tm.spectrumslotsreq
end

"$(TYPEDSIGNATURES)"
function getcost(tmd::TransmissionModuleDummy) 
    return tmd.cost
end

"$(TYPEDSIGNATURES)"
function gettransmodes(tmd::TransmissionModuleDummy) 
    return tmd.transmodes
end

"$(TYPEDSIGNATURES)"
function gettransmode(tmd::TransmissionModuleDummy) 
    return gettransmodes(tmd)[tmd.selected]
end

"$(TYPEDSIGNATURES)"
function getspectrumslotreq(tmd::TransmissionModuleDummy) 
    return getspectrumslotreq(gettransmodes(tmd)[tmd.selected])
end

function getrate(tmd::TransmissionModuleDummy) 
    return getrate(gettransmodes(tmd)[tmd.selected])
end

"$(TYPEDSIGNATURES)"
function setselectedmode!(tmd::TransmissionModuleDummy, m::Int)
    tmd.selected = m
    return nothing
end

"$(TYPEDSIGNATURES)"
function getname(s)
    return s.name
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

# NodeView
"$(TYPEDSIGNATURES)"
function getnodeproperties(s::NodeView)
    return s.nodeproperties
end

"$(TYPEDSIGNATURES)"
function getrouterview(s::NodeView)
    return s.routerview
end

"$(TYPEDSIGNATURES)"
function getoxcview(s::NodeView)
    return s.oxcview
end

"$(TYPEDSIGNATURES)"
function gettransmissionmoduleviewpool(s::NodeView)
    return s.transmissionmoduleviewpool
end

"$(TYPEDSIGNATURES)"
function gettransmissionmodulereservations(s::NodeView)
    return s.transmissionmodulereservations
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
