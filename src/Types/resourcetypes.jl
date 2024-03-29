@enum(SignalLoc, signalElectrical, signalElectricalDown, signalElectricalUp, signalTransmissionModuleDown, signalTransmissionModuleUp ,signalGroomingDown, signalGrooming, signalGroomingUp, signalOXCAdd, signalOXCDrop, signalOXCbypass, signalHalfFiberIn, signalFiberIn, signalFiberOut, signalEnd, signalUknown)

@enum(LightpathType, borderinitiatelightpath, borderterminatelightpath, fulllightpath, border2borderlightpath)

"`R` is Int for local mode and `Tuple{Int, Int}` for global"
struct ConnectionState{R}
    node::R
    signaloc::SignalLoc
end
getnode(cs::ConnectionState) = cs.node
getsignalloc(cs::ConnectionState) = cs.signaloc

"""
$(TYPEDEF)
$(TYPEDFIELDS)
Container of the spectrum requirements of a connection
"""
struct SpectrumRequirements
    cedge::NestedEdge
    frslots::UnitRange{Int}
    "Gbps (`Unitful` still doesn't support bits)"
    bandwidth::Float64
end

struct LightpathRequirements
    spslots::UnitRange{Int}
    optreach::typeof(1.0u"km")
    dist::typeof(1.0u"km")
    rate::Float64
end

"""
$(TYPEDEF)

Represents a transmission mode.
A Transponder, if flexible, might support many of such

$(TYPEDFIELDS)
"""
struct TransmissionProps
    "Optical reach in kilometers"
    optreach::typeof(1.0u"km")
    "Gbps"
     rate::Float64  
    "Number of 12.5 GHz frequency slots needed"
    freqslots::Int
end
getrate(trp::TransmissionProps) = trp.rate
getoptreach(trp::TransmissionProps) = trp.optreach
getfreqslots(trp::TransmissionProps) = trp.freqslots


"""
$(TYPEDEF)
$(TYPEDFIELDS)

Could be either a traditional transponder or a Coherent Pluggable Tranceiver.
"""
mutable struct TransmissionModuleView{T}
    "descriptive name of the transmission module"
    name::String
    "The Transmission module to use"
    transp::T
end
getrate(tr::TransmissionModuleView) = getrate(tr.transp)
getoptreach(tr::TransmissionModuleView) = getoptreach(tr.transp)
getfreqslots(tr::TransmissionModuleView) = getfreqslots(tr.transp)
getcost(tr::TransmissionModuleView) = getcost(tr.transp)
gettransmissionmodes(tr::T) where T<:TransmissionModuleView = gettransmissionmodes(tr.transp)
getselection(tr::TransmissionModuleView) = getselection(tr.transp)
setselection!(tr::TransmissionModuleView, s::Int) = setselection!(tr.transp, s)
issimilar(tr1::TransmissionModuleView, tr2::TransmissionModuleView) = Base.isequal(tr1.name, tr2.name) && issimilar(tr1.transp, tr2.transp)
"$(TYPEDSIGNATURES) Check if `tr1` is compatible with `tr2`'s selected mode"
iscompatible(tr1::TransmissionModuleView, tr2::TransmissionModuleView) = iscompatible(tr1.transp, tr2.transp)

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Integrated multilayer node; all inclusive.
"""
struct MLNode{R,T,O,D}
    router::R
    otn::T
    oxc::O
    transmodulespool::Vector{TransmissionModuleView{D}}
    transmodreservations::Vector{Tuple{TransmissionModuleView{D}, Tuple{Int, UUID}}}
end

MLNode(r, otn, oxc, tmp) = MLNode(r, otn, oxc, tmp, Vector{Tuple{TransmissionModuleView{TransmissionModuleDummy}, Tuple{Int, UUID}}}())
getrouter(mln::MLNode) = mln.router
getotn(mln::MLNode) = mln.otn
getoxc(mln::MLNode) = mln.oxc
gettransmodulespool(mln::MLNode) = mln.transmodulespool
gettransmodreservations(mln::MLNode) = mln.transmodreservations

struct RouterView{R}
    router::R
    "lists which ports are available"
    portavailability::Vector{Bool}
    "lists which intents are reserved the resources"
    reservations::Vector{Union{Missing,Tuple{Int, UUID}}}
end
#RouterView(rt::RouterDummy) = RouterView(rt, fill(true, rt.nports), Vector{Union{Missing,Tuple{Int,Int,UUID}}}(fill(missing, rt.nports)))
RouterView(rt) = RouterView(rt, Vector{Bool}(), Vector{Union{Missing,Tuple{Int,UUID}}}())
getportrate(rv::RouterView, p::Int) = getportrate(rv.router, p)
getportcost(rv::RouterView, p::Int) = getportcost(rv.router, p)
gettotalcost(rv::RouterView) = gettotalcost(rv.router)
newlinecardcost(rv::RouterView, rt::Float64, lcs, lcc) = newlinecardcost(rv.router, rt, lcs, lcc)
function addlinecard!(rv::RouterView, lc)
    portnum = addlinecard!(rv.router, lc)
    if !isnothing(portnum)
        push!(rv.portavailability, fill(true, portnum)...)
        push!(rv.reservations, fill(missing, portnum)...)
        return true
    end
    return false
end

struct OTNView end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Essentially it just have one switch.
But logically we split it up to bypass, drop and add switch.
"""
struct OXCView
    "edges coming into the OXC"
    inedges::Vector{Edge}
    "edges going out from the OXC"
    outedges::Vector{Edge}
    "connects `inedges` to `outedges` with a spslots, if `0` then it's either Add/Drop"
    switchconf::Vector{Tuple{Int,Int,UnitRange{Int}}}
    "one to one mapping to `switchconf`"
    reservations::Vector{Tuple{Int, UUID}}
end
OXCView() = OXCView(Vector{Edge}(), Vector{Edge}(), Vector{Tuple{Int,Int,UnitRange{Int}}}(), Vector{Tuple{Int, UUID}}())
OXCView(node, innei, outnei) = OXCView([Edge(i,node) for i in innei], [Edge(node, o) for o in innei])
OXCView(inedges, outedges) = OXCView(inedges, outedges, Vector{Tuple{Int,Int,UnitRange{Int}}}(), Vector{Tuple{Int, UUID}}())

mutable struct FiberView{F,L<:LogState}
    fiber::F
    operates::Bool
    logstate::L
    "True if available"
    spectrum_src::Vector{Bool}
    "lists which intents are reserved the resources"
    reservations_src::Vector{Union{Missing,Tuple{Int, UUID}}}

    spectrum_dst::Vector{Bool}
    reservations_dst::Vector{Union{Missing,Tuple{Int, UUID}}}
end
FiberView(fiber; frequency_slots=320) = FiberView(fiber, true, LogState{Bool}(),fill(true, frequency_slots), Vector{Union{Missing,Tuple{Int,UUID}}}(fill(missing, frequency_slots)), fill(true, frequency_slots), Vector{Union{Missing,Tuple{Int,UUID}}}(fill(missing, frequency_slots)))

struct OpticalRequirements
    "frequency slots allocation"
    frslots::Int
    # TODO modulation
    optreach::typeof(1.0u"km")
    "data rate in Gbps"
    drate::Float64
end

struct OpticalTransProperties
    "frequency slots allocation"
    channel::RangeHotVector
    # TODO modulation
    optreach::typeof(1.0u"km")
    "data rate in Gbps"
    drate::Float64
end

struct OpticalCircuit
    "lightpath"
    path::Vector{Int}
    "frequency slots allocation"
    props::OpticalTransProperties
end
