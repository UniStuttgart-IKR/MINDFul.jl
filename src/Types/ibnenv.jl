abstract type IBNEnvironment end

mutable struct IBNEnv{T,R,S} <: IBNEnvironment
    # TODO only time is mutable
    time::T
    ibns::Vector{IBN{R}}
    globalnet::S
end

IBNEnv(ibns,glb) = IBNEnv(0.0u"hr", ibns, glb)
updatetime!(ibnenv::IBNEnv, t::Unitful.Time) = (ibnenv.time = h) 
resettime!(ibnenv::IBNEnv) = (ibnenv.time = 0.0u"hr") 
gettime(ibnenv::IBNEnv) = ibnenv.time