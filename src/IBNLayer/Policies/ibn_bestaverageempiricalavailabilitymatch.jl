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
mutable struct BestAverageEmpiricalAvailabilityCompilation <: IntentCompilationAlgorithmWithMemory
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

const IBNFrameworkBAEA = IBNFramework{O,S,T,I,R} where {O <: AbstractOperationMode, S <: AbstractSDNController, T <: IBNAttributeGraph, I <: IBNFCommunication,R<:BestAverageEmpiricalAvailabilityCompilation}
# const IBNFrameworkBAEA = IBNFramework{O,S,T,I,BestAverageEmpiricalAvailabilityCompilation} where {O,S,T,I}

function BestAverageEmpiricalAvailabilityCompilation(ibnag::IBNAttributeGraph, candidatepathsnum::Int, pathforprotectionnum::Int)
    cachedresults = CachedResults(ibnag, candidatepathsnum)
    return BestAverageEmpiricalAvailabilityCompilation(candidatepathsnum, pathforprotectionnum, cachedresults, BasicAlgorithmMemory())
end

function BestAverageEmpiricalAvailabilityCompilation(candidatepathnum::Int, pathsforprotectionnum::Int; nodenum)
    return BestAverageEmpiricalAvailabilityCompilation(candidatepathnum, pathsforprotectionnum, CachedResults(nodenum), BasicAlgorithmMemory())
end

function BestAverageEmpiricalAvailabilityCompilation(beacomp::BestAverageEmpiricalAvailabilityCompilation, cachedresults::CachedResults)
    return BestAverageEmpiricalAvailabilityCompilation(beacomp.candidatepathsnum, beacomp.pathsforprotectionnum, cachedresults, BasicAlgorithmMemory())
end


"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFrameworkBAEA, idagnode::IntentDAGNode{<:ConnectivityIntent}; verbose::Bool = false)
    intradomaincompilationalg = intradomaincompilationtemplate(
        prioritizepaths = prioritizepaths_stochasticavailability,
        prioritizegrooming = prioritizegrooming_default,
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
        maximumsplitlevel = 1,
        @passtime
    )
end



"""
$(TYPEDSIGNATURES)
"""
function estimateintraconnectionavailability(ibnf::IBNFrameworkBAEA, srclocalnode::LocalNode, dstlocalnode::LocalNode, ::Val=Val(:distribution); servicetime=nothing)
    ed = Edge(srclocalnode, dstlocalnode)
    intentcomp = getintcompalg(ibnf)
    logintrapaths =  getlogintrapaths(intentcomp)
    # mean 
    if haskey(logintrapaths, ed)
        pastpathsdict = logintrapaths[Edge(srclocalnode, dstlocalnode)]
        ppathavails = [getempiricalavailability(ibnf, ppath; endtime=getdatetime(getbasicalgmem(intentcomp))) for ppath in keys(pastpathsdict)]
        counts = collect(values(pastpathsdict))
    else
        yenstatepaths = getyenpathsdict(getcachedresults(intentcomp))[Edge(srclocalnode, dstlocalnode)]

        ppathavails = [getempiricalavailability(ibnf, path; endtime=getdatetime(getbasicalgmem(intentcomp))) for path in yenstatepaths]
        counts = fill(1, length(ppathavails))
    end
    return mean(uniquesupportweightsDiscreteNonParametric(ppathavails, counts))
end

"""
$(TYPEDSIGNATURES)
"""
function estimatecrossconnectionavailability(ibnf::IBNFrameworkBAEA, ged::GlobalEdge, ::Val=Val(:distribution); servicetime=nothing)
    loginterupdowntimes = getloginterupdowntimes(getintcompalg(ibnf))
    if src(ged) == dst(ged)
        externalintentavails = [1.0]
        counts = [1]
        dnp = uniquesupportweightsDiscreteNonParametric(externalintentavails, counts)
    elseif haskey(loginterupdowntimes, ged) 
        updowntimesndatetimedict = loginterupdowntimes[ged]
	updowntimesndatetimes = getupdowntimesndatetime.(values(updowntimesndatetimedict))
        externalintentavails = [calculateavailability(updowntimesndatetime) for updowntimesndatetime in updowntimesndatetimes]
        weights = [sum(getuptimes(updowntimesndatetime)) + sum(getdowntimes(updowntimesndatetime)) for updowntimesndatetime in updowntimesndatetimes]
        fa = findall(isnan, externalintentavails)
        if length(fa) == length(updowntimesndatetimes)
            externalintentavails = [1.0]
            counts = [1]
            dnp = uniquesupportweightsDiscreteNonParametric(externalintentavails, counts)
        else
            deleteat!(externalintentavails, fa)
            deleteat!(weights, fa)
            dnp = uniquesupportweightsDiscreteNonParametric(externalintentavails, weights)
        end
    else
        externalintentavails = [1.0]
        counts = [1]
        dnp = uniquesupportweightsDiscreteNonParametric(externalintentavails, counts)
    end
    return mean(dnp)
end

"""
$(TYPEDSIGNATURES)
"""
function choosecrosssplitavailabilities(avcon::AvailabilityConstraint, firsthalfavailability, secondhalfavailability, beacomp::BestAverageEmpiricalAvailabilityCompilation)
    return chooseintrasplitavailabilities(avcon, firsthalfavailability, secondhalfavailability, beacomp)
end

# --------------------------- Estimating availability ------------------------------
# Estimation is a DiscreteNonParametric

function initializeestimateavailability(ibnf::IBNFrameworkBAEA, ::Val=Val(:distribution))
    return 1.0
end

function estimatepathavailability(ibnf::IBNFrameworkBAEA, path::Vector{LocalNode}, ::Val=Val(:distribution); servicetime=nothing)
    empav = getempiricalavailability(ibnf, path; endtime = getdatetime(getbasicalgmem(getintcompalg(ibnf))))
    return empav
end

function estimateprpathavailability(ibnf::IBNFrameworkBAEA, prpath::Vector{Vector{LocalNode}}, ::Val=Val(:distribution); servicetime=nothing)
    empav = getempiricalavailability(ibnf, prpath; endtime = getdatetime(getbasicalgmem(getintcompalg(ibnf))))
    return empav
end

"""
$(TYPEDSIGNATURES)

Must always return a AvailabilityConstraint

Assumes equal compliance target split
"""
function calcsecondhalfavailabilityconstraint(ibnf::IBNFrameworkBAEA, firsthalfavailability::DiscreteNonParametric, masteravconstr::AvailabilityConstraint)
    return calcsecondhalfavailabilityconstraint_defaultstochastic(ibnf, firsthalfavailability, masteravconstr)
end
