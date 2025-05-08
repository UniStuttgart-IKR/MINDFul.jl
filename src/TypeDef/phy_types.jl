# low level intents are needed for the device reservations

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct TransmissionModuleLLI <: LowLevelIntent
    "Target node"
    localnode::LocalNode
    "The index of the transmission module pool to be reserved"
    transmissionmoduleviewpoolindex::Int
    "The selected mode of the transmission module. `0` means nothing is still selected. Non elastic modules can have only `1`."
    transmissionmodesindex::Int
    "The router port index to be connected"
    routerportindex::Int
    "The port index adding or dropping the optical signal to be connected"
    adddropport::Int
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct RouterPortLLI <: LowLevelIntent
    "Target node"
    localnode::LocalNode
    "The router port index to be reserved"
    routerportindex::Int
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
struct OXCAddDropBypassSpectrumLLI <: LowLevelIntent
    "Target node"
    localnode::LocalNode
    "The node in graph entering the OXC (or `0` if invalid)"
    localnode_input::LocalNode
    "The port index adding or dropping an optical signal (or `0` if invalid)"
    adddropport::Int
    "The node in graph exiting the OXC (or `0` if invalid)"
    localnode_output::LocalNode
    "The spectrum range allocated 1-based indexed"
    spectrumslotsrange::UnitRange{Int}
end

# starting equipment
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
    "The intent reservations together with the low level intent of reserved port"
    portreservations::Dict{UUID, RouterPortLLI}
end


"""
$(TYPEDEF)
$(TYPEDFIELDS)

A view of a OXC.
This OXC view is also a view to the links connecting to the OXC.
Since links are not devices under control, MINDFul does not model them directly.
"""
struct OXCView{O <: AbstractOXC} <: ReservableResourceView
    "the underlying OXC"
    oxc::O
    "The number of add/drop ports in OXC"
    adddropportnumber::Int
    "The intent reservations together with the configuration"
    switchreservations::Dict{UUID, OXCAddDropBypassSpectrumLLI}
    """
    Link spectrum availability total view in sync with `switchreservations`.
    A vector showing the availability of the spectrum slots. `true` for available and `false` for reserved.
    The vector views should be the same with the ones on the opposite OXC view.
    """
    linkspectrumavailabilities::Dict{Edge{Int}, Vector{Bool}}
    """
    History information of the status of the connected links (working or not).
    The last element is the current state.
    """
    linkstates::Dict{Edge{Int}, BoolLogState}
end

"""
$(TYPEDEF)

Represents a transmission mode.
A transponder, if flexible, might support many of them.

$(TYPEDFIELDS)
"""
struct TransmissionMode
    "Optical reach in kilometers"
    opticalreach::KMf
    "rate in Gbps"
    rate::GBPSf
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

Describe what requirements are needed to establish transmission module end-to-end connection
Modulation should be here but it's not.
Dissagregetation data should be here but it's not.
Both are covered by the `name` which must be equal in both ends
"""
struct TransmissionModuleCompatibility
    "The bandwidth of the connection"
    rate::GBPSf
    "Number of 12.5Gz frequency slots needed"
    spectrumslotsneeded::Int
    "descriptive name of the transmission module"
    name::String
end


"""
$(TYPEDEF)
$(TYPEDFIELDS)

An immutable description of the node properties
"""
struct NodeProperties
    localnode::LocalNode
    globalnode::GlobalNode
    latitude::Float64
    longitude::Float64
    "The list of neighbohrs coming in"
    inneighbors::Vector{LocalNode}
    "The list of neighbohrs going out"
    outneighbors::Vector{LocalNode}
end

function constructfromdict(_::Type{NodeProperties}, dict::Dict{Symbol}, dict2::Dict{Symbol})
    extendedfields = [:localnode, :globalnode_node, :globalnode_ibnfid, :Latitude, :Longitude, :inneighbors, :outneighbors]
    return NodeProperties(
        [
            haskey(dict, fn) ? dict[fn] : dict2[fn]
                for fn in extendedfields
        ]...
    )
end

function NodeProperties(localnode, globalnode_node, globalnode_ibnfid, latitude, longitude, inneighbors, outneighbors)
    globalnode = GlobalNode(UUID(globalnode_ibnfid), globalnode_node)
    return NodeProperties(localnode, globalnode, latitude, longitude, inneighbors, outneighbors)
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

The view of the current node settings
Reservables resources reservations are `nothing` if it represents a border node.
"""
struct NodeView{R <: RouterView, O <: OXCView, T <: TransmissionModuleView} <: ReservableResourceView
    "The [`NodeProperties`](@ref)"
    nodeproperties::NodeProperties
    "The router in use"
    routerview::Union{Nothing, R}
    "The OXC in use"
    oxcview::Union{Nothing, O}
    "The transmission modules contained"
    transmissionmoduleviewpool::Union{Nothing, Vector{T}}
    """
    intent reservation of the transmission modules
    """
    transmissionmodulereservations::Union{Nothing, Dict{UUID, TransmissionModuleLLI}}
end

function Base.show(io::IO, nv::NodeView)
    print(io, "NodeView(")
    print(io, nv.nodeproperties, ", ")
    if !isnodeviewinternal(nv)
        print(io, "remote-node)")
    else
        print(io, nv.routerview, ", ")
        print(io, nv.oxcview, ", ")
        print(io, length(nv.transmissionmoduleviewpool), " transmission modules, ")
        print(io, length(nv.transmissionmodulereservations), " reservations")
        print(io, ")")
    end
    return nothing
end

function NodeView(nodeproperties::NodeProperties, routerview::R, oxcview::O, transmissionmoduleviewpool::Vector{T}) where {R <: RouterView, O <: OXCView, T <: TransmissionModuleView}
    return NodeView(nodeproperties, routerview, oxcview, transmissionmoduleviewpool, Dict{UUID, TransmissionModuleLLI}())
end

"""
$(TYPEDEF)

$(TYPEDFIELDS)

An immutable description of the edge properties
"""
struct EdgeProperties
    "The distance of the edge (assumed km)"
    distance::KMf
end

function constructfromdict(_::Type{EdgeProperties}, dict::Dict{Symbol})
    return EdgeProperties(KMf(dict[:distance]))
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

The view of the current edge settings
"""
struct EdgeView
    "The [`EdgeProperties`](@ref)"
    edgeproperties::EdgeProperties
end
