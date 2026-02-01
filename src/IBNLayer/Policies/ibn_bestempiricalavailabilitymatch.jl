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

const IBNFrameworkBEA = IBNFramework{O,S,T,I,R} where {O <: AbstractOperationMode, S <: AbstractSDNController, T <: IBNAttributeGraph, I <: IBNFCommunication,R<:BestEmpiricalAvailabilityCompilation}
# const IBNFrameworkBEA = IBNFramework{O,S,T,I,BestEmpiricalAvailabilityCompilation} where {O,S,T,I}

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
function estimateintraconnectionavailability(ibnf::IBNFrameworkBEA, srclocalnode::LocalNode, dstlocalnode::LocalNode, ::Val=Val(:distribution); servicetime=nothing)
    ed = Edge(srclocalnode, dstlocalnode)
    intentcomp = getintcompalg(ibnf)
    logintrapaths =  getlogintrapaths(intentcomp)
    if haskey(logintrapaths, ed)
        pastpathsdict = logintrapaths[Edge(srclocalnode, dstlocalnode)]
        ppathavails = [getempiricalavailability(ibnf, ppath; endtime=getdatetime(getbasicalgmem(intentcomp))) for ppath in keys(pastpathsdict)]
        counts = collect(values(pastpathsdict))
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
function estimatecrossconnectionavailability(ibnf::IBNFrameworkBEA, ged::GlobalEdge, ::Val=Val(:distribution); servicetime=nothing)
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
    return chooseintrasplitavailabilities_defaultstochastic(avcon, firsthalfavailability, secondhalfavailability, beacomp)
end

"""
$(TYPEDSIGNATURES)
"""
function choosecrosssplitavailabilities(avcon::AvailabilityConstraint, firsthalfavailability, secondhalfavailability, beacomp::BestEmpiricalAvailabilityCompilation)
    return chooseintrasplitavailabilities(avcon, firsthalfavailability, secondhalfavailability, beacomp)
end

# --------------------------- Estimating availability ------------------------------
# Estimation is a DiscreteNonParametric

function initializeestimateavailability(ibnf::IBNFrameworkBEA, ::Val=Val(:distribution))
    return DiscreteNonParametric([1.0], [1.0])
end

function multavs(av1::DiscreteNonParametric, av2::DiscreteNonParametric)
    newsupport = [s1 * s2 for s1 in av1.support for s2 in av2.support]
    newps = [p1 * p2 for p1 in av1.p for p2 in av2.p]
    return uniquesupportweightsDiscreteNonParametric(newsupport, newps)
end

function multavs(av1::DiscreteNonParametric, av::Float64)
    newsupport = av1.support .* av
    return uniquesupportweightsDiscreteNonParametric(newsupport, av1.p)
end

function estimatepathavailability(ibnf::IBNFrameworkBEA, path::Vector{LocalNode}, ::Val=Val(:distribution); servicetime=nothing)
    empav = getempiricalavailability(ibnf, path; endtime = getdatetime(getbasicalgmem(getintcompalg(ibnf))))
    dnp = DiscreteNonParametric([empav], [1.0])
    return dnp
end

function estimateprpathavailability(ibnf::IBNFrameworkBEA, prpath::Vector{Vector{LocalNode}}, ::Val=Val(:distribution); servicetime=nothing)
    empav = getempiricalavailability(ibnf, prpath; endtime = getdatetime(getbasicalgmem(getintcompalg(ibnf))))
    dnp = DiscreteNonParametric([empav], [1.0])
    return dnp
end

"""
$(TYPEDSIGNATURES)

Must always return a AvailabilityConstraint

Assumes equal compliance target split
"""
function calcsecondhalfavailabilityconstraint(ibnf::IBNFrameworkBEA, firsthalfavailability::DiscreteNonParametric, masteravconstr::AvailabilityConstraint)
    return calcsecondhalfavailabilityconstraint_defaultstochastic(ibnf, firsthalfavailability, masteravconstr)
end
