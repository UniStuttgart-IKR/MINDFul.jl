"""
$(TYPEDEF)

A concrete subtype of `AbstractIntent` must implement the following methods: 
- [`is_low_level_intent`](@ref)
"""
abstract type AbstractIntent end

"""
$(TYPEDEF)

An abstract subtype of `AbstractIntent` notating device-level intents and should return [`is_low_level_intent`](@ref) to be `true`
"""
abstract type LowLevelIntent <: AbstractIntent end

"Signifies a local node notation as a single integer"
const LocalNode = Int

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct GlobalNode
    "IBN Framework id"
    ibnfid::UUID
    "Node number"
    localnode::LocalNode
end

struct GlobalEdge <: Graphs.AbstractSimpleEdge{LocalNode}
    src::GlobalNode
    dst::GlobalNode
end

const KMf = typeof(u"1.0km")
const GBPSf = typeof(u"1.0Gbps")
const HRf = typeof(u"1.0hr")

"""
Stores a vector of the history of the boolean states and their timings
"""
const BoolLogState = Vector{Tuple{DateTime, Bool}}

"""
$(TYPEDSIGNATURES)

Implementing BoolLogState() is type piracy.
"""
function construct_BoolLogState(offsettime=now(), initialstate = true)
    return [(offsettime, initialstate)]
end

struct UpDownTimes
    uptimes::Vector{Dates.Millisecond}
    downtimes::Vector{Dates.Millisecond}
end

function getuptimes(updt::UpDownTimes) 
    return updt.uptimes
end

function getuptimestohours(updt::UpDownTimes)
    return getuptimes(updt).value ./ 1000 ./ 60
end

function getdowntimes(updt::UpDownTimes) 
    return updt.downtimes
end

function getdowntimestohours(updt::UpDownTimes)
    return getdowntimes(updt).value ./ 1000 ./ 60
end
