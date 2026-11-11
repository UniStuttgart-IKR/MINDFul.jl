# An intent compilation algorithm defined like another package would define it: a copy of
# `KShorestPathFirstFitCompilation` that allocates the spectrum last-fit instead of first-fit.
# It checks that the core test suite doesn't depend on the choices of MINDFul's own algorithms.
module ExternalCompilationExample

import MINDFul as MINDF
using MINDFul: IBNFramework, IntentDAGNode, ConnectivityIntent, CachedResults, BasicAlgorithmMemory
import Dates: DateTime, now

struct LastFitCompilation <: MINDF.IntentCompilationAlgorithmWithMemory
    candidatepathsnum::Int
    cachedresults::CachedResults
    basicalgmem::BasicAlgorithmMemory
end

LastFitCompilation(candidatepathnum::Int; nodenum) = LastFitCompilation(candidatepathnum, CachedResults(nodenum), BasicAlgorithmMemory())
LastFitCompilation(alg::LastFitCompilation, cachedresults::CachedResults) = LastFitCompilation(alg.candidatepathsnum, cachedresults, BasicAlgorithmMemory())

"the first slot of the last available block of `demandslotsneeded` slots"
function choosespectrum_lastfit(ibnf::IBNFramework, pathspectrumavailability::AbstractVector{Bool}, demandslotsneeded::Int)
    reversedstart = MINDF.firstfit(reverse(pathspectrumavailability), demandslotsneeded)
    isnothing(reversedstart) && return nothing
    return length(pathspectrumavailability) - reversedstart - demandslotsneeded + 2
end

MINDF.@recvtime function MINDF.compileintent!(ibnf::IBNFramework{O, S, T, I, R}, idagnode::IntentDAGNode{<:ConnectivityIntent}; verbose::Bool = false) where {O, S, T, I, R <: LastFitCompilation}
    intradomaincompilationalg = MINDF.intradomaincompilationtemplate(
        prioritizepaths = MINDF.prioritizepaths_shortest,
        prioritizegrooming = MINDF.prioritizegrooming_default,
        prioritizerouterport = MINDF.prioritizerouterports_lowestrate,
        prioritizetransmdlandmode = MINDF.prioritizetransmdlmode_cheaplowrate,
        choosespectrum = choosespectrum_lastfit,
        chooseoxcadddropport = MINDF.chooseoxcadddropport_first,
    )
    return MINDF.compileintenttemplate!(
        ibnf, idagnode;
        verbose,
        intradomainalgfun = intradomaincompilationalg,
        prioritizesplitnodes = MINDF.prioritizesplitnodes_longestfirstshortestpath,
        prioritizesplitbordernodes = MINDF.prioritizesplitbordernodes_shortestorshortestrandom,
        maximumsplitlevel = 1,
        MINDF.@passtime
    )
end

end

@testset ExtendedTestSet "conformance.jl"  begin
    TM.testsuitecompilationalgorithm(KShorestPathFirstFitCompilation(10; nodenum = 1); runjet = runjet())
    TM.testsuitecompilationalgorithm(BestEmpiricalAvailabilityCompilation(10, 5; nodenum = 1))

    lastfit = ExternalCompilationExample.LastFitCompilation(10; nodenum = 1)
    TM.testsuitecompilationalgorithm(lastfit)
    # the example really allocates differently: last-fit spectrum
    let ibnf = TM.loadsingledomaintestibnf(lastfit)
        id, _ = addintent!(ibnf, ConnectivityIntent(GlobalNode(getibnfid(ibnf), 4), GlobalNode(getibnfid(ibnf), 8), u"100.0Gbps"), NetworkOperator())
        rc, _ = compileintent!(ibnf, id)
        @test rc == ReturnCodes.SUCCESS
        slots = [getspectrumslotsrange(getintent(x)) for x in MINDF.getidagnodeleafs(getidag(ibnf), id) if getintent(x) isa OXCAddDropBypassSpectrumLLI]
        @test !isempty(slots) && all(s -> last(s) == length(first(values(getlinkspectrumavailabilities(getoxcview(getnodeview(getibnag(ibnf), 4)))))), slots)
    end
end
