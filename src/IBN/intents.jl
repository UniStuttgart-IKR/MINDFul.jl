#=
# This is supposed to be a simplified version of an Intent Language System
=#

export ConnectivityIntent
export CapacityConstraint, DelayConstraint

#traits for Intent
subjects(i::Intent) = error("not implemented")
priority(i::Intent) = error("not implemented")
actions(i::Intent) = error("not implemented")
status(i::Intent) = error("not implemented")

getsrc(i::Intent) = i.src
getdst(i::Intent) = i.dst
getsrcdom(i::Intent) = i.src[1]
getsrcdomnode(i::Intent) = i.src[2]
getdstdom(i::Intent) = i.dst[1]
getdstdomnode(i::Intent) = i.dst[2]
getconstraints(i::Intent) = i.constraints
getcompilation(i::Intent) = i.compilation
setcompilation!(i::Intent, ic::T) where {T<:Union{IntentCompilation, Missing}} = setfield!(i, :compilation, ic)
getconditions(i::Intent) = i.conditions
getstate(i::Intent) = i.state
setstate!(i::Intent, is::IntentState) = setfield!(i, :state, is)

#TODO add node port number information and frequency slot information
# since in the future different ports will have different abilities
struct ConnectivityIntentCompilation <: IntentCompilation
    "Flow path"
    path::Vector{Int}
    "Capacity reserved along the path"
    capacity::Float64
end

#struct OptConnectivityIntentCompilation <: IntentCompilation
#    "Flow path"
#    path::Vector{Int}
#    "Capacity reserved along the path"
#    channel::RangeHotVector
#    #modulation
#end

mutable struct RemoteIntentCompilation <: IntentCompilation
    "remote IBN"
    remoteibn::IBN
    "Intent index in the remote IBN"
    intentidx::Union{Int, Missing}
end

"""
Intent for connecting 2 nodes

    $(TYPEDFIELDS)
"""
mutable struct ConnectivityIntent <: Intent 
    "Source node as (IBN.id, node-id)"
    src::Tuple{Int, Int}
    "Destination node as (IBN.id, node-id)"
    dst::Tuple{Int, Int}
    #TODO constrs is array of abstract, so not performant (Union Splitting, or Tuple in the future ?)
    "Intents constraints"
    constraints::Vector{IntentConstraint}
    "Intents conditions"
    conditions::Vector{IntentCondition}
    "Intent concrete compilation to policy"
    compilation::Union{ConnectivityIntentCompilation, RemoteIntentCompilation, InheritIntentCompilation, Missing}
    "Intent state"
    state::IntentState
end
ConnectivityIntent(ce::CompositeEdge, args...) = ConnectivityIntent(ce.src, ce.dst, args...)
ConnectivityIntent(src::Tuple{Int,Int},dst::Tuple{Int, Int}, constraints::Vector{R}, conditions::Vector{T}=Vector{IntentCondition}()) where 
    {T<:IntentCondition, R<:IntentConstraint} = ConnectivityIntent(src, dst, constraints, conditions, missing, uncompiled)

newintent(intent::ConnectivityIntent) = ConnectivityIntent(getsrc(intent), getdst(intent), getconstraints(intent), 
                                                           getconditions(intent), missing, uncompiled)

newintent(intent::ConnectivityIntent, comp::R) where {R<:IntentCompilation} = 
    ConnectivityIntent(getsrc(intent), getdst(intent), getconstraints(intent), getconditions(intent), comp, compiled)

isintraintent(ibn::IBN, intentt::IntentTree{R}) where {R<:Intent} = ibn.id == getsrc(intentt)[1] == getdst(intentt)[1]
"""
Intent for connecting 2 IBNs

    $(TYPEDFIELDS)
"""
mutable struct IBNConnectivityIntent{R,T} <: Intent 
    "Source node as (IBN.id, node-id)"
    src::R
    "Destination node as (IBN.id, node-id)"
    dst::T
    #TODO constrs is array of abstract, so not performant (Union Splitting, or Tuple in the future ?)
    "Intents constraints"
    constraints::Vector{IntentConstraint}
    "Intents conditions"
    conditions::Vector{IntentCondition}
    "Intent concrete compilation to policy"
    compilation::Union{ConnectivityIntentCompilation, RemoteIntentCompilation, InheritIntentCompilation, Missing}
    "Intent state"
    state::IntentState
end
IBNConnectivityIntent(ce::CompositeEdge, args...) = IBNConnectivityIntent(ce.src, ce.dst, args...)
IBNConnectivityIntent(src::Tuple{Int,Int},dst::Tuple{Int, Int}, constraints::Vector{R}, conditions::Vector{T}=Vector{IntentCondition}()) where 
    {T<:IntentCondition, R<:IntentConstraint} = IBNConnectivityIntent(src, dst, constraints, conditions, missing, uncompiled)

getsrcdom(i::IBNConnectivityIntent{Int, Tuple{Int,Int}}) = i.src
getsrcdomnode(i::IBNConnectivityIntent{Int, Tuple{Int,Int}}) = error("$(typeof(i)) does not have a particular source node")
getdstdom(i::IBNConnectivityIntent{Tuple{Int,Int}, Int}) = i.dst
getdstdomnode(i::IBNConnectivityIntent{Tuple{Int,Int}, Int}) = error("$(typeof(i)) does not have a particular destination node")

struct CapacityConstraint <: IntentConstraint
    #TODO intergrate with Unitful once PR is pushed
    "In Gppbs"
    capacity::Float64
    #todo use Unitful
end

struct DelayConstraint <: IntentConstraint
    "Delay in milliseconds"
    delay::Float64
end

"Checks if intent is satisfied"
function issatisfied(ibn::IBN, inid::Int)
    issatisfied = isinstalled(ibn, inid)
    for constr in ibn.intents[inid].constrs
        issatisfied = issatisfied && issatisfied(ibn, inid, constr)
    end
    return issatisfied
end
isinstalled(ibn::IBN, inid::Int) = state(ibn.intents[inid]) == installed
issatisfied(ibn::IBN, inid::Int, constr::CapacityConstraint) = return getcompilation(ibn.intents[inid]).capacity >= constr.capacity
issatisfied(ibn::IBN, inid::Int, constr:: DelayConstraint) = sum(delay(l) for l in edgeify(getcompilation(ibn.intents[inid]).path)) <= constr.delay
