#=
# This is supposed to be a simplified version of an Intent Language System
=#

export ConnectivityIntent
export CapacityConstraint, DelayConstraint

abstract type Intent end
abstract type IntentConstraint end
abstract type IntentCompilation end

abstract type IntentState end
struct InstalledIntent <: IntentState end
struct UninstalledIntent <: IntentState end

abstract type IntentTransition end
struct InstallIntent <: IntentTransition end
struct UninstallIntent <: IntentTransition end

#traits for Intent
src(i::Intent) = error("not implemented")
dst(i::Intent) = error("not implemented")
constraints(i::Intent) = error("not implemented")
compilation(i::Intent) = error("not implemented")
state(i::Intent) = error("not implemented")

#TODO add node port number information
# since in the future different ports will have different abilities
struct ConnectivityIntentCompilation <: IntentCompilation
    "Flow path"
    path::Vector{Int}
    "Capacity reserved along the path"
    capacity::Float64
end

struct RemoteIntentCompilation <: IntentCompilation end
struct InheritIntentCompilation <: IntentCompilation end

"""
Intent for connecting 2 nodes

    $(TYPEDFIELDS)
"""
mutable struct ConnectivityIntent <: Intent 
    "Source node as (IBN.id, node-id)"
    src::Tuple{Int, Int}
    "Destination node as (IBN.id, node-id)"
    dst::Tuple{Int, Int}
    #TODO constrs is array of abstract, so not performant
    "Intents constraints"
    constraints::Vector{IntentConstraint}
    "Intent concrete compilation to policy"
    compilation::Union{ConnectivityIntentCompilation, RemoteIntentCompilation, InheritIntentCompilation, Missing}
    "Intent state"
    state::IntentState
end
src(i::ConnectivityIntent) = i.src
dst(i::ConnectivityIntent) = i.dst
constraints(i::ConnectivityIntent) = i.constraints
compilation(i::ConnectivityIntent) = i.compilation
setcompilation!(i::ConnectivityIntent, ic::IntentCompilation) = setfield!(i, :compilation, ic)
state(i::ConnectivityIntent) = i.state
setstate!(i::ConnectivityIntent, is::IntentState) = setfield!(i, :state, is)
ConnectivityIntent(ce::CompositeEdge, args...) = ConnectivityIntent(ce.src, ce.dst, args...)
ConnectivityIntent(src::Tuple{Int,Int},dst::Tuple{Int, Int},constraints::Vector{R}) where {R<:IntentConstraint} = ConnectivityIntent(src, dst,constraints, missing, UninstalledIntent())


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

step(ista::T, itra::R) where {T<:IntentState, R<:IntentTransition} = error("illegal operation")


