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
Base.show(io::IO, ric::RemoteIntentCompilation) = print(io,"RemoteIntentCompilation(ibnid=$(getid(ric.remoteibn)), idx = $(ric.intentidx)))")
Base.show(io::IO, ::MIME"text/plain", ric::RemoteIntentCompilation) = print(io,"RemoteIntentCompilation(ibnid=$(getid(ric.remoteibn)), idx = $(ric.intentidx)))")

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

function isintraintent(ibn::IBN, intenttr::IntentTree{R}) where {R<:Intent}
    if getid(ibn) == getsrc(intenttr)[1] == getdst(intenttr)[1]
        return true
    elseif getid(ibn) == getsrcdom(intenttr)
        return getdst(intenttr) in transnodes(ibn)
    elseif getid(ibn) == getdstdom(intenttr)
        return getsrc(intenttr) in transnodes(ibn)
    else
        return false
    end
end

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

has_extendedchildren(intr::IntentTree) = (getcompilation(intr) isa RemoteIntentCompilation) || AbstractTrees.has_children(intr)

function extendedchildren(intr::IntentTree)
    if getcompilation(intr) isa RemoteIntentCompilation
        comp = getcompilation(intr)
        return [comp.remoteibn.intents[comp.intentidx]]
    elseif AbstractTrees.has_children(intr)
        return children(intr)
    end
end
"Assuming that `intr` belongs to `ibn`, return extended children together with the corresponding ibn"
function extendedchildren(ibn::IBN, intr::IntentTree)
    if getcompilation(intr) isa RemoteIntentCompilation
        comp = getcompilation(intr)
        return zip(Iterators.repeated(comp.remoteibn),[comp.remoteibn.intents[comp.intentidx]])
    elseif AbstractTrees.has_children(intr)
        return zip(Iterators.repeated(ibn), children(intr))
    end
end

function recursive_extendedchildren!(ibn::IBN, intents, intr::IntentTree; ibnidfilter::Union{Nothing, Int}=nothing)
    if has_extendedchildren(intr)
        for (nextibn, chintentr) in extendedchildren(ibn,intr)
            if getid(nextibn) == ibnidfilter
                push!(intents, chintentr.data)
            end
            recursive_extendedchildren!(nextibn, intents, chintentr; ibnidfilter=ibnidfilter)
        end
    end
end
function recursive_extendedchildren!(ibn::IBN, ibnintd::Dict{Int, Vector{Intent}}, intr::IntentTree)
    if has_extendedchildren(intr)
        for (nextibn, chintentr) in extendedchildren(ibn,intr)
            if !haskey(ibnintd, getid(nextibn))
                ibnintd[getid(nextibn)] = Vector{Intent}()
            end
            push!(ibnintd[getid(nextibn)], chintentr.data)
            recursive_extendedchildren!(nextibn, ibnintd, chintentr)
        end
    end
end
function recursive_extendedchildren!(intents, intr::IntentTree)
    if has_extendedchildren(intr)
        for chintentr in extendedchildren(intr)
            push!(intents, chintentr.data)
            recursive_extendedchildren!(intents, chintentr)
        end
    end
end
function recursive_children!(intents, intr::IntentTree)
    if AbstractTrees.has_children(intr)
        for chintentr in children(intr)
            push!(intents, chintentr.data)
            recursive_children!(intents, chintentr)
        end
    end
end
function descendants(intr::IntentTree)
    intents = Vector{Intent}()
    push!(intents, intr.data)
    recursive_extendedchildren!(intents, intr)
    return intents
end
function family(ibn::IBN, intidx::Int; intraibn::Bool=false, ibnidfilter::Union{Nothing, Int}=nothing)
    intents = Vector{Intent}()
    if intraibn
        if ibnidfilter === nothing || ibnidfilter == getid(ibn)
            return intents
        else
            push!(intents, ibn.intents[intidx].data)
            recursive_children!(intents, ibn.intents[intidx])
        end
    else
        if ibnidfilter === nothing || ibnidfilter == getid(ibn)
            push!(intents, ibn.intents[intidx].data)
        end
        recursive_extendedchildren!(ibn, intents, ibn.intents[intidx]; ibnidfilter=ibnidfilter)
    end
    return intents
end

function dividefamily(ibn::IBN, intidx::Int)
    ibnintd = Dict{Int, Vector{Intent}}()
    ibnintd[getid(ibn)] = Vector{Intent}([ibn.intents[intidx].data])
    recursive_extendedchildren!(ibn, ibnintd, ibn.intents[intidx])
    return ibnintd
end

function edgeify(intents::Vector{Intent}, ::Type{R}) where R<:IntentCompilation
    concomps = [getcompilation(intent) for intent in intents if getcompilation(intent) isa ConnectivityIntentCompilation]
    paths = [getfield(concomp, :path) for concomp in concomps]
    return [edgeify(path) for path in paths]
end

"""
Takes input all available IBNs
Prints out a full Intent Tree across all of them
"""
function print_tree_extended(intr::IntentTree, maxdepth=5)
    p = getpair(intr)
    print_tree(p, maxdepth=maxdepth)
end

function getextendedchildrenpair(intr::IntentTree)
    if getcompilation(intr) isa RemoteIntentCompilation
        comp = getcompilation(intr)
        getpair(comp.remoteibn.intents[comp.intentidx])
    elseif AbstractTrees.has_children(intr)
        getpair.(children(intr))
    else
        return intr
    end
end

function getpair(intr::IntentTree)
    if !has_extendedchildren(intr)
        return intr
    else
        return Pair(intr, getextendedchildrenpair(intr))
    end
end

