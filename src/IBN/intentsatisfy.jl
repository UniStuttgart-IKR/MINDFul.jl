@enum(SignalLoc, signalStart, signalElectricalDown, signalElectricalUp, signalGroomingDown, signalGroomingUp, 
      signalOXCAdd, signalOXCDrop, signalOXCbypass, signalFiberIn, signalFiberOut, signalEnd)

mutable struct ConnectionState
    node::Int
    signaloc::SignalLoc
end
getnode(cs::ConnectionState) = cs.node

function filternext(sd::Val{signalStart}, cs::ConnectionState)
    function nextelectricaldown(lli::LowLevelIntent)
        lli isa NodeRouterIntent && getnode(lli) == getnode(cs)
    end
end
function filternext(sd::Val{signalElectricalDown}, cs::ConnectionState)
    function nextelectricaldown(lli::LowLevelIntent)
        lli isa NodeSpectrumIntent && getnode(lli) == getnode(cs)
    end
end
function filternext(sd::Val{signalElectricalUp}, cs::ConnectionState)
    function nextelectricaldown(lli::LowLevelIntent)
        lli isa NodeSpectrumIntent && getnode(lli) == getnode(cs)
    end
end
function filternext(sd::Val{signalFiberIn}, cs::ConnectionState)
    function nextfiberin(lli::LowLevelIntent)
        (lli isa NodeRouterIntent && getnode(lli) == getnode(cs)) ||
        (lli isa NodeSpectrumIntent && getnode(lli) == getnode(cs))
    end
end
function filternext(sd::Val{signalFiberOut}, cs::ConnectionState)
    function nextfiberin(lli::LowLevelIntent)
        (lli isa NodeSpectrumIntent && lli.edge.dst == getnode(cs))
    end
end

"Pop new (LowLevelIntent, ConnectionState)"
function findNupdate!(cs::ConnectionState, nodeintents)
    for (i,idn) in enumerate(nodeintents)
        lli = getintent(idn)
        if cs.signaloc == signalElectricalDown
            if lli isa NodeSpectrumIntent && getnode(lli) == getnode(cs)
                deleteat!(nodeintents, i)
                return (idn, ConnectionState(getnode(cs), signalFiberOut))
            end
        elseif cs.signaloc == signalElectricalUp
            if lli isa NodeSpectrumIntent && getnode(lli) == getnode(cs)
                deleteat!(nodeintents, i)
                return (idn, ConnectionState(getnode(cs), signalElectricalDown))
            end
        elseif cs.signaloc == signalFiberIn
            if (lli isa NodeRouterIntent && getnode(lli) == getnode(cs))
                deleteat!(nodeintents, i)
                return (idn, ConnectionState(getnode(cs), signalElectricalUp))
            elseif (lli isa NodeSpectrumIntent && getnode(lli) == lli.edge.src == getnode(cs))
                deleteat!(nodeintents, i)
                return (idn, ConnectionState(getnode(cs), signalFiberOut))
            end
        elseif cs.signaloc == signalFiberOut
            if lli isa NodeSpectrumIntent && lli.edge.src == getnode(cs)
                deleteat!(nodeintents, i)
                return (idn, ConnectionState(lli.edge.dst, signalFiberIn))
            end
        elseif cs.signaloc == signalStart
            if lli isa NodeRouterIntent && getnode(lli) == getnode(cs)
                deleteat!(nodeintents, i)
                return (idn, ConnectionState(getnode(cs), signalElectricalDown))
            end
        end
    end
    return (nothing,nothing)
end

issatisfied(ibn::IBN, intentidx::Int; onlylogic=false) = issatisfied(ibn, ibn.intents[intentidx], getroot(ibn.intents[intentidx]); onlylogic = onlylogic)

function issatisfied(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode{C}; onlylogic=false) where C <: ConnectivityIntent
    success = true
    # reconstruct path from allocations based on this intent
    # check if the path makes sense and the constraints are satisfied
    nodeintents = filter(x -> getintent(x) isa LowLevelIntent, getintentdagnodes(dag))
    #start with the src intent
    # need a port in the beginning

    vcs = Vector{ConnectionState}()
    llis = Vector{LowLevelIntent}()

    cs = ConnectionState(getsrcdomnode(idagn.intent), signalStart)
    while true
        idn, cs = findNupdate!(cs, nodeintents)
        idn === nothing && break

        # check how lli is the only one accessing these resources (or just rely on that the resources are only once accessed ?)
        #
        lli = getintent(idn)
        # check how lli is installed
        if !onlylogic
            issatisfied(ibn, dag, idn) || return false
        end

        push!(vcs, cs)
        push!(llis, lli)
    end

    length(nodeintents) > 0 && @warn("Some LowLevelIntents were not needed")
    if getnode(vcs[1]) != getsrcdomnode(idagn.intent) || getnode(vcs[end]) != getdstdomnode(idagn.intent)
        return false
    end

    all(issatisfied(ibn, llis, vcs, constr) for constr in getconstraints(idagn.intent))
#    return (llis, vcs)
end

"Low Level Intents are assumed to be installed now"
function issatisfied(ibn::IBN, llis::Vector{LowLevelIntent}, vcs::Vector{ConnectionState}, cc::CapacityConstraint)
    #continuity and contiguity constraints
    # split them per signalOXCDrop
    splitidxs = findall(x -> x.signaloc == signalOXCDrop, vcs)
    pushfirst!(splitidxs, 0)
    push!(splitidxs, length(llis))
    continuousllis = [llis[s1+1:s3] for (s1,s3) in zip(splitidxs[1:end-1], splitidxs[2:end])]
    for contllis in continuousllis
        # don't check continuous blocks because of channel guards
        # group them by edge (each edge 2 Intents for the 2 nodes transmitting/receiving)
        for (fibin,fibout) in partition(Iterators.filter(x-> x isa NodeSpectrumIntent, contllis), 2)
            fibin.node != fibout.node || return false
            fibin.edge == fibout.edge || return false
            fibin.slots == fibout.slots || return false
            fibin.bandwidth == fibout.bandwidth || return false
#            @show (fibin.bandwidth, cc.drate)
            fibin.bandwidth >= cc.drate || return false
        end
    end
    return true
end

"Low Level Intents are assumed to be installed now"
function issatisfied(ibn::IBN, llis::Vector{LowLevelIntent}, vcs::Vector{ConnectionState}, cc::DelayConstraint)
    # TODO code duplication with issatisfied(::CapacityConstraint)
    sumkms = 0.0u"km"
    for (fibin,fibout) in partition(Iterators.filter(x-> x isa NodeSpectrumIntent, llis), 2)
        fibin.node != fibout.node || return false
        fibin.edge == fibout.edge || return false
        fibin.slots == fibout.slots || return false
        fibin.bandwidth == fibout.bandwidth || return false
        sumkms += get_prop(ibn.cgr, fibin.edge, :link) |> distance
    end
#    @show (delay(sumkms), cc.delay)
    delay(sumkms) <= cc.delay || return false
    return true
end
