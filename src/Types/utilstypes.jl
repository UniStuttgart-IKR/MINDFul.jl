struct LogState{T,R}
    logtime::Vector{Tuple{T,R}}
end
LogState{R}() where R = LogState(Vector{Tuple{typeof(1.0u"hr"), R}}())
@inline Base.push!(ls::LogState, kw...) = push!(ls.logtime, kw...)

#TODO compare pointers not values
Base.@kwdef struct Counter
    #TODO implemente as simple integer?
    states::Dict{Any,Int} = Dict{Any,Int}(0 => 0)
end
(o::Counter)() = o.states[0] += 1
(o::Counter)(x) = haskey(o.states, x) ? o.states[x] += 1 : o.states[x] = 1

"""
Similar to an One Hot Vector but with continuous 1s from `from` to `to`
"""
struct RangeHotVector <: AbstractArray{Bool,1}
    from::Int
    to::Int
    size::Int
    RangeHotVector(from::Int, to::Int, size::Int) = from <= to && to <= size ? new(from,to,size) : error("Out of index arguments")
end
Base.size(rh::RangeHotVector) = (rh.size, )
Base.getindex(rh::RangeHotVector, i::Integer) = i in rh.from:rh.to
Base.show(io::IO, rh::RangeHotVector) = print(io,"RangeHotVector($(rh.from), $(rh.to), $(rh.size))")
Base.show(io::IO, ::MIME"text/plain", rh::RangeHotVector) = print(io,"RangeHotVector($(rh.from), $(rh.to), $(rh.size))")
Base.one(rh::RangeHotVector) = RangeHotVector(1, length(rh), length(rh))
rangesize(rhv::RangeHotVector) = rhv.to - rhv.from + 1

