# This file contains the interface and default algorithm for the intent compilation algorithms
"""
$(TYPEDEF)
$(TYPEDFIELDS)

Used for every intent compilation algorithm satisfying the template to cache and not recalculate results.
"""
struct CachedResults
    ibnagweights::Matrix{KMf}
    yenpathsdict::Dict{Edge{LocalNode}, Vector{Vector{LocalNode}}}
    yenpathsdistsdict::Dict{Edge{LocalNode}, Vector{KMf}}
end

function CachedResults(nodenum::Int)
    return CachedResults(zeros(KMf, nodenum, nodenum), Dict{Edge{LocalNode}, Vector{Vector{LocalNode}}}(), Dict{Edge{LocalNode}, Vector{KMf}}())
end

"""
$(TYPEDSIGNATURES)
"""
function getibnagweights(cr::CachedResults)
    return cr.ibnagweights
end

"""
$(TYPEDSIGNATURES)
"""
function getyenpathsdict(cr::CachedResults)
    return cr.yenpathsdict
end

"""
$(TYPEDSIGNATURES)
"""
function getyenpathsdistsdict(cr::CachedResults)
    return cr.yenpathsdistsdict
end

function CachedResults(ibnag::IBNAttributeGraph, candidatepathsnum)
    ibnweights = getweights(ibnag)

    yenpathsdict = Dict{Edge{LocalNode}, Vector{Vector{LocalNode}}}()
    yenpathsdistsdict = Dict{Edge{LocalNode}, Vector{eltype(ibnweights)}}()

    for srcnode in vertices(ibnag)
        for dstnode in vertices(ibnag)
            ed = Edge(srcnode, dstnode)
            if srcnode == dstnode
                yenpathsdict[ed] = [[srcnode]]
                yenpathsdistsdict[ed] = [zero(eltype(ibnweights))]
            else
                yenstate = Graphs.yen_k_shortest_paths(ibnag, srcnode, dstnode, ibnweights, candidatepathsnum)
                yenpathsdict[ed] = yenstate.paths
                yenpathsdistsdict[ed] = yenstate.dists
            end
        end
    end
    return CachedResults(ibnweights, yenpathsdict, yenpathsdistsdict)
end

"""
$(TYPEDSIGNATURES)
"""
function getcandidatepathsnum(intcompalg::IntentCompilationAlgorithm)
    return intcompalg.candidatepathsnum
end

"""
$(TYPEDSIGNATURES)
"""
function getpathsforprotectionnum(intcompalg::IntentCompilationAlgorithm)
    return intcompalg.pathsforprotectionnum
end

"""
$(TYPEDSIGNATURES)
"""
function getcachedresults(intcompalg::IntentCompilationAlgorithm)
    return intcompalg.cachedresults
end

"Compilation algorithm with some memory"
abstract type IntentCompilationAlgorithmWithMemory <: IntentCompilationAlgorithm end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
mutable struct BasicAlgorithmMemory
    """
    The simulated (or not) current datetime. 
    It's used by the algorithm to build the uptime/downtime data
    """
    datetime::DateTime
    """
    Log here the selection of (protection) path for an intra node (+ border) intent after install. 
    Add new elements upon installation
    A new path `Vector{Vector{LocalNode}} is added per node pair and counted how many times was it used`
    """
    logintrapaths::Dict{Edge{LocalNode}, Dict{Vector{Vector{LocalNode}}, Int}}
    """
    Log here the up/downtimes of border-node to cross node.
    Add new elements upon installation.
    Update entries upon compilation.
    All UUIDs correspond to Remote Connectivity intents
    """
    loginterupdowntimes::Dict{GlobalEdge, Dict{UUID, UpDownTimesNDatetime}}
end

function BasicAlgorithmMemory()
    return BasicAlgorithmMemory(now(), Dict{Edge{LocalNode}, Dict{Vector{Vector{LocalNode}}, Int}}(), Dict{GlobalEdge, Dict{UUID, UpDownTimesNDatetime}}())
end

const IBNFrameworkIntentAlgorithmWithMemory = IBNFramework{A,B,C,D,R} where {A,B,C,D,R<:IntentCompilationAlgorithmWithMemory}

"""
$(TYPEDSIGNATURES)
"""
function getlogintrapaths(bam::BasicAlgorithmMemory)
    return bam.logintrapaths 
end

"""
$(TYPEDSIGNATURES)
"""
function getloginterupdowntimes(bam::BasicAlgorithmMemory)
    return bam.loginterupdowntimes 
end


function getbasicalgmem(icawm::IntentCompilationAlgorithmWithMemory)
    return icawm.basicalgmem
end

"""
$(TYPEDSIGNATURES)
"""
function getdatetime(intcompalg::BasicAlgorithmMemory)
    return intcompalg.datetime
end

"""
$(TYPEDSIGNATURES)
"""
function setdatetime!(intcompalg::BasicAlgorithmMemory, currentdatetime::DateTime)
    return intcompalg.datetime = currentdatetime
end

"""
$(TYPEDSIGNATURES)
"""
function getlogintrapaths(intentcomp::IntentCompilationAlgorithmWithMemory)
    return getlogintrapaths(getbasicalgmem(intentcomp))
end

"""
$(TYPEDSIGNATURES)
"""
function getloginterupdowntimes(intentcomp::IntentCompilationAlgorithmWithMemory)
    return getloginterupdowntimes(getbasicalgmem(intentcomp))
end

function updateintcompalginstallation!(::IBNFramework{A,B,C,D,F}, ::UUID) where {A,B,C,D,F}
    return nothing
end

function updateintcompalginstallation!(ibnf::IBNFrameworkIntentAlgorithmWithMemory, idagnodeid::UUID)
    idagnode = getidagnode(getidag(ibnf), idagnodeid) 
    intcompalg = getintcompalg(ibnf)
    intent = getintent(idagnode)
    if intent isa ConnectivityIntent
        logintrapathsandinterintents!(ibnf, idagnode)
    end
end


"""
$(TYPEDSIGNATURES)
"""
function logintrapathsandinterintents!(ibnf::IBNFrameworkIntentAlgorithmWithMemory, idagnode::IntentDAGNode)
    intentuuidsalreadyaccessed = UUID[]
    intentcomp = getintcompalg(ibnf)
    # traverse intent DAG
    for childidagnode in getidagnodechildren(getidag(ibnf),idagnode)
        _rec_logintrapathsandinterintents!(ibnf::IBNFramework, childidagnode, intentuuidsalreadyaccessed)
    end
end

function _rec_logintrapathsandinterintents!(ibnf::IBNFrameworkIntentAlgorithmWithMemory, idagnode::IntentDAGNode, intentuuidsalreadyaccessed::Vector{UUID})
    intentcomp = getintcompalg(ibnf)
    intent = getintent(idagnode)
    continuedown = true
    getidagnodeid(idagnode) in intentuuidsalreadyaccessed && return
    push!(intentuuidsalreadyaccessed, getidagnodeid(idagnode))
    if intent isa ProtectedLightpathIntent || intent isa LightpathIntent
        prpath = if intent isa ProtectedLightpathIntent
            getprpath(intent)
        elseif intent isa LightpathIntent
            [getpath(intent)]
        end
        srcdst = Edge(prpath[1][1], prpath[1][end])
        logintrapaths = getlogintrapaths(intentcomp)
        if !haskey(logintrapaths, srcdst)
            logintrapaths[srcdst] = Dict{Vector{Vector{LocalNode}}, Int}()
        end
        if haskey(logintrapaths[srcdst], prpath)
            logintrapaths[srcdst][prpath] += 1
        else
            logintrapaths[srcdst][prpath] = 1
        end
        continuedown = false
    elseif intent isa RemoteIntent && getisinitiator(intent)
        conintent = getintent(intent)
        sourcenode = getsourcenode(conintent)
        destinationnode = getdestinationnode(conintent)
        logstates = getlogstate(idagnode)
        updowntimes = getupdowntimes(logstates, getdatetime(getbasicalgmem(intentcomp)))
        globaledge = GlobalEdge(sourcenode, destinationnode) 
        loginterupdowntimes = getloginterupdowntimes(intentcomp)
        if haskey(loginterupdowntimes, globaledge)
            getloginterupdowntimes(intentcomp)[GlobalEdge(sourcenode, destinationnode)][getidagnodeid(idagnode)] = UpDownTimesNDatetime(getuptimes(updowntimes), getdowntimes(updowntimes), getdatetime(getbasicalgmem(intentcomp)))
        else
            getloginterupdowntimes(intentcomp)[GlobalEdge(sourcenode, destinationnode)] = Dict{UUID, UpDownTimesNDatetime}(getidagnodeid(idagnode) => UpDownTimesNDatetime(getuptimes(updowntimes), getdowntimes(updowntimes), getdatetime(getbasicalgmem(intentcomp))))
        end
        continuedown = false
    end
    if continuedown
        for childidagnode in getidagnodechildren(getidag(ibnf), idagnode)
            _rec_logintrapathsandinterintents!(ibnf, childidagnode, intentuuidsalreadyaccessed)
        end
    end
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function updatelogintentcomp!(ibnf::IBNFrameworkIntentAlgorithmWithMemory)
    intentcomp = getintcompalg(ibnf)
    setdatetime!(getbasicalgmem(intentcomp), @logtime)
    currentdatetime = getdatetime(getbasicalgmem(intentcomp))
    for dictuuidupdowndatetime in values(getloginterupdowntimes(intentcomp))
        for (intentuuid, updownndatetime) in dictuuidupdowndatetime
            if intentuuid in getidagnodeid.(getidagnodes(getidag(ibnf)))
                logstates = getlogstate(getidagnode(getidag(ibnf), intentuuid))
                getupdowntimes!(updownndatetime, logstates, currentdatetime)
            end
        end
    end
end
