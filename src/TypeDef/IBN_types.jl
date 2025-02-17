"""
$(TYPEDEF)
All possible default intent states.
Another intent state schema could be defined.
"""
@enumx IntentState begin
    Uncompiled
    Compiling
    Compiled
    Installing
    Installed
end

"Instances of this specify how to compile the intent"
abstract type IntentCompilationAlgorithm end

"""
Stores a vector of the history of the intent states and their timings
"""
const IntentLogState{S <: Enum{Int32}} = Vector{Tuple{DateTime, S}}

"""
$(TYPEDSIGNATURES)
"""
function IntentLogState(intentstate::IntentState.T = IntentState.Uncompiled)
    return [(now(), intentstate)]    
end

"""
Characterizes the entity issuing an intent
"""
abstract type IntentIssuer end

"""
Intent issued directly by the network operator, i.e., a user intent
"""
struct NetworkOperator <: IntentIssuer end

"""
Intent is generated automatically by the IBN Framework
"""
struct MachineGenerated <: IntentIssuer end

"""
$(TYPEDEF)

Intent is issued by an IBN Framework domain

$(TYPEDFIELDS)
"""
struct IBNIssuer <: IntentIssuer
    "the id of the `IBNF` issued the intent"
    ibnfid::UUID
    "The id of the intent node in the DAG. The issuer of this intent node points back in this `IBNIssuer` instance."
    idagnodeid::UUID
end


"""
$(TYPEDEF)

$(TYPEDFIELDS)
"""
struct IntentDAGNode{I <: AbstractIntent, II <: IntentIssuer}
    "The intent itself"
    intent::I
    """The id of the intent w.r.t. the intent DAG it belongs"""
    idagnodeid::UUID
    """The intent issuer"""
    intentissuer::II
    """The history of states of the intent with the last being the current state"""
    logstate::IntentLogState{IntentState.T}
end

mutable struct IntentDAGInfo
    intentcounter::Int
end

"""
$(TYPEDSIGNATURES)

Empty constructor 
"""
function IntentDAGInfo()
    return IntentDAGInfo(0)
end

const IntentDAG = AttributeGraph{Int, SimpleDiGraph{Int}, Vector{IntentDAGNode}, Nothing, IntentDAGInfo}

"""
$(TYPEDFIELDS)
"""
struct ConnectivityIntent <: AbstractIntent
    "Source node"
    sourcenode::GlobalNode
    "Destination node"
    destinationnode::GlobalNode
    "Bandwidth request value (Gbps)"
    rate::GBPSf
end

"""
$(TYPEDSIGNATURES)
"""
function is_low_level_intent(ci::ConnectivityIntent)
    return false
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

The interface the IBN Frameworks talk to each other
"""
struct IBNFrameworkHandler
    "The id of the IBN Framework"
    ibnfid::UUID
end

"""
    The graph of the IBN Framework is expressed with this `AttributeGraph`.
    Border nodes are assumed to be visible from both sides.
    However only the official owner can issue an intent.
"""
const IBNAttributeGraph{T} = AttributeGraph{Int, SimpleDiGraph{Int}, Vector{T}, Dict{Edge{LocalNode}, EdgeView}, UUID} where {T <: NodeView}

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct IBNFramework{S <: AbstractSDNController, T <: IBNAttributeGraph}
    "The id of this IBN Framework instance"
    ibnfid::UUID
    "The intent dag tree that contains all intents (can be disconnected graph)"
    intentdag::IntentDAG
    "Single-domain internal graph with border nodes included"
    ibnag::T
    "Other IBN Frameworks handles"
    interIBNFs::Vector{IBNFrameworkHandler}
    "SDN controller handle"
    sdncontroller::S
end

"""
$(TYPEDSIGNATURES) 
"""
function IBNFramework(ibnag::T) where {T <: IBNAttributeGraph}
    ibnfid = AG.graph_attr(ibnag)
    return IBNFramework(ibnfid, IntentDAG(), ibnag, IBNFrameworkHandler[], SDNdummy())
end

"""
$(TYPEDSIGNATURES)
"""
function Base.show(io::IO, ibnf::I) where {I <: IBNFramework}
    print(io, I, "(", getibnfid(ibnf))
    print(io, ", IntentDAG(", nv(getidag(ibnf)), ", ", ne(getidag(ibnf)), ")")
    print(io, ", IBNAttributeGraph(", nv(getibnag(ibnf)), ", ", ne(getibnag(ibnf)), ")")
    print(io, ", ", getibnfid.(getinteribnfs(ibnf)))
    return print(io, ", ", typeof(getsdncontroller(ibnf)))
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Expresses an intent for a lightpath.
Compilation should yield: 
- source and destination port indices
- transmissionmodule selection
"""
struct LightpathIntent <: AbstractIntent
    path::Vector{LocalNode}
end
