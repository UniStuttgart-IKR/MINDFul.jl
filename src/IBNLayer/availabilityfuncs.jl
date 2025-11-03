function gettruesingleton(::Type{IntentState.T})
    return IntentState.Installed
end
function getfalsesingleton(::Type{IntentState.T})
    return IntentState.Failed
end
function getfinalsingleton(::Type{IntentState.T})
    return IntentState.Compiled
end

function gettruesingleton(::Type{Bool})
    return true
end
function getfalsesingleton(::Type{Bool})
    return false
end
function getfinalsingleton(::Type{Bool})
    return nothing
end

"""
$(TYPEDSIGNATURES)

Get uptime and downtime periods from link/intent states.
Return a tuple with the first element being the uptimes in Milliseconds and the second the downtimes in Milliseconds.
If endtime is different that the one in list, pass it.
Also return a simplified version of the log state vector

For links the state machine goes:
true -> false -> true -> false -> ...

For intents the state machine goes:
Installed -> Failed --> Installed --> Failed --> Compiled
or
Installed -> Failed --> Installed --> Failed --> Installed --> Compiled
"""
function getupdowntimes(logstates::Vector{Tuple{R, T}}, endtime=nothing) where {R,T}
    uptimes = Vector{Dates.Millisecond}()
	downtimes = empty(uptimes)
    lssimple = empty(logstates)

    datetime2start = logstates[1][1] - Dates.Hour(1)

    uddts = UpDownTimesNDatetime(uptimes, downtimes, lssimple, datetime2start)
    updateupdowntimes!(uddts, logstates, endtime)

    return uddts
end

function updateupdowntimes!(updowntimesndatetime::UpDownTimesNDatetime, logstates::Vector{Tuple{R, T}}, endtime=nothing) where {R,T}
    uptimes = getuptimes(updowntimesndatetime)
    downtimes = getdowntimes(updowntimesndatetime)
    datetimestamps = getdatetimestamps(updowntimesndatetime)

    if isempty(datetimestamps)
        prsti = 0
    else
        prsti = findfirst(==(datetimestamps[end]), logstates)
        @assert !isnothing(prsti)
    end

    # probably not needed
    nextlsi = prsti + 1
    for i in (prsti+1):length(logstates)
        nextlsi = i
        logstates[i][1] >= getdatetime(updowntimesndatetime) && break
    end

    for i in (nextlsi):length(logstates)
        currentstate = logstates[i][2]
        currenttime = logstates[i][1]
        # @show currenttime, currentstate
        if iszero(prsti)
            prsti = i
            if currentstate == gettruesingleton(T) || currentstate == getfalsesingleton(T)
                push!(datetimestamps, logstates[i])
            end
        else
            previousstate = logstates[prsti][2]
            previoustime = getdatetime(updowntimesndatetime) > logstates[prsti][1] ? getdatetime(updowntimesndatetime) : logstates[prsti][1]
            requirenewblock = logstates[prsti][1] == previoustime
            if currentstate !== previousstate

                # store
                dt = currenttime - previoustime
                @assert dt >= zero(dt)

                if currentstate == gettruesingleton(T)
                    if previousstate == getfalsesingleton(T)
                        if requirenewblock
                            push!(downtimes, dt)
                        else
                            downtimes[end] += dt
                        end
                    end
                    push!(datetimestamps, logstates[i])
                    @assert currenttime >= getdatetime(updowntimesndatetime)
                    setdatetime!(updowntimesndatetime, currenttime)
                    prsti = i
                elseif currentstate == getfalsesingleton(T)
                    if previousstate == gettruesingleton(T)
                        if requirenewblock
                            push!(uptimes, dt)
                        else
                            uptimes[end] += dt
                        end
                    end
                    push!(datetimestamps, logstates[i])
                    @assert currenttime >= getdatetime(updowntimesndatetime)
                    setdatetime!(updowntimesndatetime, currenttime)
                    prsti = i
                elseif currentstate == getfinalsingleton(T)
                    if previousstate == gettruesingleton(T)
                        if requirenewblock
                            push!(uptimes, dt)
                        else
                            uptimes[end] += dt
                        end
                    elseif previousstate == getfalsesingleton(T)
                        if requirenewblock
                            push!(downtimes, dt)
                        else
                            downtimes[end] += dt
                        end
                    end
                    push!(datetimestamps, logstates[i])
                    @assert currenttime >= getdatetime(updowntimesndatetime)
                    setdatetime!(updowntimesndatetime, currenttime)
                    prsti = i
                end
                prsti
            end
        end 
    end

    # if there is additional endtime
    if !isnothing(endtime)
        previousstate = logstates[prsti][2]
        previoustime = logstates[prsti][1]
        requirenewblock = previoustime == getdatetime(updowntimesndatetime)
        dt = endtime - getdatetime(updowntimesndatetime)
        @assert dt >= zero(dt)
        if dt > zero(dt)
            if previousstate == gettruesingleton(T)
                if requirenewblock || isempty(uptimes)
                    push!(uptimes, dt)
                else
                    uptimes[end] += dt
                end
            elseif previousstate == getfalsesingleton(T)
                if requirenewblock || isempty(downtimes)
                    push!(downtimes, dt)
                else
                    downtimes[end] += dt
                end
            end
            setdatetime!(updowntimesndatetime, endtime)
        end
    end
end

"""
$(TYPEDSIGNATURES)

Return a dictionary with keys the edges and values the up and downtimes.
"""
function getdictlinkupdowntimes(ibnf; checkfirst = true, verbose::Bool = false, endtime=nothing)
    return Dict(ed => getlinkupdowntimes(ibnf, ed; checkfirst, verbose, endtime) for ed in edges(getibnag(ibnf)))
end

"""
$(TYPEDSIGNATURES)

Return a dictionary with keys the edges and values the empirical availabilities.
"""
function getdictlinkempiricalavailabilities(ibnf; checkfirst = true, verbose::Bool = false, endtime=nothing)
    return Dict(ed => 
                let 
                    ludts = getlinkupdowntimes(ibnf, ed; checkfirst, verbose, endtime) 
                    isempty(getuptimes(ludts)) ? 1.0 : sum(getuptimes(ludts)) / (sum(getdowntimes(ludts)) + sum(getuptimes(ludts)))
                end
                for ed in edges(getibnag(ibnf)))
end

"""
$(TYPEDSIGNATURES)

Calculate empirical availability of a path
"""
function getempiricalavailability(ibnf::IBNFramework, path::Vector{Int}; checkfirst::Bool = true, verbose::Bool = false, endtime=nothing)
    return reduce(*, [let 
        ludts = getlinkupdowntimes(ibnf, ed; checkfirst, verbose, endtime) 
        isempty(getuptimes(ludts)) ? 1.0 : calculateavailability(ludts)
    end for ed in edgeify(path)])
end

"""
$(TYPEDSIGNATURES)

Calculate empirical availability of a protected path
"""
function getempiricalavailability(ibnf::IBNFramework, ppath::Vector{Vector{Int}}; checkfirst::Bool = true, verbose::Bool = false, endtime=nothing)
    @assert length(ppath) <= 2
    if length(ppath) == 1
        return getempiricalavailability(ibnf, ppath[1]; checkfirst, verbose, endtime)
    else
        p1edges = edgeify(ppath[1])
        p1avails = [let
            ludts = getlinkupdowntimes(ibnf, ed; checkfirst, verbose, endtime) 
            isempty(getuptimes(ludts)) ? 1.0 : calculateavailability(ludts)
        end for ed in p1edges]

        p2edges = edgeify(ppath[2])
        p2avails = [let
            ludts = getlinkupdowntimes(ibnf, ed; checkfirst, verbose, endtime) 
            isempty(getuptimes(ludts)) ? 1.0 : calculateavailability(ludts)
        end for ed in p2edges]

        return calculateprotectedpathavailability(p1edges, p1avails, p2edges, p2avails)
    end
end

"""
$(TYPEDSIGNATURES)
"""
function getempiricalavailability(ibnf::IBNFramework, intentuuid::UUID, endtime=nothing)
    logstates = getlogstate(getidagnode(getidag(ibnf), intentuuid))
    updowntimes = UpDownTimes(getupdowntimes(logstates, endtime))
    return calculateavailability(updowntimes)
end

"""
$(TYPEDSIGNATURES)

Return the up and downtimes for the specific link
"""
function getlinkupdowntimes(ibnf, edge; checkfirst = true, verbose::Bool = false, endtime=nothing)
    linkstates = getlinkstates(ibnf, edge; checkfirst, verbose)
    updowntimes = UpDownTimes(getupdowntimes(linkstates, endtime))
    return updowntimes
end

function calculateavailability(updowntimes::UpDownTimes)
    return sum(getuptimes(updowntimes)) / (sum(getdowntimes(updowntimes)) + sum(getuptimes(updowntimes)))
end

function calculateavailability(updowntimes::UpDownTimesNDatetime)
    return sum(getuptimes(updowntimes)) / (sum(getdowntimes(updowntimes)) + sum(getuptimes(updowntimes)))
end

"""
$(TYPEDSIGNATURES)
"""
function calculatepathavailability(availabilities::Vector{Float64})
    return reduce(*, availabilities)
end

function calculateparallelavailability(avails::Float64...)
    # TODO : perf: avoid vector
    return 1 - reduce(*, [1 - avail for avail in avails])
end

"""
$(TYPEDSIGNATURES)
"""
function calculateprotectedpathavailability(p1edges::Vector{Edge{Int}}, p1avails::Vector{Float64}, p2edges::Vector{Edge{Int}}, p2avails::Vector{Float64})
    @assert length(p1edges) == length(p1avails)
    @assert length(p2edges) == length(p2avails)

    commonedges1inds = findall(ed -> ed in p2edges, p1edges)
    commonedges = p1edges[commonedges1inds]

    p1branchavail = 1.0
    p2branchavail = 1.0
    for p1i in 1:length(p1edges)
        if p1edges[p1i] ∉ commonedges
            p1branchavail *= p1avails[p1i]
        end
    end
    for p2i in 1:length(p2edges)
        if p2edges[p2i] ∉ commonedges
            p2branchavail *= p2avails[p2i]
        end
    end

    protectedpathavailability = calculateparallelavailability(p1branchavail, p2branchavail)
    protectedpathavailability *= reduce(*, p1avails[commonedges1inds])

    return protectedpathavailability
end

"""
$(TYPEDSIGNATURES)

# need to finish it if I ever use more than 2 protection paths
"""
function calculateprotectedpathavailability(pedges::Vector{Vector{Edge{Int}}}, pavails::Vector{Vector{Float64}})
    @assert all( pes_pas -> length(pes_pas[1]) == length(pes_pas[2]), zip(pedges, pavails))
    return 0.0
end


# --------------------------- Estimating availability ------------------------------
# Estimation is a Float
# TODO: use average estimation instead of DiscreteNonParametric also for the pre-estimation

function estimatepathavailability(ibnf::IBNFramework, path::Vector{LocalNode})
    return getempiricalavailability(ibnf, path; endtime = getdatetime(getbasicalgmem(getintcompalg(ibnf))))
end

function estimateprpathavailability(ibnf::IBNFramework, prpath::Vector{Vector{LocalNode}})
    return getempiricalavailability(ibnf, prpath; endtime = getdatetime(getbasicalgmem(getintcompalg(ibnf))))
end

function estimateintentavailability(ibnf::IBNFramework, intentuuid::UUID; requested::Bool=true)
    return estimateintentavailability(ibnf, getidagnode(getidag(ibnf), intentuuid); requested)
end

function estimateintentavailability(ibnf::IBNFramework, conintidagnode::IntentDAGNode{<:ConnectivityIntent}; requested::Bool=true)
    estimatedavailability = 1.
    remintent = nothing
    for avawareintent in getidagnodedescendants_availabilityaware(getidag(ibnf), getidagnodeid(conintidagnode))
        if avawareintent isa LightpathIntent
            path = getpath(avawareintent)
            estimatedavailability *= estimatepathavailability(ibnf, path)
        elseif avawareintent isa ProtectedLightpathIntent
            prpath = getprpath(avawareintent)
            estimatedavailability *= estimateprpathavailability(ibnf, prpath)
        elseif avawareintent isa RemoteIntent{<:ConnectivityIntent}
            if requested
                estimatedavailability *= getavailabilityrequirement(something(getfirst(x -> x isa AvailabilityConstraint, getconstraints(getintent(avawareintent)))))
            else
                remintent = getintent(avawareintent)
                srcglobalnode = getsourcenode(remintent)
                dstglobalnode = getdestinationnode(remintent)
                globaledge = GlobalEdge(srcglobalnode, dstglobalnode)
                estimatedcrosssav = estimatecrossconnectionavailability(ibnf, globaledge)
                estimatedavailability *= estimatedcrosssav
            end
        end
    end
    return estimatedavailability
end

"""
$(TYPEDSIGNATURES)

Final cross domain avaibility is the average empirical availability
"""
function estimatecrossconnectionavailability(ibnf::IBNFramework, ged::GlobalEdge)
    loginterupdowntimes = getloginterupdowntimes(getintcompalg(ibnf))
    if haskey(loginterupdowntimes, ged) 
        updowntimesndatetimedict = loginterupdowntimes[ged]
        updowntimesndatetimes = values(updowntimesndatetimedict)
        estimatedavailabilitysum = 0.0
        count = 0
        for updowntimesndatetime in updowntimesndatetimes
            if isempty(getuptimes(updowntimesndatetime)) && isempty(getdowntimes(updowntimesndatetime))
                continue
            end
            estimatedavailabilitysum += calculateavailability(updowntimesndatetime)
            count += 1
        end
        if iszero(count)
            return 1.0
        else
            estimatedavailability = estimatedavailabilitysum / count
        end
        return estimatedavailability
    else
        return 1.0
    end
end

"""
$(TYPEDSIGNATURES)

Must always return a AvailabilityConstraint

Assumes 100% compliance target
"""
function calcsecondhalfavailabilityconstraint(ibnf::IBNFramework, firsthalfavailability::Float64, masteravconstr::AvailabilityConstraint)
    secondavailabilityrequirement = getavailabilityrequirement(masteravconstr) / firsthalfavailability
    secondcompliancetarget = getcompliancetarget(masteravconstr)
    return AvailabilityConstraint(secondavailabilityrequirement, secondcompliancetarget)
end
