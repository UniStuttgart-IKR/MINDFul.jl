"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct BestEmpiricalAvailabilityCompilation <: IntentCompilationAlgorithm
    "How many k paths to check"
    candidatepathsnum::Int
    """
    How many m paths to consider for joint protection.
    It investigates all possible pair of the first m paths
    """
    pathsforprotectionnum::Int
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
    intradomaincompilationalg = intradomaincompilationtemplate(
        prioritizepaths = prioritizepaths_shortest,
        prioritizegrooming = prioritizegrooming_default,
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
    priorityprotectionpaths = Vector{Vector{LocalNode}}()

    ibnag = getibnag(ibnf)
    distweights = getweights(ibnag)
    sourcelocalnode = getlocalnode(ibnag, getsourcenode(getintent(idagnode)))
    destlocalnode = getlocalnode(ibnag, getdestinationnode(getintent(idagnode)))

    if sourcelocalnode == destlocalnode
        yenstate = Graphs.YenState([u"0.0km"], [[destlocalnode]])
    else
        yenstate = Graphs.yen_k_shortest_paths(ibnag, sourcelocalnode, destlocalnode, distweights, MINDF.getcandidatepathsnum(beacomp))
    end

    operatingpaths = filter(yenstate.paths) do path
        all(edgeify(path)) do ed
            getcurrentlinkstate(ibnf, ed; checkfirst = true)
        end
    end

    dictlinkempiricalavail = MINDF.getdictlinkempiricalavailabilities(ibnf; endtime = getcurrentdatetime(beacomp))
    pathempavail = [reduce(*, [dictlinkempiricalavail[e] for e in edgeify(op)] ) for op in operatingpaths]
    for op in operatingpaths
        push!(priorityprotectionpaths, [op])
    end

    kprotectedpaths = yenstate.paths[1:getpathsforprotectionnum(beacomp)]
    for i1 in eachindex(kprotectedpaths)
        path1 = yenstate.paths[i1]
        for i2 in i1+1:length(kprotectedpaths)
            path2 = yenstate.paths[i2]
            edges1 = edgeify(path1)
            avails1 = [calculateavailability(edgemttfmttrdict[ed]) for ed in edges1]
            edges2 = edgeify(path2)
            avails2 = [calculateavailability(edgemttfmttrdict[ed]) for ed in edges2]
            if !any(x -> x isa MINDF.OpticalTerminateConstraint, getintent(idagnode))
                # protection with optical terminate requires that last link is the same (such that the protected paths terminate similarly)
                if path1[end-1] == path2[end-1] && path1[end] == path2[end]
                    push!(pathempavail, MINDF.calculateprotectedpathavailability(edges1, avails1, edges2, avails2))
                    push!(priorityprotectionpaths, [path1, path2])
                end
            else
                push!(pathempavail, MINDF.calculateprotectedpathavailability(edges1, avails1, edges2, avails2))
                push!(priorityprotectionpaths, [path1, path2])
            end
        end
    end


    availabilityconstraint = getfirst(x -> x isa MINDF.AvailabilityConstraint, getintent(idagnode))
    if isnothing(availabilityconstraint)
        availabilityrequirement = getavailabilityrequirement(availabilityconstraint)
        # pick best availability match
        sp = sortperm(pathempavail; by = x -> abs(availabilityrequirement - x))
    else
        sp = eachindex(pathempavail)
    end

    # prioritize based on highest availability
    return operatingpaths[sp]
end
