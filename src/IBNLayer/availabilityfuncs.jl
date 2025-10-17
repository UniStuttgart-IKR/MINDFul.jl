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
    updowntimes = getupdowntimes(logstates, endtime)
    return calculateavailability(updowntimes)
end

"""
$(TYPEDSIGNATURES)

Return the up and downtimes for the specific link
"""
function getlinkupdowntimes(ibnf, edge; checkfirst = true, verbose::Bool = false, endtime=nothing)
    linkstates = getlinkstates(ibnf, edge; checkfirst, verbose)
    return getupdowntimes(linkstates, endtime)
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
