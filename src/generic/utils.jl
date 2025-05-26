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

Return a Vector{Tuple{Int, Int}} with the consecutive blocks that satisfy function `predicate`.
The first element of the tuple is the starting index and the second the last index of the block.
"""
function findconsecutiveblocks(predicate::F, vec::Vector) where F<:Function
    consblocks = Vector{Tuple{Int, Int}}()
    i = first(eachindex(vec))
    while i <= length(vec)
        if predicate(vec[i])
            startingindex = i
            lastindex = length(vec)
            for j in startingindex+1:length(vec)
                if !predicate(vec[j])
                    lastindex = j-1
                    break
                end
            end
            push!(consblocks, (startingindex, lastindex))
            i = lastindex + 1
        else
            i += 1
        end
    end
    return consblocks
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

"""
    Pass a `Vector{Vector{Int}}` where `Int` are the nodes of each lightpath.
    Return a `Vector{Vector{Int}}` where `Int` is the index of the contained lightpaths.
    if `startingnode = true`, `node` is starting else is ending.
"""
function consecutivelightpathsidx(containedlightpaths::Vector{Vector{Int}}, node::Int; startingnode=true)
    firstorlast = startingnode ? first : last
    startinglightpathscollections = Vector{Vector{Int}}()
    buildinglightpathscollections = Vector{Vector{Int}}()
    for lp in Iterators.filter(i -> firstorlast(containedlightpaths[i]) == node, eachindex(containedlightpaths))
        push!(buildinglightpathscollections, [lp])
    end
    while true
        _coreloop_consecutivelightpathsidx!(startinglightpathscollections, containedlightpaths, buildinglightpathscollections; startingnode)
        isempty(buildinglightpathscollections) && break
    end
    return startinglightpathscollections
end

function _coreloop_consecutivelightpathsidx!(startinglightpathscollections::Vector{Vector{Int}}, containedlightpaths::Vector{Vector{Int}}, buildinglightpathscollections::Vector{Vector{Int}}; startingnode=true)
    firstorlast = startingnode ? first : last
    # find all lightpaths that start with the last node
    eachindexcollections = eachindex(buildinglightpathscollections)
    for buildinglightpathscollectionidx in eachindexcollections
        buildinglightpathscollection = buildinglightpathscollections[buildinglightpathscollectionidx]
        # get the last node of the investigated lightpath collection (or the first node)
        gluenode = startingnode ? containedlightpaths[buildinglightpathscollection[end]][end] : containedlightpaths[buildinglightpathscollection[1]][1]
        lpfounder = Iterators.filter(eachindex(containedlightpaths)) do i
            firstorlast(containedlightpaths[i]) == gluenode || return false
            cyclicnode = false
            for v in containedlightpaths[i]
                v == gluenode && continue
                for lpidx in buildinglightpathscollection
                    if v ∈ containedlightpaths[lpidx]
                        return false
                    end
                end
                cyclicnode && break
            end
            return true
        end
        for lp in lpfounder
            if lp ∉ buildinglightpathscollection
                newlightpathcollection = vcat(buildinglightpathscollection, lp)
                if startingnode
                    push!(buildinglightpathscollections, vcat(buildinglightpathscollection, lp)) 
                else
                    push!(buildinglightpathscollections, vcat(lp, buildinglightpathscollection)) 
                end
            end
        end
    end
    # delete all old entries
    for buildinglightpathscollectionidx in eachindexcollections
        push!(startinglightpathscollections, buildinglightpathscollections[buildinglightpathscollectionidx])
    end
    deleteat!(buildinglightpathscollections, eachindexcollections)

    return nothing
end


"""
$(TYPEDSIGNATURES)
    Return `true` if `subpath` is contained in `path`
"""
function issubpath(path::Vector{Int}, subpath::Vector{Int})
    length(subpath) <= length(path) || return false
    iscontained = true
    for i in eachindex(path)
        if path[i] == subpath[1]
            for j in 2:length(subpath)
                path[i-1+j] == subpath[j] || return false
            end
            break
        end
    end
    return true
end
