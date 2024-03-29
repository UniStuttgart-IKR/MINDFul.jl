function filternext(sd::Val{signalElectrical}, cs::ConnectionState)
    function nextelectricaldown(lli::LowLevelIntent)
        lli isa NodeRouterPortIntent && getnode(lli) == getnode(cs)
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
        (lli isa NodeRouterPortIntent && getnode(lli) == getnode(cs)) ||
        (lli isa NodeSpectrumIntent && getnode(lli) == getnode(cs))
    end
end
function filternext(sd::Val{signalFiberOut}, cs::ConnectionState)
    function nextfiberin(lli::LowLevelIntent)
        (lli isa NodeSpectrumIntent && lli.edge.dst == getnode(cs))
    end
end

# TODO check port rate and intent rate
"$(TYPEDSIGNATURES) Find next logical low-level intent. Pop new (LowLevelIntent, ConnectionState)"
function findNupdate!(cs::ConnectionState, prelli, globalIBNnlli)
    for (i,gibnl) in enumerate(globalIBNnlli)
        lli = gibnl.lli
        if cs.signaloc == signalElectricalDown
            if lli isa NodeTransmoduleIntent && getnode(lli) == getnode(cs)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalTransmissionModuleDown))
            end
        elseif cs.signaloc == signalElectricalUp
            if lli isa NodeRouterPortIntent && getnode(lli) == getnode(cs)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalElectricalDown))
            end
        elseif cs.signaloc == signalTransmissionModuleDown
            if lli isa NodeROADMIntent && getnode(lli) == getnode(cs) && ismissing(lli.inedge) && getfreqslots(gettransmodl(prelli)) <= length(lli.slots)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalOXCAdd))
            end
        elseif cs.signaloc == signalOXCAdd
            if lli isa NodeSpectrumIntent && getnode(lli) == getnode(cs) && lli.sptype == signalOXCAdd && !ismissing(prelli.outedge) && prelli.outedge == lli.edge && prelli.slots == lli.slots
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalFiberOut))
            end
        elseif cs.signaloc == signalTransmissionModuleUp
            if lli isa NodeRouterPortIntent && getnode(lli) == getnode(cs)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalElectricalUp))
            end
        elseif cs.signaloc == signalFiberIn
            if lli isa NodeROADMIntent && getnode(lli) == getnode(cs) && !ismissing(lli.inedge) && prelli.edge == lli.inedge && prelli.slots == lli.slots
                deleteat!(globalIBNnlli, i)
                if ismissing(lli.outedge)
                    return (gibnl, ConnectionState(getnode(cs), signalOXCDrop))
                else
                    return (gibnl, ConnectionState(getnode(cs), signalOXCbypass))
                end
            end
            # elseif lli isa RemoteLogicIntent && lli.intent isa BorderIntent
            #     constrs = getconstraints(lli.intent)
            #     if constrs isa GoThroughConstraint{Missing} && 
            #                 constrs.layer == signalElectrical && getnode(cs) == constrs.node
            #         deleteat!(globalIBNnlli, i)
            #         return (gibnl, ConnectionState(constrs.node , signalFiberIn))
            #     end
            # end
        elseif cs.signaloc == signalOXCbypass
            if (lli isa NodeSpectrumIntent && getnode(lli) == lli.edge.src == getnode(cs)) && lli.sptype == signalOXCbypass && lli.slots == prelli.slots && !ismissing(prelli.outedge) && prelli.outedge == lli.edge
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalFiberOut))
            end
        elseif cs.signaloc == signalOXCDrop
            if (lli isa NodeTransmoduleIntent && getnode(lli) == getnode(cs)) && ismissing(prelli.outedge)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalTransmissionModuleUp))
            end
        elseif cs.signaloc == signalFiberOut
            if lli isa NodeSpectrumIntent && lli.edge == prelli.edge && lli.slots == prelli.slots
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(lli.edge.dst, signalFiberIn))
            end
            # elseif lli isa RemoteLogicIntent && lli.intent isa BorderIntent
            #     constrs = getconstraints(lli.intent)
            #     if constrs isa GoThroughConstraint{SpectrumRequirements} && 
            #                 constrs.layer == signalFiberIn && getnode(cs) == constrs.req.cedge.src
            #         deleteat!(globalIBNnlli, i)
            #         return (gibnl, ConnectionState(constrs.req.cedge.dst , signalFiberIn))
            #     end
            # end
        elseif cs.signaloc == signalElectrical 
            if lli isa NodeRouterPortIntent && getnode(lli) == getnode(cs)
                deleteat!(globalIBNnlli, i)
                return (gibnl, ConnectionState(getnode(cs), signalElectricalDown))
            end
        end
    end
    return (nothing,nothing)
end

function isintentsatisfied(ibn::IBN, idn::IntentDAGNode{C}, gbnls::Vector{IBNnIntentGLLI}, vcs::Vector{R}) where {R <: ConnectionState, C <: ConnectivityIntent}
    if getnode(vcs[1]) != getsrc(idn.intent) || getnode(vcs[end]) != getdst(idn.intent)
        return false
    else
        return true
    end
end

isintentsatisfied(ibn::IBN, idn::IntentDAGNode{C}, gbnls::Vector{IBNnIntentGLLI}, vcs::Vector{Missing}) where {C <: BorderIntent} = true

"onlylogic is WIP"
issatisfied(ibn::IBN, intentid::UUID; exactly=false) = issatisfied(ibn, getintentnode(ibn,intentid))

# TODO issatisfied(onlylogic = true) could be implemented with ML ?
"""
$(TYPEDSIGNATURES)

Check if intent of `ibn`,`idagn` is satisfied.
It checks whether the implementation of the intent makes sense and if all constraints are satisfied.
Internally it retrieves all low-level intents, assembles them, and decides whether or not they satisfy the intent.

This function assumes global knowledge to reach a verdict.
For this reason it is clearly a function used for simulation purposes.
"""
function issatisfied(ibn::IBN, idagn::IntentDAGNode{I}; exactly=false) where I <: Intent
    getstate(idagn) ∈ [compiled, installed] || return false
    # get low level intents (resource reservations) in a logical order.
    globalIBNnllis, vcs, glllirest = logicalorderedintents(ibn, idagn, true; rest=true)
    exactly && length(glllirest) > 0 && return false

    # check if installed correctly
    for gibnl in globalIBNnllis
        if !issatisfied(gibnl.ibn, gibnl.idn)
            @info "intent IBN $(getid(ibn)), $(getid(gibnl.idn)) is not satisfied"
            return false
        end
    end

    # check general intent nature
    if !isintentsatisfied(ibn, idagn, globalIBNnllis, vcs)
        @info "General intent nature not satisfied"
        return false
    end

    # check specific constraints
    if applicable(iterate, getconstraints(idagn.intent))
        return all(issatisfied(globalIBNnllis, vcs, constr) for constr in getconstraints(idagn.intent))
    else
        return issatisfied(globalIBNnllis, vcs, getconstraints(idagn.intent))
    end
end

logicalorderedintents(ibn::IBN, intid::UUID, globalknow=false) = logicalorderedintents(ibn, getintentnode(ibn, intid), globalknow)

"""
$(TYPEDSIGNATURES)

Returns a tuple where the first element is a `Vector` of all low-level intents sorted 
in a logical order as used in the data plane to satisfy the intent identified by `ibn`, `idn`.

The second element is the `Vector` of the logical states served by the equivalent low-level intent of the first `Vector`.
Thus, the first and second `Vector` have the same length.

Toggle `globalknowledge` depending on the scenario.
"""
function logicalorderedintents(ibn::IBN, idn::IntentDAGNode{I}, globalknow=false) where I<:Intent
    globalIBNnlli_rest = getinterdomain_lowlevelintents(ibn, idn, globalknow)
    return globalIBNnlli_rest, fill(missing, length(globalIBNnlli_rest))
end

"$(TYPEDSIGNATURES)"
function logicalorderedintents(ibn::IBN, idn::IntentDAGNode{C}, globalknow=false; rest=false) where C<:Union{ConnectivityIntent, DomainConnectivityIntent}
    # the `Vector` of remaining low-level intents, which were not needed in the logical sequence.
    # This vector might be seen as wasting of resources.
    globalIBNnlli_rest = getinterdomain_lowlevelintents(ibn, idn, globalknow)
    vcs = Vector{ConnectionState}()
    globalIBNnlli = Vector{IBNnIntentGLLI}()

    # TODO maybe it starts from the fiber
    # start with the src intent
#    cs = ConnectionState(getsrc(idn.intent), signalElectrical)
    cs, prelli = getstartingconnectionstate(ibn, getintent(idn))
    _logicalorderedintents_rec!(cs, prelli, globalIBNnlli_rest, globalIBNnlli, vcs)
#    while true
#        gibnlli, cs = findNupdate!(cs, globalIBNnlli_rest)
#        gibnlli === nothing && break
#        push!(vcs, cs)
#        push!(globalIBNnlli, gibnlli)
#    end
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
    if rest
        return (globalIBNnlli, vcs, globalIBNnlli_rest)
    else
        length(globalIBNnlli_rest) > 0 && @warn("Some LowLevelIntents were not needed")
        return (globalIBNnlli, vcs)
    end
end

function _logicalorderedintents_rec!(cs, prelli, globalIBNnlli_rest, globalIBNnlli, vcs)
    gibnlli, cs = findNupdate!(cs, prelli, globalIBNnlli_rest)
    gibnlli === nothing && return nothing
    push!(vcs, cs)
    push!(globalIBNnlli, gibnlli)
    _logicalorderedintents_rec!(cs, getlli(gibnlli), globalIBNnlli_rest, globalIBNnlli, vcs)
end

"$(TYPEDSIGNATURES) Get a list of global view low-level intents `IBNnIntentGLLI` for the intent `ibn, idn`"
function getinterdomain_lowlevelintents(ibn::IBN, idna::IntentDAGNode, globalknow=false)
    # need to transform node and edge to global values for interdomain satisfaction check
    dag = getintentdag(ibn)
    globalIBNnlli = Vector{IBNnIntentGLLI}()
    for idn in descendants(dag, idna)
        if idn.intent isa RemoteIntent
            if globalknow
                ibnrem = getibn(ibn, idn.intent.ibnid)
                intidx = idn.intent.intentidx
                dagnrem = getintentnode(ibnrem,intidx)
                push!(globalIBNnlli, getinterdomain_lowlevelintents(ibnrem, dagnrem, globalknow)...)
                # get LowLevelIntent descendants of remote Intent
                # search remote Intent recursively for other remote intents to get all concerning LowLevelIntent
            else
                # get what I asked for as a remote intent (parent of RemoteIntent)
                lliglobals = parents(dag, idn)
                for lliglobal in lliglobals
                    rli = RemoteLogicIntent(lliglobal.intent, idn.intent)
                    push!(globalIBNnlli, IBNnIntentGLLI(ibn, idn, rli))
                end
            end
        elseif idn.intent isa LowLevelIntent
            lliglobal = convert2global(ibn, idn.intent)
            push!(globalIBNnlli, IBNnIntentGLLI(ibn, idn, lliglobal))
        end
    end
    return globalIBNnlli
end

function getstartingconnectionstate(ibn::IBN, intent::I) where I<:Intent
    bic = getfirst(c->c isa BorderInitiateConstraint, getconstraints(intent))
    if isnothing(bic)
        cs = ConnectionState(getsrc(intent), signalElectrical)
        prelli = nothing
    else
        cs = ConnectionState(src(bic.edg), signalFiberOut)
        prelli = NodeSpectrumIntent(src(bic.edg), bic.edg, bic.reqs.spslots, bic.reqs.rate, signalOXCbypass)
    end
    return (cs, prelli)
end

"""
$(TYPEDSIGNATURES) 

Check whether the gloval low-level intents `globalIBNnllis` and their logical states `vcs` satisfy the capacity constraints `cc`.
Low Level Intents are assumed to be installed now.
"""
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
            fibin.bandwidth >= cc.drate || return false
        end
    end
    return true
end

"""
$(TYPEDSIGNATURES) 

Check whether the gloval low-level intents `globalIBNnllis` and their logical states `vcs` satisfy the constraints `cc`.
Low Level Intents are assumed to be installed now.
"""
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
        sumkms += get_prop(xin.ibn.ngr, ledge, :link) |> getdistance
    end
    delay(sumkms) <= cc.delay || return false
    return true
end


"$(TYPEDSIGNATURES)"
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
            if gbnl.lli isa NodeRouterPortIntent
                if gbnl.lli.node == cc.node
                    return true
                end
            end
        end
    elseif cc.layer in [signalOXCbypass]
        for gbnl in globalIBNnllis
            if gbnl.lli isa NodeRouterPortIntent
                if gbnl.lli.node == cc.node
                    return false
                end
            end
        end
        for gbnl in globalIBNnllis
            if gbnl.lli.node == cc.node
                return true
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

"$(TYPEDSIGNATURES)"
issatisfied(globalIBNnllis::Vector{IBNnIntentGLLI}, vcs::Vector{K}, cc::ReverseConstraint) where {K <: Union{Missing, ConnectionState}} = true

"$(TYPEDSIGNATURES)"
function issatisfied(globalIBNnllis::Vector{IBNnIntentGLLI}, vcs::Vector{K}, cc::BorderInitiateConstraint) where {K <: Union{Missing, ConnectionState}}
    return true
#    error("still didn't implement issatisfied for BorderInitiateConstraint")
end
