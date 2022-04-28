abstract type Intent end
abstract type LowLevelIntent <: Intent end
getnode(lli::LowLevelIntent) = lli.node
abstract type IntentConstraint end
abstract type IntentCondition end

@enum IntentState installed installing installfailed uninstalled compiled compiling uncompiled
@enum IntentTransition doinstall douninstall docompile douncompile

"""
- intent: The intent
- state: The intent state
"""
mutable struct IntentDAGNode{T<:Intent}
    intent::T
    state::IntentState
    id::UUID
end
getstate(idagn::IntentDAGNode) = idagn.state
getintent(idagn::IntentDAGNode) = idagn.intent
getid(idagn::IntentDAGNode) = idagn.id
"""
idx: The intent index in the IBN
intentcounter: The intent UUID index to be assigned next in the IntentDAG
"""
mutable struct IntentDAGInfo
    idx::Int
    intentcounter::Int
end
IntentDAGInfo(idx::Int) = IntentDAGInfo(idx, 1)
const IntentDAG = typeof(MG(SimpleDiGraph(); Label=UUID, VertexData=IntentDAGNode, graph_data=IntentDAGInfo(0)))
function IntentDAG(idx::Int, intent::Intent)
    mg = MG(SimpleDiGraph(); Label=UUID, VertexData=IntentDAGNode, graph_data=IntentDAGInfo(idx))
    addchild!(mg, intent)
    return mg
end

#traits for Intent
subjects(i::Intent) = error("not implemented")
priority(i::Intent) = error("not implemented")
actions(i::Intent) = error("not implemented")
getconstraints(i::Intent) = i.constraints
getconditions(i::Intent) = i.conditions

mutable struct RemoteIntent <: Intent
    "remote IBN"
    ibnid::Int
    "Intent index in the remote IBN"
    intentidx::Union{Int, Missing}
end
Base.show(io::IO, ric::RemoteIntent) = print(io,"RemoteIntent(ibnid=$(ric.ibnid)), idx = $(ric.intentidx)))")
dagtext(ci::RemoteIntent) = "RemoteIntent($(ci.ibnid), $(ci.intentidx))"
Base.:(==)(rm1::RemoteIntent, rm2::RemoteIntent) = (rm1.ibnid == rm2.ibnid) && (rm1.intentidx == rm2.intentidx)

"""
Intent for connecting 2 nodes

    $(TYPEDFIELDS)
"""
struct ConnectivityIntent{C,R} <: Intent 
    "Source node as (IBN.id, node-id)"
    src::Tuple{Int, Int}
    "Destination node as (IBN.id, node-id)"
    dst::Tuple{Int, Int}
    #TODO constrs is array of abstract, so not performant (Union Splitting, or Tuple in the future ?)
    "Intents constraints"
    constraints::C
    "Intents conditions"
    conditions::R
    ConnectivityIntent(src::Tuple{Int,Int},dst::Tuple{Int, Int}, constraints::C, conditions::R=missing) where {C,R} =
        new{C,R}(src, dst, constraints, conditions)
end
getsrc(i::Intent) = i.src
getdst(i::Intent) = i.dst
getsrcdom(i::Intent) = i.src[1]
getsrcdomnode(i::Intent) = i.src[2]
getdstdom(i::Intent) = i.dst[1]
getdstdomnode(i::Intent) = i.dst[2]
dagtext(ci::ConnectivityIntent) = "ConnectivityIntent($(ci.src), $(ci.dst), $(ci.constraints), $(ci.conditions))"
ConnectivityIntent(ce::CompositeEdge, args...) = ConnectivityIntent(ce.src, ce.dst, args...)

struct EdgeIntent{C,R} <: Intent
    constraints::C
    conditions::R
end
EdgeIntent(constraints) = EdgeIntent(constraints, missing)
dagtext(ci::EdgeIntent) = "EdgeIntent($(ci.constraints), $(ci.conditions))"

struct PathIntent{C} <: Intent
    "Flow path"
    path::Vector{Int}
    constraints::C
end
dagtext(ci::PathIntent) = "PathIntent($(ci.path), $(ci.constraints))"

"Termination points for the optical circuits. If middle of vector is termination and instantiation"
struct SpectrumIntent{C} <: Intent
    "Flow path"
    lightpath::Vector{Int}
    drate::Float64
    spectrumalloc::UnitRange{Int}
    constraints::C
end
dagtext(ci::SpectrumIntent) = "SpectrumIntent($(ci.lightpath), $(ci.drate), $(ci.spectrumalloc), $(ci.constraints))"

struct RegenerationIntent{C} <: Intent
    constraints::C
end

struct GroomingIntent{C} <: Intent
    termlayer::DataLayer
    constraints::C
end

#    transponders::T
#transponders configuration
#OTN ports
#OTN configuration
#OXC ports?
#OXC bypass
# TODO delete ports. NodeRouterIntent can only occupy 1 port
"R can be Int for local view or Tuple{Int, Int} for gloval view"
struct NodeRouterIntent{R} <: LowLevelIntent
    node::R
    ports::Int
end
NodeRouterIntent(nd) = NodeRouterIntent(nd, 1)
dagtext(ci::NodeRouterIntent) = "NodeRouterIntent\nnode=$(ci.node)\nports=$(ci.ports)"

"""
R can be Int for local view or Tuple{Int, Int} for gloval view
T can be Edge for local view or CompositeEdge for gloval view
""" 
struct NodeSpectrumIntent{R,T} <: LowLevelIntent
    node::R
    edge::T
    slots::UnitRange{Int}
    bandwidth::Float64
end
dagtext(ci::NodeSpectrumIntent) = "NodeSpectrumIntent\nnode=$(ci.node)\nedge=$(ci.edge)\nslots=$(ci.slots)\nbandwidth=$(ci.bandwidth)"

"""
Intent for connecting 2 IBNs

    $(TYPEDFIELDS)
"""
struct DomainConnectivityIntent{R,T,C,D} <: Intent 
    "Source node as (IBN.id, node-id)"
    src::R
    "Destination node as (IBN.id, node-id)"
    dst::T
    #TODO constrs is array of abstract, so not performant (Union Splitting, or Tuple in the future ?)
    "Intents constraints"
    constraints::C
    "Intents conditions"
    conditions::D
end
dagtext(ci::DomainConnectivityIntent) = "DomainConnectivityIntent($(ci.src), $(ci.dst), $(ci.constraints), $(ci.conditions))"
DomainConnectivityIntent(ce::CompositeEdge, args...) = DomainConnectivityIntent(ce.src, ce.dst, args...)
getsrcdom(i::DomainConnectivityIntent{Int, Tuple{Int,Int}}) = i.src
getsrcdomnode(i::DomainConnectivityIntent{Int, Tuple{Int,Int}}) = error("$(typeof(i)) does not have a particular source node")
getdstdom(i::DomainConnectivityIntent{Tuple{Int,Int}, Int}) = i.dst
getdstdomnode(i::DomainConnectivityIntent{Tuple{Int,Int}, Int}) = error("$(typeof(i)) does not have a particular destination node")

struct CapacityConstraint <: IntentConstraint
    #TODO intergrate with Unitful once PR is pushed
    "In Gppbs"
    drate::Float64
    #todo use Unitful
end

struct DelayConstraint <: IntentConstraint
    "Delay in milliseconds"
    delay::typeof(1.0u"ms")
end

struct GoThroughConstraint{R} <: IntentConstraint
    node::Tuple{Int,Int}
    layer::SignalLoc
    req::R
end
GoThroughConstraint(nd,l) = GoThroughConstraint(nd, l, missing)
