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
    "Intents Constraints"
    constrs::Vector{IntentConstraint}
end

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

struct ConnectivityIntentCompilation <: IntentCompilation
    "Flow path"
    path::Vector{Int}
    "Capacity reserved along the path"
    capacity::Float64
end
