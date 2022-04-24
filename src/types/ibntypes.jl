"Defines the way the IBN Framework state machine will behave"
abstract type IBNModus end
struct SimpleIBNModus <: IBNModus end
struct AdvancedIBNModus <: IBNModus end

"Defines the entity issuing an intent"
abstract type IntentIssuer end
struct NetworkProvider <: IntentIssuer end
struct IBNIssuer <: IntentIssuer
    ibnid::Int
    intentidx::Int
end

"Characterization of an Intent for algorithm dispatch"
abstract type IntentDomain end
struct IntraIntent <: IntentDomain end
abstract type IntentDirection end
struct IntentForward <: IntentDirection end
struct IntentBackward <: IntentDirection end
struct InterIntent{R<:IntentDirection} <: IntentDomain end
InterIntent() = InterIntent{IntentForward}()

"Information needed for interacting IBN"
struct IBNInterProps 
    "permissions of other IBN"
    permissions::BitVector
end

"""
The Intent Framework
The intent id is the vector index
`controllers` must have same length with `cgr.grv`
    $(TYPEDFIELDS)
"""
struct IBN{T<:SDN}
    "id of IBN"
    id::Int
    #TODO Union split ?
    "The intent collection of the IBN Framework"
    intents::Vector{IntentDAG}
    intentissuers::Vector{Union{NetworkProvider,IntentIssuer}}
    #TODO integrate permissions 
    #TODO implement IBN-NBI
    "The collection of SDNs controlled from this IBN Framework and interacting IBNs (future should be IBN-NBIs)"
    controllers::Vector{Union{T, IBN}}
    #TODO make R -> CompositeGraph directly
    """
    Composite Graph consisting of the several SDNs
    cgr is a shallow copy of the sdn graphs, 
    meaning all PHY information is available in the IBN
    """
    cgr::CompositeGraph{MetaDiGraph,MetaDiGraph}
    "InterIBN interoperability with key being the IBN id"
    interprops::Dict{Int,IBNInterProps}
end
IBN(counter::Counter, args...) = IBN(counter(), args...)
IBN!(counter::Counter, args...) = IBN!(counter(), args...)
"Empty constructor"
IBN(c::Int, ::Type{T}) where {T<:SDN}  = IBN(c, 
                                            Vector{IntentDAG}(), 
                                            Vector{IntentIssuer}(), 
                                            Vector{Union{T, IBN}}(), 
                                            CompositeGraph(),
                                            Dict{Int, IBNInterProps}())

IBN(c::Int, controllers::Vector{T}) where {T<:Union{SDN,IBN}}  = IBN(c, controllers, CompositeGraph(getfield.(controllers, :gr)))
IBN!(c::Int, controllers::Vector{T}, eds::Vector{CompositeEdge{R}}) where {T<:Union{SDN,IBN}, R}  = IBN(c, controllers, mergeSDNs!(controllers, eds))
IBN(c::Int, controllers::Vector{T}, cg::CompositeGraph) where {T<:Union{SDN,IBN}}  = IBN(c, 
                                                            Vector{IntentDAG}(), 
                                                            Vector{IntentIssuer}(), 
                                                            Vector{Union{T, IBN}}(controllers), 
                                                            cg,
                                                            Dict{Int, IBNInterProps}())
