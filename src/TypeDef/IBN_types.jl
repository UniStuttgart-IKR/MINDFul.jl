"""
$(TYPEDEF)
All possible default intent states.
Another intent state schema could be defined.
"""
@enumx IntentState begin
    Uncompiled
    Pending
    Compiled
    Installing
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

"""
$(TYPEDEF)
$(TYPEDFIELDS)

Represents an implementation of a ConnectivityIntent as a lightpath
"""
struct LightpathRepresentation
    "The nodes comprising the lightpath"
    path::Vector{LocalNode}
    "`true` if it starts optically (due to `OpticalInitiateConstraint`) or `false` otherwise"
    startsoptically::Bool
    "`true` if it terminates optically (due to `OpticalTerminateConstraint`) or `false` otherwise"
    terminatessoptically::Bool
    "total bandwidth that can be allocated"
    totalbandwidth::GBPSf
    """
    final node of the signal entering this lightpath.
    This could be a GlobalNode intrnally in the domain for a single lightpath.
    Or an external GlobalNode in a different domain for a cross-lightpath.
    In the second case, the signal might go over different lightpaths to reach the destination.
    """
    destinationnode::GlobalNode
end

"""
$(TYPEDEF)

$(TYPEDFIELDS)
"""
mutable struct IntentDAGInfo
    "The counter of the number of intents to give increasing ids to intents"
    intentcounter::Int
    "Logical representation of the installed intents as lightpaths (must be direct parent of the LLIs)"
    installedlightpaths::Dict{UUID, LightpathRepresentation}
end

"""
$(TYPEDSIGNATURES)

Empty constructor 
"""
function IntentDAGInfo()
    return IntentDAGInfo(0, Dict{UUID, LightpathRepresentation}())
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

"""
$(TYPEDEF)

$(TYPEDFIELDS)

Basically an aggregator of `RouterPortLLI`, `TransmissionModuleLLI`, `OXCAddDropBypassSpectrumLLI` in a node.
"""
struct EndNodeAllocations
    localnode::Int
    routerportindex::Union{Nothing, Int}
    transmissionmoduleviewpoolindex::Union{Nothing, Int}
    transmissionmodesindex::Union{Nothing, Int}
    localnode_input::Union{Nothing, Int}
    adddropport::Union{Nothing, Int}
end

mutable struct MutableEndNodeAllocations
    localnode::Int
    routerportindex::Union{Nothing, Int}
    transmissionmoduleviewpoolindex::Union{Nothing, Int}
    transmissionmodesindex::Union{Nothing, Int}
    localnode_input::Union{Nothing, Int}
    adddropport::Union{Nothing, Int}
end

function MutableEndNodeAllocations()
    return MutableEndNodeAllocations(0, nothing, nothing, nothing, nothing, nothing)
end

function EndNodeAllocations(mena::MutableEndNodeAllocations)
    return EndNodeAllocations(mena.localnode, mena.routerportindex, mena.transmissionmoduleviewpoolindex, mena.transmissionmodesindex, mena.localnode_input, mena.adddropport)
end

"""
$(TYPEDSIGNATURES)

Return true if allocaitons on the node do not influence the electrical devices.
This is equivalent to the `OpticalInitiateConstraint` and `OpticalTerminateConstraint`
"""
function isonlyoptical(ena::EndNodeAllocations)
    if iszeroornothing(getrouterportindex(ena)) && iszeroornothing(gettransmissionmoduleviewpoolindex(ena)) && iszeroornothing(gettransmissionmodesindex(ena)) 
        return true
    end
    return false
end


"""
$(TYPEDEF)

$(TYPEDFIELDS)

Basicaly an aggregator of `LowLevelIntents`.
One lightpath intent can translate trivially to LowLevelIntents.
It's core use is for grooming, where several Connectivity Intents can be linked to one LightpathIntent
If the field does not apply, put `0`
"""
struct LightpathIntent <: AbstractIntent
    sourcenodeallocations::EndNodeAllocations
    destinationnodeallocations::EndNodeAllocations
    spectrumslotsrange::UnitRange{Int}
    path::Vector{LocalNode}
end

function LightpathIntent(srcallocations::MutableEndNodeAllocations, dstallocations::MutableEndNodeAllocations, specrumslotsrange::UnitRange{Int}, path::Vector{LocalNode})
    srcnodeallocations = EndNodeAllocations(srcallocations)
    dstnodeallocations = EndNodeAllocations(dstallocations)
    return LightpathIntent(srcnodeallocations, dstnodeallocations, specrumslotsrange, path)
end

function Base.show(io::IO, lpt::LightpathIntent)
    startingoptical = isonlyoptical(lpt.sourcenodeallocations)
    endingoptical = isonlyoptical(lpt.destinationnodeallocations)
    description = 
    if startingoptical && endingoptical
        "segment"
    elseif startingoptical
        "o-starting"
    elseif endingoptical
        "o-ending"
    else
        "full"
    end
    print(io, description, " lightpath ", lpt.path, " ",lpt.spectrumslotsrange)
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

Constraint that requires the intent is compiled without use of grooming techniques.
"""
struct NoGroomingConstraint <: AbstractIntentConstraint end

"""
$(TYPEDEF)

Constraint that requires the intent to terminate optically one node before the destination.
It's combined with an (@ref)[`OpticalInitiateConstraint`] after.

$(TYPEDFIELDS)
"""
struct OpticalTerminateConstraint <: AbstractIntentConstraint
    """
    The final destination (intra domain or inter-domain)
    Used primarily for grooming cross lightpaths.
    """
    finaldestination::GlobalNode
end

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
$(TYPEDEF)
$(TYPEDFIELDS)

The only intent that is being built from its children to be offered as a straight grooming possibility.
It is composed by a `LightpathIntent` and a `RemoteIntent` which are also its children intents.
"""
struct CrossLightpathIntent{C1<:ConnectivityIntent, C2<:ConnectivityIntent, } <: AbstractIntent
    lightpathconnectivityintent::C2
    remoteconnectivityintent::C1
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

A single token is generated per directed pair.
The permission is referring to the genenerated token (gentoken).
gentoken and recvtoken are not constant as they will be generated when the handshake is done.
"""
mutable struct RemoteHTTPHandler <: AbstractIBNFHandler
    const ibnfid::UUID
    const baseurl::String
    const permission::String
    const key::String
    gensecret::String
    gentoken::String
    recvtoken::String
end

"The type of the HTTP server used in the IBN Framework depends on whether the encryption is used or not."
const OxygenServer = Union{HTTP.Servers.Server{HTTP.Servers.Listener{Nothing, Sockets.TCPServer}}, HTTP.Servers.Server{HTTP.Servers.Listener{MbedTLS.SSLConfig, Sockets.TCPServer}}}
"""
$(TYPEDEF)
$(TYPEDFIELDS)
Server is of type Union{Nothing, OxygenServer} to allow for the server to be started later.
"""
mutable struct IBNFCommunication{H <: AbstractIBNFHandler} 
  server::Union{Nothing, OxygenServer}
  ibnfhandlers::Vector{H}
end

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
struct IBNFramework{O <: AbstractOperationMode, S <: AbstractSDNController, T <: IBNAttributeGraph, I <: IBNFCommunication} <: AbstractIBNFHandler
    "The operation mode of the IBN framework"
    operationmode::O
    "The id of this IBN Framework instance"
    ibnfid::UUID
    "The intent dag tree that contains all intents (can be disconnected graph)"
    intentdag::IntentDAG
    "Single-domain internal graph with border nodes included"
    ibnag::T
    "Other IBN Frameworks handles"
    ibnfcomm::I 
    "SDN controller handle"
    sdncontroller::S
end

"""
$(TYPEDSIGNATURES) 

The most default construct with abstract type of IBN handlers
"""
function IBNFramework(ibnag::T) where {T <: IBNAttributeGraph}
    ibnfid = AG.graph_attr(ibnag)
    ibnfcomm = IBNFCommunication(nothing, IBNFramework{DefaultOperationMode, SDNdummy, T}[])
    # abstract type : for remote 
    return IBNFramework(DefaultOperationMode(), ibnfid, IntentDAG(), ibnag, ibnfcomm, SDNdummy())
end

"""
$(TYPEDSIGNATURES) 

Constructor that specify IBNFHandlers to make it potentially type stable
"""
function IBNFramework(ibnag::T, ibnfhandlers::Vector{H}, encryption::Bool, ips::Vector{String}, ibnfsdict::Dict{Int, IBNFramework} = Dict{Int, IBNFramework}(); verbose::Bool=false) where {T <: IBNAttributeGraph, H <: AbstractIBNFHandler}
    ibnfid = AG.graph_attr(ibnag)
    
    ibnfcomm = IBNFCommunication(nothing, ibnfhandlers)
    ibnf = IBNFramework(DefaultOperationMode(), ibnfid, IntentDAG(), ibnag, ibnfcomm, SDNdummy())

    port = getibnfhandlerport(getibnfhandlers(ibnf)[1])
    push!(ibnfsdict, port => ibnf)

    httpserver = startibnserver!(ibnfsdict, encryption, ips, port; verbose)
    setibnfserver!(ibnf, httpserver)
    
    return ibnf
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

