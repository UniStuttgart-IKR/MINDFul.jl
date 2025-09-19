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
mutable struct BestEmpiricalAvailabilityCompilation <: IntentCompilationAlgorithmWithMemory
    "How many k paths to check"
    candidatepathsnum::Int
    """
    How many m paths to consider for joint protection.
    It investigates all possible pair of the first m paths
    """
    pathsforprotectionnum::Int
    "cached information"
    cachedresults::CachedResults
    "The algorithm memory that is updated"
    basicalgmem::BasicAlgorithmMemory
end

const IBNFrameworkBEA = IBNFramework{A,B,C,D,BestEmpiricalAvailabilityCompilation} where {A,B,C,D}

function BestEmpiricalAvailabilityCompilation(ibnag::IBNAttributeGraph, candidatepathsnum::Int, pathforprotectionnum::Int)
    cachedresults = CachedResults(ibnag, candidatepathsnum)
    return BestEmpiricalAvailabilityCompilation(candidatepathsnum, pathforprotectionnum, cachedresults, BasicAlgorithmMemory())
end

function BestEmpiricalAvailabilityCompilation(candidatepathnum::Int, pathsforprotectionnum::Int; nodenum)
    return BestEmpiricalAvailabilityCompilation(candidatepathnum, pathsforprotectionnum, CachedResults(nodenum), BasicAlgorithmMemory())
end

function BestEmpiricalAvailabilityCompilation(beacomp::BestEmpiricalAvailabilityCompilation, cachedresults::CachedResults)
    return BestEmpiricalAvailabilityCompilation(beacomp.candidatepathsnum, beacomp.pathsforprotectionnum, cachedresults, BasicAlgorithmMemory())
end


"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFrameworkBEA, idagnode::IntentDAGNode{<:ConnectivityIntent}; verbose::Bool = false)
    setdatetime!(getbasicalgmem(getintcompalg(ibnf)), @logtime)
    intradomaincompilationalg = intradomaincompilationtemplate(
        prioritizepaths = prioritizepaths_bestempiricalavailability,
        prioritizegrooming = prioritizegrooming_exactly,
        prioritizerouterport = prioritizerouterports_lowestrate,
        prioritizetransmdlandmode = prioritizetransmdlmode_cheaplowrate,
        choosespectrum = choosespectrum_firstfit,
        chooseoxcadddropport = chooseoxcadddropport_first,
    )
    compileintenttemplate!(
        ibnf, idagnode;
        verbose,
        intradomainalgfun = intradomaincompilationalg,
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
Constrained to return protection only up to 2 paths
"""
function prioritizepaths_bestempiricalavailability(ibnf::IBNFrameworkBEA, idagnode::IntentDAGNode{<:ConnectivityIntent})

    priorityprotectionpaths = Vector{Vector{Vector{LocalNode}}}()

    ibnag = getibnag(ibnf)
    sourcelocalnode = getlocalnode(ibnag, getsourcenode(getintent(idagnode)))
    destlocalnode = getlocalnode(ibnag, getdestinationnode(getintent(idagnode)))

    intentcomp = getintcompalg(ibnf)

    yenstatepaths = getyenpathsdict(getcachedresults(intentcomp))[Edge(sourcelocalnode, destlocalnode)]

    operatingpaths = filter(yenstatepaths) do path
        all(edgeify(path)) do ed
            getcurrentlinkstate(ibnf, ed; checkfirst = true)
        end
    end

    availabilityconstraint = getfirst(x -> x isa AvailabilityConstraint, getconstraints(getintent(idagnode)))
    isnothing(availabilityconstraint) && return [[opel] for opel in operatingpaths]

    dictlinkempiricalavail = getdictlinkempiricalavailabilities(ibnf; endtime = getdatetime(getbasicalgmem(intentcomp)))
    pathempavail = Float64[]
    for op in operatingpaths
        pathempavailop = reduce(*, [dictlinkempiricalavail[e] for e in edgeify(op)])
        if pathempavailop > getavailabilityrequirement(availabilityconstraint)
            push!(priorityprotectionpaths, [op])
            push!(pathempavail, pathempavailop)
        end
    end

    kprotectedpaths = yenstatepaths[1:getpathsforprotectionnum(intentcomp)]
    for i1 in eachindex(kprotectedpaths)
        path1 = yenstatepaths[i1]
        for i2 in i1+1:length(kprotectedpaths)
            path2 = yenstatepaths[i2]
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
function prioritizegrooming_exactly(ibnf::IBNFrameworkBEA, idagnode::IntentDAGNode{<:ConnectivityIntent}; candidatepaths::Vector{Vector{Vector{LocalNode}}} = Vector{Vector{Vector{LocalNode}}}())
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
function choosegroominornot(ibnf::IBNFrameworkBEA, protectedpaths::Vector{Vector{LocalNode}}, pi::Int, shortestpathdists::Matrix, groomingpossibility::Vector{Union{UUID, Edge{Int}}})
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
"""
function estimateintraconnectionavailability(ibnf::IBNFrameworkBEA, srclocalnode::LocalNode, dstlocalnode::LocalNode)
    ed = Edge(srclocalnode, dstlocalnode)
    intentcomp = getintcompalg(ibnf)
    logintrapaths =  getlogintrapaths(intentcomp)
    if haskey(logintrapaths, ed)
        pastpathsdict = logintrapaths[Edge(srclocalnode, dstlocalnode)]
        ppathavails = [getempiricalavailability(ibnf, ppath; endtime=getdatetime(getbasicalgmem(intentcomp))) for ppath in keys(pastpathsdict)]
        counts = values(pastpathsdict)
    else
        yenstatepaths = getyenpathsdict(getcachedresults(intentcomp))[Edge(srclocalnode, dstlocalnode)]

        ppathavails = [getempiricalavailability(ibnf, path; endtime=getdatetime(getbasicalgmem(intentcomp))) for path in yenstatepaths]
        counts = fill(1, length(ppathavails))
    end
    return uniquesupportweightsDiscreteNonParametric(ppathavails, counts)
end

"""
$(TYPEDSIGNATURES)
"""
function estimatecrossconnectionavailability(ibnf::IBNFrameworkBEA, srcglobalnode::GlobalNode, dstglobalnode::GlobalNode)
    ged = GlobalEdge(srcglobalnode, dstglobalnode)
    loginterupdowntimes = getloginterupdowntimes(getintcompalg(ibnf))
    if haskey(loginterupdowntimes, ged) 
        updowntimesndatetimedict = loginterupdowntimes[ged]
        updowntimesndatetimes = values(updowntimesndatetimedict)
        externalintentavails = [calculateavailability(updowntimesndatetime) for updowntimesndatetime in updowntimesndatetimes]
        weights = [sum(getuptimes(updowntimesndatetime)) + sum(getdowntimes(updowntimesndatetime))  for updowntimesndatetime in updowntimesndatetimes]
        dnp = uniquesupportweightsDiscreteNonParametric(externalintentavails, weights)
    else
        externalintentavails = [1.0]
        counts = [1]
        dnp = uniquesupportweightsDiscreteNonParametric(externalintentavails, counts)
    end
    return dnp
end

"""
$(TYPEDSIGNATURES)

`quantile(::DiscreteNonParametric, q)` gives smallest value `x` such that `cdf(::DiscreteNonParatetric, x) >= q`
This means that there is `x` is the biggest value for `q`% of `::DiscreteNonParametric`.
For example, `q=0.95` means that `x` will be bigger than 95% of the support of `::DiscreteNonParametric`.
`cquantile` is exactly the opposite implying that it would be smaller than 95% of the support.
For example, now talking availability requirements and compliance targets,  

"""
function chooseintrasplitavailabilities(avcon::AvailabilityConstraint, firsthalfavailability::DiscreteNonParametric, secondhalfavailability::DiscreteNonParametric, beacomp::BestEmpiricalAvailabilityCompilation)
    availabilityrequirement = getavailabilityrequirement(avcon)
    compliancetarget = getcompliancetarget(avcon)

    sqrtcompliancetarget = sqrt(compliancetarget)

    firsthalfmutavailabilityconstraint = MutableAvailabilityConstraint(0.0, 0.0) 
    secondhalfmutavailabilityconstraint = MutableAvailabilityConstraint(0.0, 0.0) 

    combinationfound = false
    # begin from 100 % compliance target
    for firstct in 1:-0.01:compliancetarget
        setcompliancetarget!(firsthalfmutavailabilityconstraint, firstct)
        firstavailabilityrequirement = cquantile(firsthalfavailability, firstct)
        setavailabilityrequirement!(firsthalfmutavailabilityconstraint, firstavailabilityrequirement)

        secondcompliancetargetlimit = compliancetarget / firstct
        for secondct in 1:-0.01:secondcompliancetargetlimit
            setcompliancetarget!(secondhalfmutavailabilityconstraint, secondct)
            secondavailabilityrequirement = cquantile(secondhalfavailability, secondct)
            setavailabilityrequirement!(secondhalfmutavailabilityconstraint, secondavailabilityrequirement)

            if firstavailabilityrequirement * secondavailabilityrequirement >= availabilityrequirement
                combinationfound = true
                break
            end
        end
        combinationfound && break
    end

    # Take leap of fath for external domain if current estimations are not enough (explore) by giving half compliance target for each domain
    if !combinationfound
        setcompliancetarget!(firsthalfmutavailabilityconstraint, sqrtcompliancetarget)
        firstavailabilityrequirement = cquantile(firsthalfavailability, sqrtcompliancetarget)
        setavailabilityrequirement!(firsthalfmutavailabilityconstraint, firstavailabilityrequirement)

        setcompliancetarget!(secondhalfmutavailabilityconstraint, sqrtcompliancetarget)
        secondavailabilityrequirement = availabilityrequirement / firstavailabilityrequirement
        setavailabilityrequirement!(secondhalfmutavailabilityconstraint, secondavailabilityrequirement)
    end

    firsthalfavailabilityconstraint = AvailabilityConstraint(getavailabilityrequirement(firsthalfmutavailabilityconstraint), getcompliancetarget(firsthalfmutavailabilityconstraint)) 
    secondhalfavailabilityconstraint = AvailabilityConstraint(getavailabilityrequirement(secondhalfmutavailabilityconstraint), getcompliancetarget(secondhalfmutavailabilityconstraint)) 
    return firsthalfavailabilityconstraint, secondhalfavailabilityconstraint
end

"""
$(TYPEDSIGNATURES)
"""
function choosecrosssplitavailabilities(avcon::AvailabilityConstraint, firsthalfavailability, secondhalfavailability, beacomp::BestEmpiricalAvailabilityCompilation)
    return chooseintrasplitavailabilities(avcon, firsthalfavailability, secondhalfavailability, beacomp)
end
