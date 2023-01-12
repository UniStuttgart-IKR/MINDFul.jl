function filternext(sd::Val{signalElectrical}, cs::ConnectionState)
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
function findNupdate!(cs::ConnectionState, globalIBNnlli)
    for (i,gibnl) in enumerate(globalIBNnlli)
        lli = gibnl.lli
        if cs.signaloc == signalElectricalDown
            if lli isa NodeSpectrumIntent && getnode(lli) == getnode(cs)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalFiberOut))
            end
        elseif cs.signaloc == signalElectricalUp
            if lli isa NodeRouterIntent && getnode(lli) == getnode(cs)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalElectricalDown))
            end
        elseif cs.signaloc == signalFiberIn
            if (lli isa NodeRouterIntent && getnode(lli) == getnode(cs))
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalElectricalUp))
            elseif (lli isa NodeSpectrumIntent && getnode(lli) == lli.edge.src == getnode(cs))
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalFiberOut))
            elseif lli isa RemoteLogicIntent && lli.intent isa EdgeIntent
                constrs = getconstraints(lli.intent)
                if constrs isa GoThroughConstraint{Missing} && 
                            constrs.layer == signalElectrical && getnode(cs) == constrs.node
                    deleteat!(globalIBNnlli, i)
                    return (gibnl, ConnectionState(constrs.node , signalFiberIn))
                end
            end
        elseif cs.signaloc == signalFiberOut
            if lli isa NodeSpectrumIntent && lli.edge.src == getnode(cs)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(lli.edge.dst, signalFiberIn))
            elseif lli isa RemoteLogicIntent && lli.intent isa EdgeIntent
                constrs = getconstraints(lli.intent)
                if constrs isa GoThroughConstraint{SpectrumRequirements} && 
                            constrs.layer == signalFiberIn && getnode(cs) == constrs.req.cedge.src
                    deleteat!(globalIBNnlli, i)
                    return (gibnl, ConnectionState(constrs.req.cedge.dst , signalFiberIn))
                end
            end
        elseif cs.signaloc == signalElectrical 
            if lli isa NodeRouterIntent && getnode(lli) == getnode(cs)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalElectricalDown))
            end
        end
    end
    return (nothing,nothing)
end

function isnextLLI(sl::SignalLoc, lli::LowLevelIntent)
    success = lli isa RemoteLogicIntent && ll
end

function isintentsatisfied(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode{C}, gbnls::Vector{IBNnIntentGLLI}, vcs::Vector{R}) where {R <: ConnectionState, C <: ConnectivityIntent}
    if getnode(vcs[1]) != getsrc(idn.intent) || getnode(vcs[end]) != getdst(idn.intent)
        return false
    else
        return true
    end
end

isintentsatisfied(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode{C}, gbnls::Vector{IBNnIntentGLLI}, vcs::Vector{Missing}) where {C <: EdgeIntent} = true

"onlylogic is WIP"
issatisfied(ibn::IBN, intentidx::Int; onlylogic=false) = issatisfied(ibn, getintent(ibn,intentidx), getroot(getintent(ibn,intentidx)))

# TODO issatisfied(onlylogic = true) could be implemented with ML ?
"check if the path makes sense and the constraints are satisfied"
function issatisfied(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode{I}) where I <: Intent
    # get low level intents (resource reservations) in a logical order.
    globalIBNnllis, vcs = logicalorderedintents(ibn, dag, idagn, true)

    # check if installed correctly
    for gibnl in globalIBNnllis
        issatisfied(gibnl.ibn, gibnl.dag, gibnl.idn) || (@info "$(intentidx(gibnl.ibn, gibnl.dag, gibnl.idn)) is not satisfied"; return false)
    end

    # check general intent nature
    if !isintentsatisfied(ibn, dag, idagn, globalIBNnllis, vcs)
        @info "General intent nature not satisfied"
        return false
    end

    # check specific constraints
    if applicable(iterate, getconstraints(idagn.intent))
        all(issatisfied(globalIBNnllis, vcs, constr) for constr in getconstraints(idagn.intent))
    else
        return issatisfied(globalIBNnllis, vcs, getconstraints(idagn.intent))
    end
end

logicalorderedintents(ibn::IBN, intid::Int, globalknow=false) = logicalorderedintents(ibn, getintent(ibn, intid), getroot(getintent(ibn, intid)), globalknow)

"returns all lowlevelintents in no particular order"
function logicalorderedintents(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode{I}, globalknow=false) where I<:Intent
    globalIBNnlli_rest = getinterdomain_lowlevelintents(ibn, dag, idn, globalknow)
    return globalIBNnlli_rest, fill(missing, length(globalIBNnlli_rest))
end

"""
Returns the intents in an ordered as used in data plane in order to satisfy `idn`
Is made to run for simulations and interdomain cases.
Returns
- The ordered IntentDAGNode as sequenced in tha data plane
- The ordered logical role of each intent
- The remaining intents of the tree that were not used
"""
function logicalorderedintents(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode{C}, globalknow=false) where C<:ConnectivityIntent
    globalIBNnlli_rest = getinterdomain_lowlevelintents(ibn, dag, idn, globalknow)
    vcs = Vector{ConnectionState}()
    globalIBNnlli = Vector{IBNnIntentGLLI}()

    # TODO maybe it starts from the fiber
    # start with the src intent
    cs = ConnectionState(getsrc(idn.intent), signalElectrical)
    while true
        gibnlli, cs = findNupdate!(cs, globalIBNnlli_rest)
        gibnlli === nothing && break
        push!(vcs, cs)
        push!(globalIBNnlli, gibnlli)
    end
    if !globalknow
        for (i,gibnl) in enumerate(globalIBNnlli_rest)
            lli = gibnl.lli
            if lli isa RemoteLogicIntent
                deleteat!(globalIBNnlli_rest, i)
                push!(vcs, ConnectionState(getnode(vcs[end]), signalUknown))
                push!(globalIBNnlli, gibnl)
            end
        end
    end
    length(globalIBNnlli_rest) > 0 && @warn("Some LowLevelIntents were not needed")
    return (globalIBNnlli, vcs)
end

"Returns a list of IBNnIntentGLLI"
function getinterdomain_lowlevelintents(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode, globalknow=false)
    # need to transform node and edge to global values for interdomain satisfaction check
    globalIBNnlli = Vector{IBNnIntentGLLI}()
    for idn in descendants(dag, idn)
        if idn.intent isa RemoteIntent
            if globalknow
                ibnrem = getibn(ibn, idn.intent.ibnid)
                intidx = idn.intent.intentidx
                dagrem = getintent(ibnrem,intidx)
                push!(globalIBNnlli, getinterdomain_lowlevelintents(ibnrem, dagrem, getroot(dagrem), globalknow)...)
                # get LowLevelIntent descendants of remote Intent
                # search remote Intent recursively for other remote intents to get all concerning LowLevelIntent
            else
                # get what I asked for as a remote intent (parent of RemoteIntent)
                lliglobals = parents(dag, idn)
                for lliglobal in lliglobals
                    rli = RemoteLogicIntent(lliglobal.intent, idn.intent)
                    push!(globalIBNnlli, IBNnIntentGLLI(ibn, dag, idn, rli))
                end
            end
        elseif idn.intent isa LowLevelIntent
            lliglobal = convert2global(ibn, idn.intent)
            push!(globalIBNnlli, IBNnIntentGLLI(ibn, dag, idn, lliglobal))
        end
    end
    return globalIBNnlli
end

"Low Level Intents are assumed to be installed now"
function issatisfied(globalIBNnllis::Vector{IBNnIntentGLLI}, vcs::Vector{K}, cc::CapacityConstraint) where {K <: Union{Missing, ConnectionState}}
    llis = getfield.(globalIBNnllis, :lli)
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
function issatisfied(globalIBNnllis::Vector{IBNnIntentGLLI}, vcs::Vector{K}, cc::DelayConstraint) where {K <: Union{Missing, ConnectionState}}
    # TODO code duplication with issatisfied(::CapacityConstraint)
    sumkms = 0.0u"km"
    for (xin,xout) in partition(Iterators.filter(x-> x.lli isa NodeSpectrumIntent, globalIBNnllis), 2)
        fibin = xin.lli
        fibout = xout.lli
        fibin.node != fibout.node || return false
        fibin.edge == fibout.edge || return false
        fibin.slots == fibout.slots || return false
        fibin.bandwidth == fibout.bandwidth || return false
        ledge = localedge(xin.ibn, fibin.edge; subnetwork_view=false)
        sumkms += get_prop(xin.ibn.ngr, ledge, :link) |> distance
    end
    delay(sumkms) <= cc.delay || return false
    return true
end

function issatisfied(globalIBNnllis::Vector{IBNnIntentGLLI}, vcs::Vector{K}, cc::GoThroughConstraint) where {K <: Union{Missing, ConnectionState}}
    if cc.layer == signalFiberIn
        for gbnl in globalIBNnllis
            if gbnl.lli isa NodeSpectrumIntent
                if gbnl.lli.edge == cc.req.cedge
                    if gbnl.lli.node == dst(cc.req.cedge) == cc.node
                        return true
                    end
                end
            end
        end
    elseif cc.layer == signalFiberOut
        for gbnl in globalIBNnllis
            if gbnl.lli isa NodeSpectrumIntent
                if gbnl.lli.edge == cc.req.cedge
                    if gbnl.lli.node == src(cc.req.cedge) == cc.node
                        return true
                    end
                end
            end
        end
    elseif cc.layer in [signalElectrical]
        for gbnl in globalIBNnllis
            if gbnl.lli isa NodeRouterIntent
                if gbnl.lli.node == cc.node
                    return true
                end
            end
        end
    elseif cc.layer == signalUknown
        for gbnl in globalIBNnllis
            if gbnl.lli.node == cc.node
                return true
            end
        end
    end
    return false
end
