"""
$(TYPEDEF)
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
$(TYPEDSIGNATURES)
"""
function IntentLogState()
    return Vector{Tuple{Float64, IntentState.T}}()
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
struct IntentDAGNode{I <: AbstractIntent, II <: IntentIssuer}
    "The intent itself"
    intent::I
    """The id of the intent w.r.t. the intent DAG it belongs"""
    dagnodeid::UUID
    """The intent issuer"""
    intentissuer::II
    """The history of states of the intent with the last being the current state"""
    logstate::IntentLogState
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

const IBNAttributeGraph = AttributeGraph{Int, SimpleDiGraph{Int}, Vector{NodeView}, Dict{Edge{LocalNode}, EdgeView}, UUID}

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

"""
$(TYPEDSIGNATURES) 
"""
function IBNFramework(ibnag::IBNAttributeGraph)
    ibnfid = AG.graph_attr(ibnag)
    return IBNFramework(ibnfid, IntentDAG(), ibnag, IBNFrameworkHandler[], SDNdummy())
end

"""
$(TYPEDSIGNATURES)
"""
function Base.show(io::IO, ibnf::I) where {I<:IBNFramework}
        print(io, I, "(", getibnfid(ibnf))
        print(io, ", IntentDAG(", nv(getintentdag(ibnf)), ", ", ne(getintentdag(ibnf)), ")")
        print(io, ", IBNAttributeGraph(", nv(getibnag(ibnf)), ", ", ne(getibnag(ibnf)), ")")
        print(io, ", ", getibnfid.(getinteribnfs(ibnf)))
        print(io, ", ", typeof(getsdncontroller(ibnf)))
end
