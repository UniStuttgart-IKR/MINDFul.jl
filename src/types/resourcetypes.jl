@enum(SignalLoc, signalElectrical, signalElectricalDown, signalElectricalUp, signalGroomingDown, signalGrooming, signalGroomingUp, 
      signalOXCAdd, signalOXCDrop, signalOXCbypass, signalFiberIn, signalFiberOut, signalEnd)

"R is Int for local mode and Tuple{Int, Int} for global"
struct ConnectionState{R}
    node::R
    signaloc::SignalLoc
end
getnode(cs::ConnectionState) = cs.node

struct SpectrumRequirements
    cedge::CompositeEdge
    frslots::UnitRange{Int}
    "Gbps"
    bandwidth::Float64
end

struct Transponder
    optreach::typeof(1.0u"km")
    rate::Float64
    frslots::Int
end
getrate(tr::Transponder) = tr.rate
getoptreach(tr::Transponder) = tr.optreach
getslots(tr::Transponder) = tr.frslots
transponderset() = Vector{Transponder}([
            Transponder(5080.0u"km", 300, 8),
            Transponder(4400.0u"km", 400, 8),
            Transponder(2800.0u"km", 500, 8),
            Transponder(1200.0u"km", 600, 8),
            Transponder(700.0u"km", 700, 10),
            Transponder(400.0u"km", 800, 10),
           ])

struct MLNode{R,T,O}
    router::R
    otn::T
    oxc::O
    transmodulespool::Vector{Transponder}
end

struct RouterView{R}
    router::R
    "lists which ports are available"
    portavailability::Vector{Bool}
    "lists which intents are reserved the resources"
    reservations::Vector{Union{Missing,Tuple{Int, Int, UUID}}}
end
RouterView(rt) = RouterView(rt, fill(true, rt.nports), Vector{Union{Missing,Tuple{Int,Int,UUID}}}(fill(missing, rt.nports)))

struct OTNView end
struct OXCView end

mutable struct FiberView{F}
    fiber::F
    operates::Bool
    logstate::LogState{Bool}
    "True if available"
    spectrum_src::Vector{Bool}
    "lists which intents are reserved the resources"
    reservations_src::Vector{Union{Missing,Tuple{Int, Int, UUID}}}

    spectrum_dst::Vector{Bool}
    reservations_dst::Vector{Union{Missing,Tuple{Int, Int, UUID}}}
end
FiberView(fiber; frequency_slots=320) = FiberView(fiber, true, LogState{Bool}(),fill(true, frequency_slots), Vector{Union{Missing,Tuple{Int,Int,UUID}}}(fill(missing, frequency_slots)), fill(true, frequency_slots), Vector{Union{Missing,Tuple{Int,Int,UUID}}}(fill(missing, frequency_slots)))

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

"""
1 is OXC bypass, 2 is regeneration (back2back transponders), 3 is grooming (OTN switch), 4 is router
3 and 4 could be the same if no OTN switch
2 and 3 and 4 could be the same if only pluggables
1 and 2 and 3 and 4 could be the same if no OXC
"""
@enum DataLayer oxcLayer regenLayer groomLayer routerLayer
