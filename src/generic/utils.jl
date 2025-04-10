"""
$(TYPEDSIGNATURES)
using Core: ReturnNode

Convenience function to construct any struct of type `T` by passing a `Dict` corresponding to the fields needed.
"""
function constructfromdict(_::Type{T}, dict::Dict{Symbol}) where {T}
    return T([dict[fn] for fn in fieldnames(T)]...)
end

"""
$(TYPEDSIGNATURES)

Convenience function to construct any struct of type `T` by passing a `Dict` corresponding to the fields needed.
A further dict `dict2` is searched for data.
"""
function constructfromdict(_::Type{T}, dict::Dict{Symbol}, dict2::Dict{Symbol}) where {T}
    return T(
        [
            haskey(dict, fn) ? dict[fn] : dict2[fn]
                for fn in fieldnames(T)
        ]...
    )
end

"""
$(TYPEDSIGNATURES)

Return a `return false` if the expression `ex` evaluates to false.
If `verbose=true` print the statement and the location.
If the expression passed is `true` do nothing.
"""
macro returniffalse(verbose, ex)
    return quote
        if !($(esc(ex)))
            if $(esc(verbose))
                println("False expression in", $(string(__source__.file)), ':', $(__source__.line), " --> ", $(string(ex)))
            end
            return false
        end
    end
end


"""
$(TYPEDSIGNATURES)

Returns the element is `predicate` is satisfied  or `nothing` otherwise.
"""
function getfirst(predicate::Function, ar::AbstractArray)
    for a in ar
        predicate(a) && return a
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)
"""
function edgeify(path::Vector{Int})
    return Edge.(path[1:(end - 1)], path[2:end])
end

"""
$(TYPEDSIGNATURES)

Finds first contiguous slot range of length `lengthrequire` that satisfies the `boolvec`.
Return the starting index of the range or `nothing` if none available
"""
function firstfit(boolvec::AbstractVector{Bool}, lenghrequire::Int)
    satisfyingslots = 0
    for (i, slotssatisfies) in enumerate(boolvec)
        if slotssatisfies
            satisfyingslots += 1
            if satisfyingslots == lenghrequire
                return i - satisfyingslots + 1
            end
        else
            satisfyingslots = 0
        end
    end
    return nothing
end


"""
$(TYPEDSIGNATURES)
"""
function mycopy(whatever::T) where {T}
    fns = fieldnames(T)
    return T(
        [
            let
                    f = getfield(whatever, fn)
                    isimmutable(f) ? f : Base.copy(f)
            end
                for fn in fns
        ]...
    )
end

function issuccess(s::Symbol)
    s === ReturnCodes.SUCCESS
end

