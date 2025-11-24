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
function findconsecutiveblocks(predicate::F, vec::Vector) where {F <: Function}
    consblocks = Vector{Tuple{Int, Int}}()
    i = first(eachindex(vec))
    while i <= length(vec)
        if predicate(vec[i])
            startingindex = i
            lastindex = length(vec)
            for j in (startingindex + 1):length(vec)
                if !predicate(vec[j])
                    lastindex = j - 1
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
    return s === ReturnCodes.SUCCESS
end

"""
    Pass a `Vector{Vector{Int}}` where `Int` are the nodes of each lightpath.
    Return a `Vector{Vector{Int}}` where `Int` is the index of the contained lightpaths.
    if `startingnode = true`, `node` is starting else is ending.

```
julia> MINDF.consecutivelightpathsidx([
       [1,3,7], #1
       [2,5,7], #2
       [2,8,9], #3
       [7,4,2]
       ], 1; startingnode=true)
3-element Vector{Vector{Int64}}:
 [1]
 [1, 4]
 [1, 4, 3]
```
"""
function consecutivelightpathsidx(containedlightpaths::Vector{Vector{Int}}, node::Int; startingnode = true)
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

"""
    Return all possible combination of the lightpath indices passed such that `path` is formed
"""
function consecutivelightpathsidx(containedlightpaths::Vector{Vector{Int}}, path::Vector{Int})
    consecutivestartingnode = consecutivelightpathsidx(containedlightpaths, path[1]; startingnode= true)
    return filter!(consecutivestartingnode) do csn
        containedlightpaths[csn[end]][end] == path[end]
    end
end

function _coreloop_consecutivelightpathsidx!(startinglightpathscollections::Vector{Vector{Int}}, containedlightpaths::Vector{Vector{Int}}, buildinglightpathscollections::Vector{Vector{Int}}; startingnode = true)
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
                pathindex = i - 1 + j
                pathindex <= length(path) || return false
                path[pathindex] == subpath[j] || return false
            end
            break
        end
    end
    return true
end

function iszeroornothing(s)
    return isnothing(s) || iszero(s)
end

"""
$(TYPEDSIGNATURES)

Get uptime and downtime periods from link states.
Return a tuple with the first element being the uptimes in Milliseconds and the second the downtimes in Milliseconds.
If endtime is different that the one in list, pass it.
"""
function getupdowntimes2(ls::Vector{Tuple{R, T}}, endtime=nothing) where {R,T}
    uptimes = Vector{Dates.Millisecond}()
	downtimes = empty(uptimes)
    lssimple = empty(ls)
	for (prev,now) in zip(ls[1:end-1], ls[2:end])
		dt = now[1] - prev[1]
        # if prev[2] == true || prev[2] == IntentState.Installed
        if prev[2] !== now[2] && prev[2] == gettruesingleton(T)
            @assert dt >= zero(dt)
			push!(uptimes, dt)
            push!(lssimple, (now[1], gettruesingleton(T)))
		elseif prev[2] !== now[2] && prev[2] == getfalsesingleton(T)
            @assert dt >= zero(dt)
			push!(downtimes, dt)
            if isempty(lssimple)
                push!(lssimple, (now[1], gettruesingleton(T)))
                push!(lssimple, (now[1], getfalsesingleton(T)))
            else
                push!(lssimple, (now[1], getfalsesingleton(T)))
            end
		end
	end
    # TODO double code
    if !isnothing(endtime)
        dt = endtime - ls[end][1]
        if !iszero(dt) && dt > zero(dt)
            if ls[end][2] == gettruesingleton(T)
                if isempty(uptimes)
                    push!(uptimes, dt)
                else
                    uptimes[end] += dt
                end
            elseif ls[end][2] == getfalsesingleton(T)
                if isempty(downtimes)
                    push!(downtimes, dt)
                else
                    downtimes[end] += dt
                end
            end
        end
    end
    return UpDownTimes(uptimes, downtimes), lssimple
end


"""
$(TYPEDSIGNATURES)

Incremeantaly update `updowntimesndatetime` given the new `ls`
"""
function getupdowntimes2!(updowntimesndatetime::UpDownTimesNDatetime, ls::Vector{Tuple{R, T}}, endtime=nothing) where {R,T}
    laststateindex_bigenough = findfirst(lg -> lg[1] > getdatetime(updowntimesndatetime), ls)
    laststateindex = isnothing(laststateindex_bigenough) ? 
        nothing : findfirst(i -> i > laststateindex_bigenough && (ls[i][2] == gettruesingleton(T) || ls[i][2] == getfalsesingleton(T)), eachindex(ls))

    uptimes = getuptimes(updowntimesndatetime)
    downtimes = getdowntimes(updowntimesndatetime)
    datetimestamps = getdatetimestamps(updowntimesndatetime)
    
    if isnothing(laststateindex)
        if isnothing(endtime)
            return updowntimesndatetime
        else
            # increase the last uptime or downtime
            previoustimestate = ls[end]
            newstate = getdatetime(updowntimesndatetime) == previoustimestate[1] 
            previoustime = getdatetime(updowntimesndatetime) > previoustimestate[1] ? getdatetime(updowntimesndatetime) : previoustimestate[1]
            dt = endtime - previoustime
            @assert dt >= zero(dt)
            if !iszero(dt)
                if previoustimestate[2] == gettruesingleton(T)
                    if length(uptimes) > 0
                        if newstate
                            # intent has just been installed and just failed and time proceeded so an uptime must be created
                            push!(uptimes, dt)
                            push!(datetimestamps, (endtime, gettruesingleton(T)))
                        else
                            uptimes[end] += dt
                        end
                    else
                        # intent has just been installed and time proceeded so an uptime must be created
                        push!(uptimes, dt)
                        push!(datetimestamps, (previoustime, gettruesingleton(T)))
                    end
                    setdatetime!(updowntimesndatetime, endtime)
                elseif previoustimestate[2] == getfalsesingleton(T)
                    if length(downtimes) > 0
                        if newstate
                            # intent has just been installed, failed and just repaired and time proceeded so an downtime must be created
                            push!(downtimes, dt)
                            push!(datetimestamps, (endtime, getfalsesingleton(T)))
                        else
                            downtimes[end] += dt
                        end
                    else
                        push!(downtimes, dt)
                    end
                    setdatetime!(updowntimesndatetime, endtime)
                end
            end
        end
    else
        for (prev,now) in zip(ls[laststateindex-1:end-1], ls[laststateindex:end])
            dt = now[1] - prev[1]
            @assert dt >= zero(dt)
            if prev[2] !== now[2] && prev[2] == gettruesingleton(T)
                push!(uptimes, dt)
                setdatetime!(updowntimesndatetime, now[1])
                push!(datetimestamps, (now[1], gettruesingleton(T)))
            elseif prev[2] !== now[2] && prev[2] == getfalsesingleton(T)
                push!(downtimes, dt)
                setdatetime!(updowntimesndatetime, now[1])
                if isempty(datetimestamps)
                    push!(datetimestamps, (prev[1], gettruesingleton(T)))
                    push!(datetimestamps, (now[1], getfalsesingleton(T)))
                else
                    push!(datetimestamps, (now[1], getfalsesingleton(T)))
                end
            end
        end

        # TODO double code
        if !isnothing(endtime)
            dt = endtime - ls[end][1]
            @assert dt >= zero(dt)
            if !iszero(dt)
                if ls[end][2] == gettruesingleton(T)
                    if isempty(uptimes)
                        push!(uptimes, dt)
                    else
                        uptimes[end] += dt
                    end
                    setdatetime!(updowntimesndatetime, endtime)
                elseif ls[end][2] == getfalsesingleton(T)
                    if isempty(downtimes)
                        push!(downtimes, dt)
                    else
                        downtimes[end] += dt
                    end
                    setdatetime!(updowntimesndatetime, endtime)
                end
            end
        end
    end
    return updowntimesndatetime
end


function millisecondtohour(ms::Number)
    return ms / 1_000 / 60 / 60
end

function millisecondtohour(ms::Dates.Millisecond)
    return ms.value / 1_000 / 60 / 60
end

function millisecondtoday(ms::Number)
    return ms / 1_000 / 60 / 60 / 24
end

function millisecondtoday(ms::Dates.Millisecond)
    return ms.value / 1_000 / 60 / 60 / 24
end

function millisecondtomonth(ms::Number)
    return ms / 1_000 / 60 / 60 / 24 / 30
end

function millisecondtomonth(ms::Dates.Millisecond)
    return ms.value / 1_000 / 60 / 60 / 24 / 30
end

function uniquesupportweightsDiscreteNonParametric(support::AbstractVector, weights::AbstractVector)
    uniquesupport = unique(support)
    sameelements = [findall(==(us), support) for us in uniquesupport]

    # weights = [
    #     let
    #         sum(weights[sameels])
    #     end for sameels in sameelements
    # ]
    
    weights2 = [sum(weights[sameels]) for sameels in sameelements]

    ps = weights2 ./ sum(weights2)
    if isnan(ps[1])
        @show support, weights
    end

    return DiscreteNonParametric(uniquesupport, ps)
end
