"""
$(TYPEDEF)

A concrete subtype of `AbstractIntent` must implement the following methods: 
- [`is_low_level_intent`](@ref)
"""
abstract type AbstractIntent end

"""
All possible intent states
"""
@enumx IntentState begin
    Uncompiled
    Compiled
    Installed
end

"""
$(TYPEDEF)

$(TYPEDFIELDS)

Stores a vector of the history of the intent states and their timings
"""
struct IntentLogState
    logstate::Vector{Tuple{Float64, IntentState.T}}
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
    dagnodeid::UUID
end


"""
$(TYPEDEF)

$(TYPEDFIELDS)
"""
mutable struct IntentDAGNode{I <: AbstractIntent, II <: IntentIssuer}
    """The mutable state of the intent node"""
    state::IntentState.T
    "The intent itself"
    const intent::I
    """The id of the intent w.r.t. the intent DAG it belongs"""
    const dagnodeid::UUID
    """The intent issuer"""
    const intentissuer::II
    """The history of states of the intent"""
    const logstate::IntentLogState
end

mutable struct IntentDAGInfo
    intentcounter::Int
end

const IntentDAG = AttributeGraph{Int, SimpleDiGraph{Int}, Vector{IntentDAGNode}, Missing, IntentDAGInfo}

"""
$(TYPEDFIELDS)
"""
struct ConnectivityIntent <: AbstractIntent
    "Source node"
    sourcenode::GlobalNode
    "Destination node"
    destinationnode::GlobalNode
    "Bandwidth request value (Gbps)"
    rate::Float64
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
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct IBNFramework{S<:AbstractSDNController}
    "The id of this IBN Framework instance"
    ibnfid::UUID
    "The intent dag tree that contains all intents (can be disconnected graph)"
    intentdag::IntentDAG
    "Single-domain internal graph with border nodes included"
    ibnag::IBNAttributeGraph
    "Other IBN Frameworks handles"
    interIBNFs::Vector{IBNFrameworkHandler}
    "SDN controller handle"
    sdncontroller::S
end
