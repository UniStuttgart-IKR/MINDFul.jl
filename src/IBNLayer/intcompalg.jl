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
function getallflatpaths(cr::CachedResults)
    return [path for (_, paths) in cr.yenpathsdict for path in paths]
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
function getcachedpaths(ibnf::IBNFramework, globaledge::GlobalEdge)
    cachedresults = getcachedresults(getintcompalg(ibnf))
    srcglobalnode = src(globaledge)
    srclocalnode = getlocalnode(getibnag(ibnf), srcglobalnode)
    dstglobalnode = dst(globaledge)
    dstlocalnode = getlocalnode(getibnag(ibnf), dstglobalnode)
    localedge = Edge(srclocalnode, dstlocalnode)
    paths = cachedresults.yenpathsdict[localedge]
    return paths
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

# TODO : tomorrow add AvailabilityConstraint and network operator UUID
struct ConnectionData
    availabilityconstraint::Union{Nothing,AvailabilityConstraint}
    updowntimesndatetime::UpDownTimesNDatetime{IntentState.T}
end

function getavailabilityconstraint(cd::ConnectionData)
    return cd.availabilityconstraint

end
function getupdowntimesndatetime(cd::ConnectionData)
    return cd.updowntimesndatetime
end

const CrossConnections = Dict{GlobalEdge, Dict{UUID, ConnectionData}}

struct CrossConnectionID 
    globaledge::GlobalEdge
    intentuuid::UUID
end

function CrossConnectionID(str::String)
    pattern = r"^([0-9a-fA-F]+)\.([0-9]+)=>([0-9a-fA-F]+)\.([0-9]+)\|([0-9a-fA-F]+)$"

    m = match(pattern, str)

    isnothing(m) && error("Invalid CrossConnectionID string format: \"$str\"")

    src_ibnfid_hex, src_localnode_dec, dst_ibnfid_hex, dst_localnode_dec, intentuuid_hex = m.captures

    src_ibnfid_val = parse(UInt128, src_ibnfid_hex, base=16)
    dst_ibnfid_val = parse(UInt128, dst_ibnfid_hex, base=16)
    intentuuid_val = parse(UInt128, intentuuid_hex, base=16)

    src_localnode_val = parse(Int, src_localnode_dec)
    dst_localnode_val = parse(Int, dst_localnode_dec)
    src_ibnfid = UUID(src_ibnfid_val)
    dst_ibnfid = UUID(dst_ibnfid_val)

    src_node = GlobalNode(src_ibnfid, src_localnode_val)
    dst_node = GlobalNode(dst_ibnfid, dst_localnode_val)

    ge = GlobalEdge(src_node, dst_node)

    uuid = UUID(intentuuid_val)

    return CrossConnectionID(ge, uuid)
end

function getcrossconnectionid_srcdstnode(str::String)
    pattern = r"^([0-9a-fA-F]+)\.([0-9]+)=>([0-9a-fA-F]+)\.([0-9]+)\|[0-9a-fA-F]+$"

    m = match(pattern, str)

    isnothing(m) && error("Invalid CrossConnectionID string format: \"$str\"")

    src_ibnfid_hex, src_localnode_dec, dst_ibnfid_hex, dst_localnode_dec = m.captures

    src_ibnfid_val = parse(UInt128, src_ibnfid_hex, base=16)
    dst_ibnfid_val = parse(UInt128, dst_ibnfid_hex, base=16)
    src_localnode_val = parse(Int, src_localnode_dec)
    dst_localnode_val = parse(Int, dst_localnode_dec)
    src_ibnfid = UUID(src_ibnfid_val)
    dst_ibnfid = UUID(dst_ibnfid_val)

    src_node = GlobalNode(src_ibnfid, src_localnode_val)
    dst_node = GlobalNode(dst_ibnfid, dst_localnode_val)
    return src_node, dst_node
end

function stringify(conid::CrossConnectionID)
	io = IOBuffer();
	ge = getglobaledge(conid)
	
	@printf(io, "%0.0x.", getibnfid(src(ge)).value)
	@printf(io, "%0.0d=>", getlocalnode(src(ge)))
	@printf(io, "%0.0x.", getibnfid(dst(ge)).value)
	@printf(io, "%0.0d|", getlocalnode(dst(ge)))
	@printf(io, "%0.0x", getintentuuid(conid).value)

	return String(take!(io))
end

function getglobaledge(ccid::CrossConnectionID)
    return ccid.globaledge
end

function getintentuuid(ccid::CrossConnectionID)
    return ccid.intentuuid
end

function getconnection(ibnf::IBNFramework, ccid::CrossConnectionID)
    cc = getloginterupdowntimes(getbasicalgmem(getintcompalg(ibnf)))
    getupdowntimesndatetime(cc[getglobaledge(ccid)][getintentuuid(ccid)])
end

function getconnection(cc::CrossConnections, ccid::CrossConnectionID)
    getupdowntimesndatetime(cc[getglobaledge(ccid)][getintentuuid(ccid)])
end

function getallconnectionpairs_geavcon(ibnf::IBNFramework; crossdomainibnfid=nothing)
    loginterupdowntimes = getloginterupdowntimes(getbasicalgmem(getintcompalg(ibnf)));
    geavconpairs = Vector{Pair{GlobalEdge, AvailabilityConstraint}}()
    for (ge,dic) in loginterupdowntimes 
        if !isnothing(crossdomainibnfid)
            if getibnfid(src(ge)) != crossdomainibnfid || getibnfid(dst(ge)) != crossdomainibnfid
                continue
            end
        end
        for (_, condata) in dic
	    avcon = getavailabilityconstraint(condata)
            push!(geavconpairs, ge => avcon)
        end
    end
    return geavconpairs
end

function getallconnectionpairs(ibnf::IBNFramework; crossdomainibnfid=nothing)
    loginterupdowntimes = getloginterupdowntimes(getbasicalgmem(getintcompalg(ibnf)));
    allcrossconnectionswithconnectionid = Vector{Pair{String, UpDownTimesNDatetime{IntentState.T}}}()
    for (ge,dic) in loginterupdowntimes 
        if !isnothing(crossdomainibnfid)
            if getibnfid(src(ge)) != crossdomainibnfid || getibnfid(dst(ge)) != crossdomainibnfid
                continue
            end
        end
        for (intentuuid, condata) in dic
	    updtimes = getupdowntimesndatetime(condata)
            push!(allcrossconnectionswithconnectionid, stringify(CrossConnectionID(ge,intentuuid)) => updtimes)
        end
    end
    return allcrossconnectionswithconnectionid
end

function getallcrossconnectionids(ibnf::IBNFramework)
    loginterupdowntimes = getloginterupdowntimes(getbasicalgmem(getintcompalg(ibnf)));
    return [CrossConnectionID(ge,intentuuid) for (ge,dic) in loginterupdowntimes for (intentuuid, _) in dic];
end

function getallcrossconnectionidsstr(ibnf::IBNFramework; crossdomainibnfid=nothing)
    loginterupdowntimes = getloginterupdowntimes(getbasicalgmem(getintcompalg(ibnf)));
    retval = String[]
    for (ge,dic) in loginterupdowntimes 
        if !isnothing(crossdomainibnfid)
            if getibnfid(src(ge)) != crossdomainibnfid || getibnfid(dst(ge)) != crossdomainibnfid
                continue
            end
        end
        for (intentuuid, _) in dic
            push!(retval, stringify(CrossConnectionID(ge,intentuuid)))
        end
    end
    return retval
end

function getallconnectionsdict(ibnf::IBNFramework; crossdomainibnfid=nothing)
    allconnectionpairs = getallconnectionpairs(ibnf; crossdomainibnfid)
    allconnectiondict = Dict(k => v for (k,v) in allconnectionpairs)
    return allconnectiondict
end

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
    loginterupdowntimes::CrossConnections
end

function BasicAlgorithmMemory()
    return BasicAlgorithmMemory(now(), Dict{Edge{LocalNode}, Dict{Vector{Vector{LocalNode}}, Int}}(), CrossConnections())
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
function getdatetime(intcompalg::IntentCompilationAlgorithm)
    return intcompalg.datetime
end

"""
$(TYPEDSIGNATURES)
"""
function setdatetime!(intcompalg::IntentCompilationAlgorithm, currentdatetime::DateTime)
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
	avcon = getfirst(x -> x isa AvailabilityConstraint, getconstraints(conintent))
        logstates = getlogstate(idagnode)
        updowntimesndatetime = getupdowntimes(logstates, getdatetime(getbasicalgmem(intentcomp)))
        if getcurrentstate(getlogstate(getidagnode(getidag(ibnf), getidagnodeid(idagnode)))) == IntentState.Installed
            distance = pingdistanceconnectivityintent(ibnf, getidagnodeid(idagnode))
            @assert !isinf(ustrip(distance))
            setconnectiondistance!(updowntimesndatetime, distance)
        end

        globaledge = GlobalEdge(sourcenode, destinationnode) 
        loginterupdowntimes = getloginterupdowntimes(intentcomp)
        if haskey(loginterupdowntimes, globaledge)
	    getloginterupdowntimes(intentcomp)[GlobalEdge(sourcenode, destinationnode)][getidagnodeid(idagnode)] = ConnectionData(avcon, updowntimesndatetime)
        else
	    getloginterupdowntimes(intentcomp)[GlobalEdge(sourcenode, destinationnode)] = Dict{UUID, ConnectionData}(getidagnodeid(idagnode) => ConnectionData(avcon, updowntimesndatetime))
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
    idagnodeids = getidagnodeid.(getidagnodes(getidag(ibnf)))
    setdatetime!(getbasicalgmem(intentcomp), @logtime)
    currentdatetime = getdatetime(getbasicalgmem(intentcomp))
    for dictuuidupdowndatetime in values(getloginterupdowntimes(intentcomp))
        for (intentuuid, connectiondata) in dictuuidupdowndatetime
	    updownndatetime = getupdowntimesndatetime(connectiondata)
            if intentuuid in idagnodeids
                if currentdatetime > getdatetime(updownndatetime)
                    logstates = getlogstate(getidagnode(getidag(ibnf), intentuuid))
                    updateupdowntimes!(updownndatetime, logstates, currentdatetime)

                    # update distance in case it changed
                    if getcurrentstate(getlogstate(getidagnode(getidag(ibnf), intentuuid))) == IntentState.Installed
                        # @show getibnfid(ibnf), intentuuid
                        distance = pingdistanceconnectivityintent(ibnf, intentuuid)
			# inf means it's failed intent
                        if !isinf(ustrip(distance))
			    prevdistance = getconnectiondistance(updownndatetime)
			    setconnectiondistance!(updownndatetime, (distance+prevdistance)/2)
			end
                    end
                end
            end
        end
    end
end
