### Overload IBNFramework for the specific algorithm to customize your behavior

function getkpis(intentcomp::IntentCompilationAlgorithm)
    return missing
end

"""
$(TYPEDSIGNATURES)

If estimating is a slow procedure, we have some batched simulations.
For that this function will be updated.
This must be called from the simulation code and is not directly called from MINDFul
"""
function updateestimations!(ibnf::IBNFramework, currenttime::DateTime)
    return nothing
end

function multavs(av1, av2)
    return av1 * av2
end

function multavs(av1::AbstractVector, av2::AbstractVector)
    return av1 .* av2
end

function multavs(av1::AbstractVector, av2::Number)
    return av1 .* av2
end

function initializeestimateavailability(ibnf::IBNFramework)
    return 1.0
end

"""
$(TYPEDSIGNATURES)

Estimate the availability of an intent.
It's used to reestimate the intent availability after the first split is done.
The intent is usually an internal intent.
"""
function estimateintentavailability(ibnf::IBNFramework, conintidagnode::IntentDAGNode{<:ConnectivityIntent}; requested::Bool=true)
    # TODO : perf maybe make mutable to save on allocations with doing multiavs! ?
    estimatedavailability = initializeestimateavailability(ibnf)
    remintent = nothing
    for avawareintent in getidagnodedescendants_availabilityaware(getidag(ibnf), getidagnodeid(conintidagnode))
        if avawareintent isa LightpathIntent
            path = getpath(avawareintent)
	    newestim = estimatepathavailability(ibnf, path)
	    estimatedavailability = multavs(estimatedavailability, newestim)
        elseif avawareintent isa ProtectedLightpathIntent
            prpath = getprpath(avawareintent)
	    newestim = estimateprpathavailability(ibnf, prpath)
	    estimatedavailability = multavs(estimatedavailability, newestim)
        elseif avawareintent isa RemoteIntent{<:ConnectivityIntent}
            remintent = getintent(avawareintent)
            if requested
                avreq = getavailabilityrequirement(something(getfirst(x -> x isa AvailabilityConstraint, getconstraints(remintent))))
		estimatedavailability = multavs(estimatedavailability, avreq)
            else
                srcglobalnode = getsourcenode(remintent)
                dstglobalnode = getdestinationnode(remintent)
                globaledge = GlobalEdge(srcglobalnode, dstglobalnode)
                estimatedcrosssav = estimatecrossconnectionavailability(ibnf, globaledge)
		estimatedavailability = multavs(estimatedavailability, estimatedcrosssav)
            end
        end
    end
    return estimatedavailability
end

function estimatepathavailability(ibnf::IBNFramework, path::Vector{LocalNode})
    return getempiricalavailability(ibnf, path; endtime = getdatetime(getbasicalgmem(getintcompalg(ibnf))))
end

function estimateprpathavailability(ibnf::IBNFramework, prpath::Vector{Vector{LocalNode}})
    return getempiricalavailability(ibnf, prpath; endtime = getdatetime(getbasicalgmem(getintcompalg(ibnf))))
end

"""
$(TYPEDSIGNATURES)

After `estimateintentavailability(IBNFramework, ::IntentDAGNode{<:ConnectivityIntent})` is invoked for the first half of the internal intent, this function is called to get back the right AvailabilityConstraint to ask for

Must always return a AvailabilityConstraint

Assumes 100% compliance target

The `firsthalfavailability` must be of the same type that the `estimateintentavailability` returns.
"""
function calcsecondhalfavailabilityconstraint(ibnf::IBNFramework, firsthalfavailability::Float64, masteravconstr::AvailabilityConstraint)
    secondavailabilityrequirement = getavailabilityrequirement(masteravconstr) / firsthalfavailability
    secondcompliancetarget = getcompliancetarget(masteravconstr)
    return AvailabilityConstraint(secondavailabilityrequirement, secondcompliancetarget)
end

"""
$(TYPEDSIGNATURES)

This function is called to estimate the first half availability constraint of the `SplitGlobalNode`
"""
function estimateintraconnectionavailability(ibnf::IBNFramework, srcnode::LocalNode, dstnode::LocalNode)
    return nothing
end

"""
$(TYPEDSIGNATURES)

This function is called to estimate the second half availability constraint of the `SplitGlobalNode`

Final cross domain avaibility is the average empirical availability
"""
function estimatecrossconnectionavailability(ibnf::IBNFramework, ged::GlobalEdge)
    loginterupdowntimes = getloginterupdowntimes(getintcompalg(ibnf))
    if haskey(loginterupdowntimes, ged) 
        updowntimesndatetimedict = loginterupdowntimes[ged]
	updowntimesndatetimes = getupdowntimesndatetime.(values(updowntimesndatetimedict))
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

After calculating the two halfs of the availabilities, choose the two availabilities.
"""
function chooseintrasplitavailabilities(avcon::AvailabilityConstraint, firsthalfavailability, secondhalfavailability, intentcomp::IntentCompilationAlgorithm)
    availabilityrequirement = getavailabilityrequirement(avcon)
    compliancetarget = getcompliancetarget(avcon)
    firsthalfavailabilityconstraint = AvailabilityConstraint(sqrt(availabilityrequirement), sqrt(compliancetarget)) 
    secondhalfavailabilityconstraint = AvailabilityConstraint(sqrt(availabilityrequirement), sqrt(compliancetarget)) 
    return firsthalfavailabilityconstraint, secondhalfavailabilityconstraint
end

"""
$(TYPEDSIGNATURES)
"""
function choosecrosssplitavailabilities(avcon::AvailabilityConstraint, firsthalfavailability, secondhalfavailability, intentcomp::IntentCompilationAlgorithm)
    return chooseintrasplitavailabilities(avcon, firsthalfavailability, secondhalfavailability, intentcomp)
end
