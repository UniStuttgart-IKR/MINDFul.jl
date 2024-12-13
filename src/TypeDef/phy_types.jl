const LocalNode = Int

abstract type AbstractRouter end
struct RouterDummy <: AbstractRouter end

abstract type AbstractOXC end
struct OXCDummy <: AbstractOXC end

abstract type AbstractTransmissionModule end
struct TransmissionModuleDummy <: AbstractTransmissionModule end

"""
The following functions should be implemented for subtypes:
- `getreservations(subtype::ReservableResourceView)::Dict{UUID, T}`
- `canreserve(subtype::ReservableResourceView, reservation::T)::Bool`
The following default functions exist that should already work
- `reserve!(subtype::ReservableResourceView, dagnodeid::UUID, reservation::T; checkfirst::Bool=true)::Bool`
- `unreserve!(subtype::ReservableResourceView, dagnodeid::UUID)::Bool`
- `insertreservation!(subtype::ReservableResourceView, dagnodeid::UUID, reservation::T)`
- `deletereservation!(subtype::ReservableResourceView, dagnodeid::UUID)`
"""
abstract type ReservableResourceView end

"""
$(TYPEDEF)

A view of a router with several ports.

$(TYPEDFIELDS)
"""
struct RouterView{R <: AbstractRouter} <: ReservableResourceView
    "The underlying router"
    router::R
    "number of ports in router"
    portnumber::Int
    "The intent reservations together with the reserved port index"
    portreservations::Dict{UUID, Int}
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

A value-based interpretation of (`input`, `adddrop`, `output`).
At least one of the 3 elements must be `0`.
`(x, 0, y)` means optical bypass from the localnode `x` to the localnode `y`
`(0, x, y)` means adding an optical signal from add port `x` going to the localnode `y`
`(x, y, 0)` means droping an optical signal from  the localnode `x` to the drop port `y`
`(0, x, 0)` mean that an add/drop allocation port is only reserved (is needed on top for an add/drop signal)
"""
struct OXCSwitchEntry
    "The node in graph entering the OXC (or `0` if invalid)"
    localnode_input::LocalNode
    "The port index adding or dropping an optical signal (or `0` if invalid)"
    port_adddrop::Int
    "The node in graph exiting the OXC (or `0` if invalid)"
    localnode_output::LocalNode
    "The spectrum range allocated"
    spectrumslotsrange::UnitRange{Int}
end


"""
$(TYPEDEF)

A view of a OXC .
It just has one switch.
But logically we split it up to bypass, drop and add switch.
The add/drop IO are not modeled.

$(TYPEDFIELDS)
"""
struct OXCView{O<:AbstractOXC} <:  ReservableResourceView
    "the underlying OXC"
    oxc::O
    "The number of add/drop ports in OXC"
    adddropportnumber::Int
    "The intent reservations together with the configuration"
    switchreservations::Dict{UUID, OXCSwitchEntry}
    # TODO: think it could be a Dictionary
end



"""
$(TYPEDEF)

Represents a transmission mode.
A transponder, if flexible, might support many of them.

$(TYPEDFIELDS)
"""
struct TransmissionMode
    "Optical reach in kilometers"
    opticalreach::Float64
    "rate in Gbps"
    rate::Float64
    "Number of 12.5 GHz frequency slots needed"
    spectrumslotsneeded::Int
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

A view of a transmission module.
"""
struct TransmissionModuleView{T <: AbstractTransmissionModule}
    "The underlying transmission module"
    transmissionmodule::T
    "descriptive name of the transmission module"
    name::String
    "operating transmission modes"
    transmissionmodes::Vector{TransmissionMode}
    "Cost of the transmission module (in unit costs)"
    cost::Float64
end


"""
$(TYPEDEF)

$(TYPEDFIELDS)
"""
struct GlobalNode
    "IBN Framework id"
    ibnfid::UUID
    "Node number"
    node::LocalNode
end


"""
$(TYPEDEF)

$(TYPEDFIELDS)

An immutable description of the node properties
"""
struct NodeProperties
    "The id of the IBN framework this node belongs"
    ibnfid::UUID
    latitude::Float64
    longtitude::Float64
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct TransmissionModuleReservationEntry
    "The index of the transmission module pool to be reserved"
    transmissionmoduleviewpoolindex::Int
    "The selected mode of the transmission module. `0` means nothing is still selected. Non elastic modules can have only `1`."
    transmissionmodesindex::Int
    "The router port index to be reserved"
    routerportindex::Int
    "The oxc add/drop port index to be reserved"
    oxcadddropportindex::Int
end

"""
$(TYPEDEF)

$(TYPEDFIELDS)

The view of the current node settings
"""
struct NodeView{R<:RouterView, O<:OXCView, T<:TransmissionModuleView} <: ReservableResourceView
    "The [`NodeProperties`](@ref)"
    nodeproperties::NodeProperties
    "The router in use"
    routerview::R
    "The OXC in use"
    oxcview::O
    "The transmission modules contained"
    transmissionmoduleviewpool::Vector{T}
    """
    intent reservation of the transmission modules
    """
    transmissionmodulereservations::Dict{UUID, TransmissionModuleReservationEntry}
end

function Base.show(io::IO, nv::NodeView)
    print(io, "NodeView(")
    print(io, nv.nodeproperties, ", ")
    print(io, nv.routerview, ", ")
    print(io, nv.oxcview, ", ")
    print(io, length(nv.transmissionmoduleviewpool), " transmission modules, " )
    print(io, length(nv.transmissionmodulereservations), " reservations" )
end

function NodeView(nodeproperties::NodeProperties, routerview::R, oxcview::O, transmissionmoduleviewpool::Vector{T})  where {R<:RouterView, O<:OXCView, T<:TransmissionModuleView}
    return NodeView(nodeproperties, routerview, oxcview, transmissionmoduleviewpool, Dict{UUID, TransmissionModuleReservationEntry}())
end

"""
$(TYPEDEF)

$(TYPEDFIELDS)

An immutable description of the edge properties
"""
struct EdgeProperties
    "The overall spectrum slot number (assumed 12.5GHz)"
    spectrumslots::Int
    "The distance of the edge (assumed km)"
    distance::Float64
end

"""
$(TYPEDEF)

$(TYPEDFIELDS)

The view of the current edge settings
"""
struct EdgeView
    "The [`EdgeProperties`](@ref)"
    edgeproperties::EdgeProperties
    "A vector showing the availability of the spectrum slots. `true` for available and `false` for reserved"
    spectrumavailability::Vector{Bool}
end

"""
$(TYPEDSIGNATURES)
"""
function EdgeView(edgeproperties::EdgeProperties) 
    return EdgeView(edgeproperties, fill(true, getspectrumslots(edgeproperties)))
end

const IBNAttributeGraph = AttributeGraph{Int, SimpleDiGraph{Int}, Vector{NodeView}, Dict{Edge{LocalNode}, EdgeView}, Missing}

"""
$(TYPEDSIGNATURES)
"""
function IBNAttributeGraph(ag::AttributeGraph{Int, SimpleDiGraph{Int}, Vector{Dict{Symbol, T}}, Dict{Edge{Int}, Dict{Symbol, R}}, Missing}) where {T<:Any ,R <: Any}
    nodeviews = NodeView.(constructfromdict.(NodeProperties, vertex_attr(ag)))
    edgeviews = Dict(k => EdgeView(constructfromdict(EdgeProperties, v)) for (k,v) in edge_attr(ag))
    return IBNAttributeGraph(AG.getgraph(ag), nodeviews, edgeviews, missing)
end

