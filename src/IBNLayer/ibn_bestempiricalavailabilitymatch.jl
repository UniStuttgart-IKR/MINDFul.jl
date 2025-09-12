# Rules for current implementation
#
# 1. ProtectedLightpathIntent cannot use grooming other than another single ProtectedLightIntent
# 2. ProtectedLightpathIntent children (LightpathIntents) cannot be grommed, but the ProtectedLightpathIntent can.
# 3. Grooming an availability-aware intent is possible to do using O-E-O grooming (many groomed intents along the way)
# 4. Groomign an availability-aware intent meant to use protection cannot use grooming (like 1.)



"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
mutable struct BestEmpiricalAvailabilityCompilation <: IntentCompilationAlgorithm
    "How many k paths to check"
    candidatepathsnum::Int
    """
    How many m paths to consider for joint protection.
    It investigates all possible pair of the first m paths
    """
    pathsforprotectionnum::Int
    """
    The simulated (or not) current datetime. 
    It's used by the algorithm to build the uptime/downtime data
    """
    datetime::DateTime
    # TODO : think: maybe delete ?
    "The intents used to fill `logintrapaths`, correspond to either `LightpathIntent` or `ProtectedLightpathIntent`"
    logintraintentsuuid::Vector{UUID}
    """
    Log here the selection of (protection) path for an intra node (+ border) intent after install. 
    Add new elements upon installation
    A new path `Vector{Vector{LocalNode}} is added per node pair and counted how many times was it used`
    """
    logintrapaths::Dict{Edge{LocalNode}, Dict{Vector{Vector{LocalNode}}, Int}}
    """
    The intents used to fill `logintetupdowntimes`, corresponds to a cross-domain `ConnectivityIntent` as keys.
    Values are the last log state considered. if there are more, the `UpDownTimes` of `loginterupdowntimes` are updated.
    """
    # TODO : tomorrow: deleted: loginterintentsuuid::Vector{UUID}
    """
    Log here the up/downtimes of border-node to cross node.
    Add new elements upon installation.
    Update entries upon compilation.
    All UUIDs correspond to Remote Connectivity intents
    """
    loginterupdowntimes::Dict{GlobalEdge, Dict{UUID, UpDownTimesNDatetime}}
    # TODO : tomorrow made UpdDownTimesNDatatime -> Dict
end

function BestEmpiricalAvailabilityCompilation(candidatepathsnum::Int, pathforprotectionnum::Int)
    return BestEmpiricalAvailabilityCompilation(candidatepathsnum, pathforprotectionnum, now(), Vector{UUID}(), Dict{Edge{LocalNode}, Dict{Vector{Vector{LocalNode}}, Int}}(), Dict{GlobalEdge, Dict{UUID, UpDownTimesNDatetime}}())
end


"""
$(TYPEDSIGNATURES) 

"""
function logintrapathsandinterintents!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcomp::IntentCompilationAlgorithm)
    intentuuidsalreadyaccessed = UUID[]
    # traverse intent DAG
    for childidagnode in getidagnodechildren(getidag(ibnf),idagnode)
        _rec_logintrapathsandinterintents!(ibnf::IBNFramework, childidagnode, intentcomp::IntentCompilationAlgorithm, intentuuidsalreadyaccessed)
    end
end

function _rec_logintrapathsandinterintents!(ibnf::IBNFramework, idagnode::IntentDAGNode, intentcomp::IntentCompilationAlgorithm, intentuuidsalreadyaccessed::Vector{UUID})
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
    elseif intent isa RemoteIntent
        conintent = getintent(intent)
        sourcenode = getsourcenode(conintent)
        destinationnode = getdestinationnode(conintent)
        logstates = getlogstate(idagnode)
        updowntimes = getupdowntimes(logstates, getdatetime(intentcomp))
        globaledge = GlobalEdge(sourcenode, destinationnode) 
        loginterupdowntimes = getloginterupdowntimes(intentcomp)
        if haskey(loginterupdowntimes, globaledge)
            getloginterupdowntimes(intentcomp)[GlobalEdge(sourcenode, destinationnode)][getidagnodeid(idagnode)] = UpDownTimesNDatetime(getuptimes(updowntimes), getdowntimes(updowntimes), getdatetime(intentcomp))
        else
            getloginterupdowntimes(intentcomp)[GlobalEdge(sourcenode, destinationnode)] = Dict{UUID, UpDownTimesNDatetime}(getidagnodeid(idagnode) => UpDownTimesNDatetime(getuptimes(updowntimes), getdowntimes(updowntimes), getdatetime(intentcomp)))
        end
        continuedown = false
    end
    if continuedown
        for childidagnode in getidagnodechildren(getidag(ibnf), idagnode)
            _rec_logintrapathsandinterintents!(ibnf::IBNFramework, childidagnode, intentcomp::IntentCompilationAlgorithm, intentuuidsalreadyaccessed)
        end
    end
end

"""
$(TYPEDSIGNATURES)
"""
function updateloginterintent!(ibnf::IBNFramework, intentcomp::IntentCompilationAlgorithm)
    currentdatetime = getdatetime(intentcomp)
    for dictuuidupdowndatetime in values(getloginterupdowntimes(intentcomp))
        for (intentuuid, updownndatetime) in dictuuidupdowndatetime
            logstates = getlogstate(getidagnode(getidag(ibnf), intentuuid))
            getupdowntimes!(updownndatetime, logstates, currentdatetime)
        end
    end
end


"""
$(TYPEDSIGNATURES)
"""
function getlogintraintentsuuid(intentcomp::IntentCompilationAlgorithm)
    return intentcomp.logintraintentsuuid 
end

"""
$(TYPEDSIGNATURES)
"""
function getlogintrapaths(intentcomp::IntentCompilationAlgorithm)
    return intentcomp.logintrapaths 
end

"""
$(TYPEDSIGNATURES)
"""
function getloginterupdowntimes(intentcomp::IntentCompilationAlgorithm)
    return intentcomp.loginterupdowntimes 
end

"""
$(TYPEDSIGNATURES)
"""
function getcandidatepathsnum(beacomp::BestEmpiricalAvailabilityCompilation)
    return beacomp.candidatepathsnum
end

"""
$(TYPEDSIGNATURES)
"""
function getdatetime(beacomp::BestEmpiricalAvailabilityCompilation)
    return beacomp.datetime
end

"""
$(TYPEDSIGNATURES)
"""
function setdatetime!(beacomp::BestEmpiricalAvailabilityCompilation, currentdatetime::DateTime)
    return beacomp.datetime = currentdatetime
end

"""
$(TYPEDSIGNATURES)
"""
function getpathsforprotectionnum(beacomp::BestEmpiricalAvailabilityCompilation)
    return beacomp.pathsforprotectionnum
end

"The keyword for [BestEmpiricalAvailabilityCompilation](@ref)"
const BEAalg = :bestempiricalavailability

"""
$(TYPEDSIGNATURES)

Give back the algorithm mapped to the symbol
"""
function getcompilationalgorithmtype(s::Val{BEAalg})
    return BestEmpiricalAvailabilityCompilation
end

"""
$(TYPEDSIGNATURES)
"""
function getdefaultcompilationalgorithmargs(s::Val{BEAalg})
    return (5,5)
end

"""
$(TYPEDSIGNATURES)

Give back the symbol mapped to the algorithm
"""
function getcompilationalgorithmkeyword(::Type{BestEmpiricalAvailabilityCompilation})
    return BEAalg
end


"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, beacomp::BestEmpiricalAvailabilityCompilation; verbose::Bool = false)
    setdatetime!(beacomp, @logtime)
    # TODO : NOW: update loginterupdowntimes
    updateloginterintent!(ibnf, beacomp)
    intradomaincompilationalg = intradomaincompilationtemplate(
        prioritizepaths = prioritizepaths_bestempiricalavailability,
        prioritizegrooming = prioritizegrooming_exactly,
        prioritizerouterport = prioritizerouterports_lowestrate,
        prioritizetransmdlandmode = prioritizetransmdlmode_cheaplowrate,
        choosespectrum = choosespectrum_firstfit,
        chooseoxcadddropport = chooseoxcadddropport_first,
    )
    compileintenttemplate!(
        ibnf, idagnode, beacomp;
        verbose,
        intradomainalgfun = intradomaincompilationalg,
        externaldomainalgkeyword = getcompilationalgorithmkeyword(beacomp),
        prioritizesplitnodes = prioritizesplitnodes_longestfirstshortestpath,
        prioritizesplitbordernodes = prioritizesplitbordernodes_shortestorshortestrandom,
        @passtime
    )
end



"""
$(TYPEDSIGNATURES)

Return a `Vector{Vector{Int}}` vector of vector of paths.
Each element in the outer vector is a combination of paths to be used for protection.
The first path is supposed to be the one deployed and all other are the protection.
"""
function prioritizepaths_bestempiricalavailability(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, beacomp::BestEmpiricalAvailabilityCompilation)

    priorityprotectionpaths = Vector{Vector{Vector{LocalNode}}}()

    ibnag = getibnag(ibnf)
    distweights = getweights(ibnag)
    sourcelocalnode = getlocalnode(ibnag, getsourcenode(getintent(idagnode)))
    destlocalnode = getlocalnode(ibnag, getdestinationnode(getintent(idagnode)))

    if sourcelocalnode == destlocalnode
        yenstate = Graphs.YenState([u"0.0km"], [[destlocalnode]])
    else
        yenstate = Graphs.yen_k_shortest_paths(ibnag, sourcelocalnode, destlocalnode, distweights, getcandidatepathsnum(beacomp))
    end

    operatingpaths = filter(yenstate.paths) do path
        all(edgeify(path)) do ed
            getcurrentlinkstate(ibnf, ed; checkfirst = true)
        end
    end

    availabilityconstraint = getfirst(x -> x isa AvailabilityConstraint, getconstraints(getintent(idagnode)))
    isnothing(availabilityconstraint) && return [[opel] for opel in operatingpaths]

    dictlinkempiricalavail = getdictlinkempiricalavailabilities(ibnf; endtime = getdatetime(beacomp))
    pathempavail = Float64[]
    for op in operatingpaths
        pathempavailop = reduce(*, [dictlinkempiricalavail[e] for e in edgeify(op)])
        if pathempavailop > getavailabilityrequirement(availabilityconstraint)
            push!(priorityprotectionpaths, [op])
            push!(pathempavail, pathempavailop)
        end
    end

    kprotectedpaths = yenstate.paths[1:getpathsforprotectionnum(beacomp)]
    for i1 in eachindex(kprotectedpaths)
        path1 = yenstate.paths[i1]
        for i2 in i1+1:length(kprotectedpaths)
            path2 = yenstate.paths[i2]
            edges1 = edgeify(path1)
            avails1 = [dictlinkempiricalavail[ed] for ed in edges1]
            edges2 = edgeify(path2)
            avails2 = [dictlinkempiricalavail[ed] for ed in edges2]
            if !any(x -> x isa OpticalTerminateConstraint, getconstraints(getintent(idagnode)))
                # protection with optical terminate requires that last link is the same (such that the protected paths terminate similarly)
                if path1[end-1] == path2[end-1] && path1[end] == path2[end]
                    pathempavailop = calculateprotectedpathavailability(edges1, avails1, edges2, avails2)
                    if pathempavailop > getavailabilityrequirement(availabilityconstraint)
                        push!(priorityprotectionpaths, [path1, path2])
                        push!(pathempavail, pathempavailop)
                    end
                end
            else
                pathempavailop = calculateprotectedpathavailability(edges1, avails1, edges2, avails2)
                if pathempavailop > getavailabilityrequirement(availabilityconstraint)
                    push!(priorityprotectionpaths, [path1, path2])
                    push!(pathempavail, pathempavailop)
                end
            end
        end
    end

    availabilityrequirement = getavailabilityrequirement(availabilityconstraint)
    # pick best availability match
    sp = sortperm(pathempavail; by = x ->  x - availabilityrequirement)

    # prioritize based on highest availability
    @assert length(pathempavail) == length(priorityprotectionpaths)
    return priorityprotectionpaths[sp]
end


"""
$(TYPEDSIGNATURES)

Return suggestion that match exactly the candidatepaths, such that availability is not changed.
All the protection paths need to be matched exactly.
"""
function prioritizegrooming_exactly(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm; candidatepaths::Vector{Vector{Vector{LocalNode}}} = Vector{Vector{Vector{LocalNode}}}())
    intent = getintent(idagnode)
    srcglobalnode = getsourcenode(intent)
    dstglobalnode = getdestinationnode(intent)
    srcnode = getlocalnode(getibnag(ibnf), srcglobalnode)
    dstnode = getlocalnode(getibnag(ibnf), dstglobalnode)

    groomingpossibilities = Vector{Vector{Union{UUID, Edge{Int}}}}()

    if !(getibnfid(ibnf) == getibnfid(srcglobalnode) == getibnfid(dstglobalnode))
        if isbordernode(ibnf, srcglobalnode)
            any(x -> x isa OpticalInitiateConstraint, getconstraints(intent)) || return groomingpossibilities
        elseif isbordernode(ibnf, dstglobalnode)
            any(x -> x isa OpticalTerminateConstraint, getconstraints(intent)) || return groomingpossibilities
        else
            # cross domain intent
            # find lightpath combinations regardless of paths
            return groomingpossibilities
        end
    end

    # intentuuid => LightpathRepresentation
    installedlightpaths = collect(pairs(getinstalledlightpaths(getidaginfo(getidag(ibnf)))))
    filter!(installedlightpaths) do (lightpathuuid, lightpathrepresentation)
        getresidualbandwidth(ibnf, lightpathuuid, lightpathrepresentation; onlyinstalled = false) >= getrate(intent) &&
            getidagnodestate(getidag(ibnf), lightpathuuid) == IntentState.Installed
    end

    for protectedpaths in candidatepaths
        containedlightpaths = Vector{Vector{Int}}()
        containedlpuuids = UUID[]
        if length(protectedpaths) <= 1
            # can groom with OEO but still the path should be exactly the same
            candidatepath = protectedpaths[1]
            for (intentid, lightpathrepresentation) in installedlightpaths
                if length(getpath(lightpathrepresentation)) <= 1  # Protected paths will not be groomed
                    # have to find exactly the candidatepath
                    pathlightpathrepresentation = getpath(lightpathrepresentation)[1]
                    if issubpath(candidatepath, pathlightpathrepresentation)
                        opttermconstraint = getfirst(c -> c isa OpticalTerminateConstraint, getconstraints(intent))
                        if !isnothing(opttermconstraint)
                            if getterminatessoptically(lightpathrepresentation) && getdestinationnode(lightpathrepresentation) == getdestinationnode(opttermconstraint)
                                push!(containedlightpaths, pathlightpathrepresentation)
                                push!(containedlpuuids, intentid)
                            end
                        else
                            push!(containedlightpaths, pathlightpathrepresentation)
                            push!(containedlpuuids, intentid)
                        end
                    end
                end
            end
            # build up the possible OEO lightpaths
            # I want a combination of lightpaths in `containedlightpaths` such that exactly `candidatepath` is produced
            lightpathcollections = consecutivelightpathsidx(containedlightpaths, candidatepath)
            for lpcol in lightpathcollections
                push!(groomingpossibilities, Vector{Union{UUID, Edge{Int}}}( [containedlpuuids[lpcoli] for lpcoli in lpcol] ) )
            end
        else
            # need to find an installedlightpath with exactly this protection if any
            for (intentid, lightpathrepresentation) in installedlightpaths
                if length(getpath(lightpathrepresentation)) == length(protectedpaths)  # Protected paths will not be groomed
                    # have to find exactly the candidatepath
                    if all(pl -> pl[1] == pl[2], zip(protectedpaths, getpath(lightpathrepresentation)))
                        opttermconstraint = getfirst(c -> c isa OpticalTerminateConstraint, getconstraints(intent))
                        if !isnothing(opttermconstraint)
                            if getterminatessoptically(lightpathrepresentation) && getdestinationnode(lightpathrepresentation) == getdestinationnode(opttermconstraint)
                                push!(groomingpossibilities, Vector{Union{UUID, Edge{Int}}}( [intentid] ) )
                            end
                        else
                            push!(groomingpossibilities, Vector{Union{UUID, Edge{Int}}}( [intentid] ) )
                        end
                    end
                end
            end

        end
        # reorder exactlyinstalledlightpaths
    end

    sort!(groomingpossibilities; by=length)

    return groomingpossibilities
end

"""
Choose exactly the grooming for `protectedpaths`
If many  protectedpaths are passed, there can only be matched with a single protection lightpath intent that has the same paths
If just one path is passed, it can be broken down to several lightpaths but that must have the same nodes.
"""
function choosegroominornot(ibnf::IBNFramework, protectedpaths::Vector{Vector{LocalNode}}, pi::Int, shortestpathdists::Matrix, groomingpossibility::Vector{Union{UUID, Edge{Int}}}, beacomp::BestEmpiricalAvailabilityCompilation)
    any(x -> x isa Edge, groomingpossibility) && return false
    groomingpaths = [getpath(getinstalledlightpaths(getidaginfo(getidag(ibnf)))[intentuuid]) for intentuuid in groomingpossibility]
    if length(protectedpaths) == 1
        if all(p -> length(p) == 1, groomingpaths)
            concatenatedgroomingpath = unique(vcat(getindex.(groomingpaths, 1)...))
            if concatenatedgroomingpath == protectedpaths[1] 
                return true
            end
        end
        return false
    else
        if length(groomingpaths) == 1
            if length(groomingpaths[1]) == length(protectedpaths)
                return all(pl -> pl[1] == pl[2], zip(protectedpaths, groomingpaths[1]))
            end
        end
        return false
    end

    return false
end


"""
$(TYPEDSIGNATURES)

Estimate the end 2 end availability without knowing which path to take.
"""
function estimateend2endavailability(ibnf::IBNFramework, srcglobalnode::GlobalNode, dstglobalnode::GlobalNode, beacomp::BestEmpiricalAvailabilityCompilation)

end

"""
`firsthalfe2eavailability` and `secondhalfe2eavailability` are given from `estimateend2endavailability`
"""
function calculatefirstavailabilityconstrain(ibnf::IBNFramework, firsthalfe2eavailability, secondhalfe2eavailability, beacomp::BestEmpiricalAvailabilityCompilation)

end

function estimatepathavailability(ibnf::IBNFramework, idagnodeid::UUID, beacomp::BestEmpiricalAvailabilityCompilation)
end

"""
`firsthalfe2eavailability` is given from `estimatepathavailability`
"""
function calculatesecondavailabilityconstraint(ibnf::IBNFramework, firsthalfe2eavailability, beacomp::BestEmpiricalAvailabilityCompilation)

end

