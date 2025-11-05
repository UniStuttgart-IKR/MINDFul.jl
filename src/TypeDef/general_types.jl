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

abstract type AbstractUpDownTimes end

struct UpDownTimes <: AbstractUpDownTimes 
    uptimes::Vector{Dates.Millisecond}
    downtimes::Vector{Dates.Millisecond}
end

function Base.show(io::IO, udts::UpDownTimes)
    print(io, "UpDownTimes( up: ", getuptimeshour(udts), " hr, down: ", getdowntimeshour(udts), " hr)")
end

function getuptimes(updt::AbstractUpDownTimes) 
    return updt.uptimes
end

function getuptimeshour(updt::AbstractUpDownTimes) 
    return millisecondtohour.(updt.uptimes)
end

function getuptimesmonth(updt::AbstractUpDownTimes) 
    return millisecondtomonth.(updt.uptimes)
end

function getdowntimes(updt::AbstractUpDownTimes) 
    return updt.downtimes
end

function getdowntimeshour(updt::AbstractUpDownTimes) 
    return millisecondtohour.(updt.downtimes)
end

function getdowntimesmonth(updt::AbstractUpDownTimes) 
    return millisecondtomonth.(updt.downtimes)
end

mutable struct UpDownTimesNDatetime{T} <: AbstractUpDownTimes 
    uptimes::Vector{Dates.Millisecond}
    downtimes::Vector{Dates.Millisecond}
    datetimestamps::Vector{Tuple{DateTime, T}}
    datetime::DateTime
end

function UpDownTimes(udtnd::UpDownTimesNDatetime)
    return UpDownTimes(getuptimes(udtnd), getdowntimes(udtnd))
end

function getdatetimestamps(uptnd::UpDownTimesNDatetime)
    return uptnd.datetimestamps
end

function getdatetime(uptnd::UpDownTimesNDatetime)
    return uptnd.datetime
end

function setdatetime!(uptnd::UpDownTimesNDatetime, datetime::DateTime)
    uptnd.datetime = datetime
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)

What most time-sensitive functions return
"""
struct ReturnCodeTime
    returncode::Symbol
    datetime::DateTime
end

function Base.iterate(c::ReturnCodeTime, state = 0)
    state >= nfields(c) && return nothing
    return Base.getfield(c, state+1), state+1
end

"""
$(TYPEDSIGNATURES)
"""
function getreturncode(rct::ReturnCodeTime)
    rct.returncode
end

"""
$(TYPEDSIGNATURES)
"""
function getdatetime(rct::ReturnCodeTime)
    rct.datetime
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct ReturnUUIDTime
    uuid::UUID
    datetime::DateTime
end

function Base.iterate(c::ReturnUUIDTime, state = 0)
    state >= nfields(c) && return nothing
    return Base.getfield(c, state+1), state+1
end

"""
$(TYPEDSIGNATURES)
"""
function getuuid(rct::ReturnUUIDTime)
    rct.uuid
end

"""
$(TYPEDSIGNATURES)
"""
function getdatetime(rct::ReturnUUIDTime)
    rct.datetime
end
