abstract type Intent end
abstract type LowLevelIntent <: Intent end
getnode(lli::LowLevelIntent) = lli.node
abstract type IntentConstraint end
"still not used"
abstract type IntentCondition end

@enum IntentState installed installing installfailed uninstalled compiled compiling uncompiled failure
@enum IntentTransition doinstall douninstall docompile douncompile

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
mutable struct IntentDAGNode{T<:Intent, L<:LogState}
    intent::T
    state::IntentState
    id::UUID
    logstate::L
end
IntentDAGNode(kw...) = IntentDAGNode(kw..., LogState{IntentState}())
getstate(idagn::IntentDAGNode) = idagn.state
getintent(idagn::IntentDAGNode) = idagn.intent
getid(idagn::IntentDAGNode) = idagn.id

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
mutable struct IntentDAGInfo
    "The intent UUID index to be assigned next in the IntentDAG"
    intentcounter::Int
end
IntentDAGInfo() = IntentDAGInfo(1)
const IntentDAG = typeof(MG(SimpleDiGraph(); Label=UUID, VertexData=IntentDAGNode, graph_data=IntentDAGInfo()))
getid(dag::IntentDAG) = dag.graph_data.id

function IntentDAG(id::Int, intent::Intent)
    mg = MG(SimpleDiGraph(); Label=UUID, VertexData=IntentDAGNode, graph_data=IntentDAGInfo(id))
    addchild!(mg, intent)
    return mg
end

subjects(i::Intent) = error("not implemented")
priority(i::Intent) = error("not implemented")
actions(i::Intent) = error("not implemented")
getconstraints(i::Intent) = i.constraints
getconditions(i::Intent) = i.conditions

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
mutable struct RemoteIntent <: Intent
    "remote IBN"
    ibnid::Int
    "Intent index in the remote IBN"
    intentidx::Union{Int,Missing}
end
#Base.show(io::IO, ric::RemoteIntent) = print(io,"RemoteIntent(ibnid=$(ric.ibnid)), idx = $(ric.intentidx)))")
dagtext(ci::RemoteIntent) = "RemoteIntent($(ci.ibnid), $(ci.intentidx))"
Base.:(==)(rm1::RemoteIntent, rm2::RemoteIntent) = (rm1.ibnid == rm2.ibnid) && (rm1.intentidx == rm2.intentidx)

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Intent for connecting 2 nodes
"""
struct ConnectivityIntent{C,R} <: Intent
    "Source node as (IBN.id, node-id)"
    src::Tuple{Int,Int}
    "Destination node as (IBN.id, node-id)"
    dst::Tuple{Int,Int}
    #TODO constrs is array of abstract, so not performant (Union Splitting, or Tuple in the future ?)
    "Intents constraints"
    constraints::C
    "Intents conditions"
    conditions::R
    ConnectivityIntent(src::Tuple{Int,Int}, dst::Tuple{Int,Int}, constraints::C, conditions::R=missing) where {C,R} =
        new{C,R}(src, dst, constraints, conditions)
end
getsrc(i::Intent) = i.src
getdst(i::Intent) = i.dst
getsrcdom(i::Intent) = i.src[1]
getsrcdomnode(i::Intent) = i.src[2]
getdstdom(i::Intent) = i.dst[1]
getdstdomnode(i::Intent) = i.dst[2]
dagtext(ci::ConnectivityIntent) = "ConnectivityIntent($(ci.src), $(ci.dst), $(ci.constraints), $(ci.conditions))"
ConnectivityIntent(ce::NestedEdge, args...) = ConnectivityIntent(ce.src, ce.dst, args...)

struct EdgeIntent{C,R} <: Intent
    constraints::C
    conditions::R
end
EdgeIntent(constraints) = EdgeIntent(constraints, missing)
dagtext(ci::EdgeIntent) = "EdgeIntent($(ci.constraints), $(ci.conditions))"

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct PathIntent{C} <: Intent
    "Flow path"
    path::Vector{Int}
    constraints::C
end
getpath(pin::PathIntent) = pin.path
dagtext(ci::PathIntent) = "PathIntent($(ci.path), $(ci.constraints))"

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct LightpathIntent{T,C} <: Intent
    "Flow path"
    path::Vector{Int}
    transmodl::T
    constraints::C
end
getpath(lpi::LightpathIntent) = lpi.path
gettransmodl(lpi::LightpathIntent) = lpi.transmodl
dagtext(ci::LightpathIntent) = "LightpathIntent\npath=$(ci.path)"


"""
$(TYPEDEF)
$(TYPEDFIELDS)
Termination points for the optical circuits. If middle of vector is termination and instantiation
"""
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
"""
$(TYPEDEF)
$(TYPEDFIELDS)
`R` can be `Int` for local view or `Tuple{Int, Int}` for gloval view
"""
struct NodeRouterPortIntent{R} <: LowLevelIntent
    node::R
    rate::Float64
end
NodeRouterPortIntent(nd) = NodeRouterPortIntent(nd, 100.0)
dagtext(ci::NodeRouterPortIntent) = "NodeRouterPortIntent\nnode=$(ci.node)\nrate=$(ci.rate)"

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct NodeTransmoduleIntent{R,T<:TransmissionModuleView} <: LowLevelIntent
    "which node this low-level intent targets"
    node::R
    "the transmission module that must be allocated (or similar for dissagregated networks)"
    tm::T
end
dagtext(ci::NodeTransmoduleIntent) = "NodeTransmoduleIntent\nnode=$(ci.node)\ntransmodl=$(ci.tm)"

"""
$(TYPEDEF)
$(TYPEDFIELDS)
`R` can be Int for local view or `Tuple{Int, Int}` for gloval view
`T` can be Edge for local view or `NestedEdge` for gloval view
"""
struct NodeSpectrumIntent{R,T} <: LowLevelIntent
    node::R
    edge::T
    slots::UnitRange{Int}
    bandwidth::Float64
end
dagtext(ci::NodeSpectrumIntent) = "NodeSpectrumIntent\nnode=$(ci.node)\nedge=$(ci.edge)\nslots=$(ci.slots)\nbandwidth=$(ci.bandwidth)"

struct RemoteLogicIntent{T} <: LowLevelIntent
    intent::T
    ri::RemoteIntent
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
Intent for connecting 2 IBNs
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
DomainConnectivityIntent(ce::NestedEdge, args...) = DomainConnectivityIntent(ce.src, ce.dst, args...)
getsrcdom(i::DomainConnectivityIntent{Int,Tuple{Int,Int}}) = i.src
getsrcdomnode(i::DomainConnectivityIntent{Int,Tuple{Int,Int}}) = error("$(typeof(i)) does not have a particular source node")
getdstdom(i::DomainConnectivityIntent{Tuple{Int,Int},Int}) = i.dst
getdstdomnode(i::DomainConnectivityIntent{Tuple{Int,Int},Int}) = error("$(typeof(i)) does not have a particular destination node")

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

struct AvailabilityConstraint <: IntentConstraint end

struct GoThroughConstraint{R} <: IntentConstraint
    node::Tuple{Int,Int}
    layer::SignalLoc
    req::R
end
GoThroughConstraint(nd, l) = GoThroughConstraint(nd, l, missing)
GoThroughConstraint(nd) = GoThroughConstraint(nd, signalUknown, missing)

struct CompiledConnectivityIntent{T,R}
    path::Vector{Tuple{Int,Int}}
    spectrum::Vector{UnitRange{Int}}
    electrical_path::Vector{Tuple{Int,Int}}
    remote_intents::T
    remote_intents_uuid::R
end
