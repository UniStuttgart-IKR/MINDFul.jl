mutable struct IBNFProps
    time::THours
end
updateIBNFtime!(ibnprops::IBNFProps, h::THours) = (ibnprops.time = h) 
updateIBNFtime!(h::THours) = (IBNFPROPS.time = h) 
resetIBNFtime!() = (IBNFPROPS.time = 0.0u"hr") 

struct LogState{T}
    logtime::Vector{Tuple{THours, T}}
end

LogState{T}() where T = LogState{T}(Vector{Tuple{typeof(1u"s"), T}}())
@inline Base.push!(ls::LogState, kw...) = push!(ls.logtime, kw...)

include("resourcetypes.jl")
include("sdntypes.jl")
include("intenttypes.jl")
include("ibntypes.jl")

