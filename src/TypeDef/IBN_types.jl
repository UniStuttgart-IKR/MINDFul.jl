"""
$(TYPEDEF)
All possible default intent states.
Another intent state schema could be defined.
"""
@enumx IntentState begin
    Uncompiled
    Pending
    Compiled
    Installed
    Failed
end

"Special requirements for an intent (such as QoS)"
abstract type AbstractIntentConstraint end

"Instances of this specify how to compile the intent"
abstract type IntentCompilationAlgorithm end

"""
How the IBN frameworks operates generally. 
It has effect of the available compilation algorithms
In the future it could also have effect on different intent state machines
"""
abstract type AbstractOperationMode end

"Default operation mode defined in MINDFul.jl"
struct DefaultOperationMode <: AbstractOperationMode end

"""
Stores a vector of the history of the intent states and their timings
"""
const IntentLogState{S <: Enum{Int32}} = Vector{Tuple{DateTime, S}}

"""
$(TYPEDSIGNATURES)
"""
function IntentLogState(intentstate::IntentState.T = IntentState.Uncompiled, logtime::DateTime=now())
    return [(logtime, intentstate)]    
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

"An `AttributeGraph` graph used as an intent Directed Acyclic Graph (DAG)"
const IntentDAG = AttributeGraph{Int, SimpleDiGraph{Int}, Vector{IntentDAGNode}, Nothing, IntentDAGInfo}

"""
$(TYPEDEF)

Contains the requirements to compile down to `TransmissionModuleLLI`

$(TYPEDFIELDS)
"""
struct TransmissionModuleIntent <: AbstractIntent
    "The data rate requierement"
    rate::GBPSf
    "Optical reach requirements in kilometres"
    opticalreach::KMf
    "Number of 12.5 GHz frequency slots needed"
    spectrumslotsneeded::Int
end

"""
$(TYPEDEF)

$(TYPEDFIELDS)
"""
struct ConnectivityIntent{T <: AbstractIntentConstraint} <: AbstractIntent
    "Source node"
    sourcenode::GlobalNode
    "Destination node"
    destinationnode::GlobalNode
    "Bandwidth request value (Gbps)"
    rate::GBPSf
    "Constraints for the Connecivity intent"
    constraints::Vector{T}
end

function ConnectivityIntent(sourcenode::GlobalNode, destinationnode::GlobalNode, rate::GBPSf)
    return ConnectivityIntent(sourcenode, destinationnode, rate, AbstractIntentConstraint[])
end

function Base.show(io::IO, connectivityintent::ConnectivityIntent)
    sourcenodeibnfid = @sprintf("%x", getfield(getibnfid(getsourcenode(connectivityintent)), :value))
    destinationnodeibnfid = @sprintf("%x", getfield(getibnfid(getdestinationnode(connectivityintent)), :value))
    print(io, "ConnectivityIntent(GN($(sourcenodeibnfid), $(getlocalnode(getsourcenode(connectivityintent))))")
    print(io, ", GN($(destinationnodeibnfid), $(getlocalnode(getdestinationnode(connectivityintent))))")
    print(io, ", $(getrate(connectivityintent))")
    constraints = getconstraints(connectivityintent)
    print(io, ", $(length(constraints)) constraints:")
    foreach(constraints) do constraint
        print(io, " ", typeof(constraint))
    end
    print(io, ")")
end

"""
$(TYPEDEF)

Constraint that requires the intent to terminate optically one node before the destination.
It's combined with an (@ref)[`OpticalInitiateConstraint`] after.
"""
struct OpticalTerminateConstraint <: AbstractIntentConstraint end

"""
$(TYPEDEF)

Constraint that requires the intent to initiate optically.
It's combined with an (@ref)[`OpticalTerminateConstraint`] before.
It contains some requirements for the connection to work out.

$(TYPEDFIELDS)
"""
struct OpticalInitiateConstraint <: AbstractIntentConstraint
    "The incoming border node entering the OXC"
    globalnode_input::GlobalNode
    "The spectrum range allocated 1-based indexed"
    spectrumslotsrange::UnitRange{Int}
    "the remaining optical reach to use"
    opticalreach::KMf
    "Requirements for termination in the electical layer"
    transmissionmodulecompat::TransmissionModuleCompatibility
end


"""
$(TYPEDEF)

$(TYPEDFIELDS)
"""
struct RemoteIntent{I<:AbstractIntent} <: AbstractIntent
    "The id of the remote IBN framework"
    ibnfid::UUID
    "The dag node id of the remote IBN framework"
    idagnodeid::UUID
    "The intent to be transferred"
    intent::I
    "`true` if the intent originates here and `false` otherwise"
    isinitiator::Bool
end

"""
$(TYPEDSIGNATURES)
"""
function is_low_level_intent(ci::ConnectivityIntent)
    return false
end

"A handler or API for IBNFrameworks to talk to each other"
abstract type AbstractIBNFHandler end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Fabian Gobantes implementation.
Should consist of basic information all handlers should have (e.g. `ibnfid`).
And a parametric type specific to the protocol used.
"""

"""
Abstract type for communication protocols between IBN Frameworks.
"""
abstract type AbstractIBNFComm end


"""
    The graph of the IBN Framework is expressed with this `AttributeGraph`.
    Border nodes are assumed to be visible from both sides.
    However only the official owner can issue an intent.
"""
const IBNAttributeGraph{T} = AttributeGraph{Int, SimpleDiGraph{Int}, Vector{T}, Dict{Edge{LocalNode}, EdgeView}, UUID} where {T <: NodeView}

function IBNAttributeGraph{T}(uuid::UUID) where {T <: NodeView}
    IBNAttributeGraph{T}(SimpleDiGraph{Int}(), Vector{T}(), Dict{Edge{LocalNode}, EdgeView}(), uuid)
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct IBNFramework{O <: AbstractOperationMode, S <: AbstractSDNController, T <: IBNAttributeGraph, H <: AbstractIBNFHandler} <: AbstractIBNFHandler
    "The operation mode of the IBN framework"
    operationmode::O
    "The id of this IBN Framework instance"
    ibnfid::UUID
    "The intent dag tree that contains all intents (can be disconnected graph)"
    intentdag::IntentDAG
    "Single-domain internal graph with border nodes included"
    ibnag::T
    "Other IBN Frameworks handles"
    ibnfhandlers::Vector{H}
    "SDN controller handle"
    sdncontroller::S
end

struct HandlerProperties
    ibnfid::UUID
    base_url::String
end

struct IBNFHTTP2Comm <: AbstractIBNFComm
    base_url::String # Base URL of the remote IBN Framework (e.g., "http://192.168.1.2:8081")
end

struct IBNFSameProcess{T<:IBNFramework} <: AbstractIBNFComm
    # this can  be the new dummy and substitute the current dummy implementation
    ibng::T
end

#=struct RemoteIBNFHandler{T<:AbstractIBNFComm} <: AbstractIBNFHandler
    handlerproperties::HandlerProperties
    ibnfcomm::T
end=#

struct RemoteIBNFHandler <: AbstractIBNFHandler
    ibnfid::UUID
    base_url::String
end



#struct RemoteIBNFHandler <: AbstractIBNFHandler
#end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""

"""
$(TYPEDSIGNATURES) 

The most default construct with abstract type of IBN handlers
"""
function IBNFramework(ibnag::T) where {T <: IBNAttributeGraph}
    ibnfid = AG.graph_attr(ibnag)
    # abstract type : for remote 
    return IBNFramework(DefaultOperationMode(), ibnfid, IntentDAG(), ibnag, IBNFramework{DefaultOperationMode, SDNdummy, T}[], SDNdummy())
end

"""
$(TYPEDSIGNATURES) 

Constructor that specify IBNFHandlers to make it potentially type stable
"""
function IBNFramework(ibnag::T, ibnfhandlers::Vector{H}) where {T <: IBNAttributeGraph, H <: AbstractIBNFHandler}
    ibnfid = AG.graph_attr(ibnag)
    # abstract type : for remote 
    return IBNFramework(DefaultOperationMode(), ibnfid, IntentDAG(), ibnag, ibnfhandlers, SDNdummy())
end

"""
$(TYPEDSIGNATURES)
"""
function Base.show(io::IO, ibnf::I) where {I <: IBNFramework}
    print(io, I, "(", getibnfid(ibnf))
    print(io, ", IntentDAG(", nv(getidag(ibnf)), ", ", ne(getidag(ibnf)), ")")
    print(io, ", IBNAttributeGraph(", nv(getibnag(ibnf)), ", ", ne(getibnag(ibnf)), ")")
    print(io, ", ", getibnfid.(getibnfhandlers(ibnf)))
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
