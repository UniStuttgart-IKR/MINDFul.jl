"""
$(TYPEDEF)
$(TYPEDFIELDS)

Cannot handle AvailabilityConstraints and will fail with weird error
"""
struct KShorestPathFirstFitCompilation <: IntentCompilationAlgorithmWithMemory
    "How many k paths to check"
    candidatepathsnum::Int
    cachedresults::CachedResults
    basicalgmem::BasicAlgorithmMemory
end

const IBNFrameworkKSP = IBNFramework{A,B,C,D,R} where {A,B,C,D,R<:KShorestPathFirstFitCompilation}

"""
$(TYPEDSIGNATURES)
"""
function KShorestPathFirstFitCompilation(ibnag::IBNAttributeGraph, candidatepathnum::Int)
    cachedresults = CachedResults(ibnag, candidatepathnum)
    return KShorestPathFirstFitCompilation(candidatepathnum, cachedresults, BasicAlgorithmMemory())
end

function KShorestPathFirstFitCompilation(candidatepathnum::Int; nodenum)
    return KShorestPathFirstFitCompilation(candidatepathnum, CachedResults(nodenum), BasicAlgorithmMemory())
end

function KShorestPathFirstFitCompilation(kspcomp::KShorestPathFirstFitCompilation, cachedresults::CachedResults)
    return KShorestPathFirstFitCompilation(kspcomp.candidatepathsnum, cachedresults, BasicAlgorithmMemory())
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFrameworkKSP, idagnode::IntentDAGNode{<:ConnectivityIntent}; verbose::Bool = false)
    intradomaincompilationalg = intradomaincompilationtemplate(
        prioritizepaths = prioritizepaths_shortest,
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
