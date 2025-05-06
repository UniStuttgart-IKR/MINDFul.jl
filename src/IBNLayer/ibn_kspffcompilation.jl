"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct KShorestPathFirstFitCompilation <: IntentCompilationAlgorithm
    "How many k paths to check"
    candidatepathsnum::Int
end

"""
$(TYPEDSIGNATURES)
"""
function getcandidatepathsnum(kspffcomp::KShorestPathFirstFitCompilation)
    return kspffcomp.candidatepathsnum
end

"The keyword for [`KShorestPathFirstFitCompilation`](@ref)"
const KSPFFalg = :kspff

"""
$(TYPEDSIGNATURES)

Give back the algorithm mapped to the symbol
"""
function getcompilationalgorithmtype(s::Val{KSPFFalg})
    return KShorestPathFirstFitCompilation
end

"""
$(TYPEDSIGNATURES)
"""
function getdefaultcompilationalgorithmargs(s::Val{KSPFFalg})
    return (5,)
end

"""
$(TYPEDSIGNATURES)

Give back the symbol mapped to the algorithm
"""
function getcompilationalgorithmkeyword(c::T) where {T<:IntentCompilationAlgorithm}
    return getcompilationalgorithmkeyword(T)
end

"""
$(TYPEDSIGNATURES)

Give back the symbol mapped to the algorithm
"""
function getcompilationalgorithmkeyword(::Type{KShorestPathFirstFitCompilation})
    return KSPFFalg
end

"""
$(TYPEDSIGNATURES)

Can overload for different Operation Modes.
"""
function getdefaultcompilationalgorithm(ibnff::IBNFramework{<:AbstractOperationMode})
    return :kspff
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function compileintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, kspffcomp::KShorestPathFirstFitCompilation)
    intradomaincompilationalg = intradomaincompilationtemplate(
        prioritizepaths = prioritizepaths_shortest,
        prioritizerouterport = prioritizerouterports_first,
        prioritizetransmdlandmode = prioritizetransmdlmode_cheaplowrate,
        choosespectrum = choosespectrum_firstfit,
        chooseoxcadddropport = chooseoxcadddropport_first,
    )
    compileintenttemplate!(ibnf, idagnode, kspffcomp;
        intradomainalgfun = intradomaincompilationalg,
        externaldomainalgkeyword = getcompilationalgorithmkeyword(kspffcomp),
        prioritizesplitnodes = prioritizesplitnodes_longestfirstshortestpath,
        prioritizesplitbordernodes = prioritizesplitbordernodes_shortestorshortestrandom,
        @passtime)
end
