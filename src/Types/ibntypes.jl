"""
Defines the way the IBN Framework state machine will behave
For now only a `SimpleIBNModus` strategy is implemented.
"""
abstract type IBNModus end
struct SimpleIBNModus <: IBNModus end 
struct AdvancedIBNModus <: IBNModus end

"Defines the entity issuing an intent"
abstract type IntentIssuer end
struct NetworkProvider <: IntentIssuer end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct IBNIssuer <: IntentIssuer
    "the id of the IBN issued an intent"
    ibnid::Int
    "the id of the intent issued, i.e. id of the DAG"
    dagid::Int
    "the id of the intent node in the DAG"
    dagnodeid::UUID
end
IBNIssuer(ibnid::Int, intentid::Int) = IBNIssuer(ibnid, intentid, UUID(1))

"Characterization of an Intent for algorithm dispatch"
abstract type IntentDomain end
struct IntraIntent <: IntentDomain end
abstract type IntentDirection end
struct IntentForward <: IntentDirection end
struct IntentBackward <: IntentDirection end
struct InterIntent{R<:IntentDirection} <: IntentDomain end
InterIntent() = InterIntent{IntentForward}()

"""
$(TYPEDEF)
$(TYPEDFIELDS)
Information needed for interacting IBN.
*still not used*
"""
struct IBNInterProps 
    "permissions of other IBN"
    permissions::BitVector
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
The Intent Framework
The intent id is the vector index
`controllers` must have same length with `ngr.grv`
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
    """
    Nested Graph consisting of the several SDNs
    ngr is a shallow copy of the sdn graphs, 
    meaning all PHY information is available in the IBN
    """
    ngr::NestedGraph{Int,MetaDiGraph{Int,Float64},MetaDiGraph{Int,Float64}}
    "InterIBN interoperability with key being the IBN id"
    interprops::Dict{Int,IBNInterProps}
end
#Base.show(io::IO, ::MIME"text/plain", ibn::IBN) = print(io,"IBN($(ibn.id), $(length(ibn.intents)) intents, $(length(ibn.controllers)) controllers, $(ibn.ngr), $(ibn.interprops))")
IBN(counter::Counter, args...) = IBN(counter(), args...)
IBN!(counter::Counter, args...) = IBN!(counter(), args...)
"Empty constructor"
IBN(c::Int, ::Type{T}) where {T<:SDN}  = IBN(c, 
                                            Vector{IntentDAG}(), 
                                            Vector{IntentIssuer}(), 
                                            Vector{Union{T, IBN}}(), 
                                            NestedGraph(),
                                            Dict{Int, IBNInterProps}())

IBN(c::Int, controllers::Vector{T}) where {T<:Union{SDN,IBN}}  = IBN(c, controllers, NestedGraph(getfield.(controllers, :gr)))
IBN!(c::Int, controllers::Vector{T}, eds::Vector{NestedEdge{R}}) where {T<:Union{SDN,IBN}, R}  = IBN(c, controllers, mergeSDNs!(controllers, eds))
IBN(c::Int, controllers::Vector{T}, ng::NestedGraph) where {T<:Union{SDN,IBN}}  = IBN(c, 
                                                            Vector{IntentDAG}(), 
                                                            Vector{IntentIssuer}(), 
                                                            Vector{Union{T, IBN}}(controllers), 
                                                            ng,
                                                            Dict{Int, IBNInterProps}())

# struct IBNnIntent{R}
#     ibn::IBN
#     dag::IntentDAG
#     idn::IntentDAGNode{R}
# end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
A container of a low-level intent `lli` with a global view.
The related `ibn`, `dag` and `idn` are also contained.
"""
struct IBNnIntentGLLI{R,T<:LowLevelIntent}
    ibn::IBN
    dag::IntentDAG
    idn::IntentDAGNode{R}
    "global low level intent"
    lli::T
#    IBNnIntentGLLI(ibn,dag,idn::IntentDAGNode{R}, lli::NodeSpectrumIntent{Tuple{Int, Int}, C}) where
#        {R <: Intent, C <: NestedEdge} = new{R, NodeSpectrumIntent{Tuple{Int, Int}, C}}(ibn, dag, idn,lli)
#    IBNnIntentGLLI(ibn,dag,idn::IntentDAGNode{R}, lli::NodeRouterPortIntent{Tuple{Int, Int}}) where
#        R <: Intent = new{R, NodeRouterPortIntent{Tuple{Int, Int}}}(ibn, dag, idn,lli)
#    IBNnIntentGLLI(ibn,dag,idn::IntentDAGNode{R}, lli::RemoteLogicIntent{C}) where 
#    {R<:Intent, C<:Intent}  = new{R, RemoteLogicIntent{C}}(ibn, dag, idn, lli)
end
getlli(giig::IBNnIntentGLLI) = giig.lli
