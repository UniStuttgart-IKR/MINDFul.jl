"""
High level view of a resource that connects either to simulated equipment or an SDN controller
"""
abstract type ResourceView end

const LocalNode = Int

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
    "The number of router ports"
    ports::Int
end

"""
$(TYPEDEF)

$(TYPEDFIELDS)

The view of the current node settings
"""
struct NodeView <: ResourceView
    "The [`NodeProperties`](@ref)"
    nodeproperties::NodeProperties
    "A vector showing the availability of a port. `true` for available and `false` for reserved"
    portavailability::Vector{Bool}
end

function NodeView(nodeproperties::NodeProperties) 
    return NodeView(nodeproperties, fill(true, getports(nodeproperties)))
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
struct EdgeView <: ResourceView
    "The [`EdgeProperties`](@ref)"
    edgeproperties::EdgeProperties
    "A vector showing the availability of the spectrum slots. `true` for available and `false` for reserved"
    spectrumavailability::Vector{Bool}
end

function EdgeView(edgeproperties::EdgeProperties) 
    return EdgeView(edgeproperties, fill(true, getspectrumslots(edgeproperties)))
end

const IBNAttributeGraph = AttributeGraph{Int, SimpleDiGraph{Int}, Vector{NodeView}, Dict{Pair{LocalNode, LocalNode}, EdgeView}, Missing}

function IBNAttributeGraph(ag::AttributeGraph{Int, SimpleDiGraph{Int}, Vector{Dict{Symbol, T}}, Dict{Edge{Int}, Dict{Symbol, R}}, Missing}) where {T<:Any ,R <: Any}
    nodedicts = vertex_attr(ag)
    nodeviews = NodeView.(constructfromdict.(NodeProperties, nodedicts))

    edgedicts = edge_attr(ag)
    edgeviews = Dict((src(k) => dst(k)) => EdgeView(constructfromdict(EdgeProperties, v)) for (k,v) in edgedicts)

    return IBNAttributeGraph(AG.getgraph(ag), nodeviews, edgeviews, missing)
end

