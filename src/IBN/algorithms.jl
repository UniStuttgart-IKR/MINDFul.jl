function compile!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode{R}, algmethod::F; algargs...) where {R<:Union{ConnectivityIntent},F<:Function}
    iam(ibn, neibn) = getid(ibn) == getid(neibn)
    firstforeignibnnode(ibn::IBN) = getfirst(x -> ibn.controllers[NestedGraphs.domain(ibn.cgr,x)] isa IBN, [v for v in vertices(ibn.cgr)])
    firstnode(ibn::IBN, neibn::IBN) = getfirst(x -> ibn.controllers[NestedGraphs.domain(ibn.cgr,x)] == neibn, [v for v in vertices(ibn.cgr)])

    conint = idagn.intent
    if getsrc(conint) == getdst(conint)
        @info "Cannot compile a connectivity intent between the same node"
        return getstate(idagn)
    end
    if isintraintent(ibn, conint)
        state = algmethod(ibn, dag, idagn, IntraIntent(); algargs...)
    else
        neibnsrc = getibn(ibn, getsrcdom(conint))
        neibndst = getibn(ibn, getdstdom(conint))
        if neibnsrc === nothing && neibndst !== nothing
            if iam(ibn,neibndst)
                neibn = first(getibns(ibn))
                state = algmethod(ibn, neibn, dag, idagn, InterIntent{IntentBackward}(); algargs...)
            else
                state = delegateintent!(ibn, neibndst, dag, idagn, idagn.intent, algmethod; algargs...)
            end
        elseif neibnsrc !== nothing && neibndst === nothing
            if iam(ibn,neibnsrc)
                for neibn in getibns(ibn)
                    algmethod(ibn, neibn, dag, idagn, InterIntent{IntentForward}(); algargs...)
                    idagn.state == compiled && break
                    restartintent!(ibn, getid(dag))
                end
            else
                state = delegateintent!(ibn, neibnsrc, dag, idagn, idagn.intent, algmethod; algargs...)
            end
        elseif neibnsrc !== nothing && neibndst !== nothing
            if iam(ibn,neibnsrc)
                state = algmethod(ibn, neibndst, dag, idagn, InterIntent{IntentForward}(); algargs...)
            elseif iam(ibn, neibndst)
                state = algmethod(ibn, neibnsrc, dag, idagn, InterIntent{IntentBackward}(); algargs...)
            else
                state = delegateintent!(ibn, neibnsrc, dag, idagn, idagn.intent, algmethod; algargs...)
            end
        elseif neibnsrc == nothing && neibndst == nothing
            # talk to random IBN (this is where fun begins!)
            for neibn in getibns(ibn)
                delegateintent!(ibn, neibn, dag, idagn, idagn.intent, algmethod; algargs...)
                idagn.state == compiled && break
            end
            return false
        end
    end
    return idagn.state
end

function compile!(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode, gtc::GoThroughConstraint)
    getid(ibn) != gtc.node[1] && (@warn "Cannot compile LowLevelIntent from another IBN"; return)
    node = gtc.node[2]

    signalocreq = gtc.layer
    if signalocreq == signalElectrical
        lli = NodeRouterIntent(node)
        addchild!(dag, getid(idn), lli)
    elseif signalocreq in [signalFiberIn, signalFiberOut] && gtc.req isa SpectrumRequirements
        sreqs = gtc.req
        cedg = localedge(ibn, sreqs.cedge)
        lli = NodeSpectrumIntent(node, NestedGraphs.edge(ibn.cgr, cedg), sreqs.frslots, sreqs.bandwidth)
        addchild!(dag, getid(idn), lli)
    end
    try2setstate!(idn, dag, ibn, Val(compiled))
end

"""
To solve an EdgeIntent, we basically need to only satisfy the constraints
"""
function shortestavailpath!(ibn::IBN, dag::IntentDAG, idagnode::IntentDAGNode{R}) where {R<:EdgeIntent}
    intent = getintent(idagnode)
    if applicable(iterate, getconstraints(intent))
        for constr in getconstraints(intent)
            compile!(ibn, dag, idagnode, constr)
        end
    else
        compile!(ibn, dag, idagnode, getconstraints(intent))
    end
end

"Handles interdomain connectivity intents"
function shortestavailpath!(ibnp::IBN, ibnc::IBN, dag::IntentDAG, idagnode::IntentDAGNode{T}, iid::InterIntent{R} ;
                k=5)  where {T<:ConnectivityIntent, R<:IntentDirection}
    iidforward = R <: IntentForward
    conint = idagnode.intent
    if iidforward
        myintent = DomainConnectivityIntent(getsrc(conint), getid(ibnc), getconstraints(conint), getconditions(conint))
    else
        myintent = DomainConnectivityIntent(getid(ibnc), getdst(conint) , getconstraints(conint), getconditions(conint))
    end
    domint = addchild!(dag, getid(idagnode), myintent)
    state = compile!(ibnp, dag, domint, shortestavailpath!; k=k)

    # create an intent for fellow ibn
    if state == compiled

        pintdn = getfirst(x -> getintent(x) isa PathIntent, children(dag, domint))
        pintent = getintent(pintdn)
        updatedconstraints = adjustNpropagate_constraints!(ibnp, dag)
        if iidforward
            transnode = (getid(ibnc), ibnp.cgr.vmap[pintent.path[end]][2])
            # need to update constraints
            remintent = ConnectivityIntent(transnode, getdst(conint), updatedconstraints, getconditions(myintent))
        else
            transnode = (getid(ibnc), ibnp.cgr.vmap[pintent.path[1]][2])
            remintent = ConnectivityIntent(getsrc(conint), transnode, updatedconstraints, getconditions(myintent))
        end
        success = delegateintent!(ibnp, ibnc, dag, idagnode, remintent, shortestavailpath!; k=k)
    end

    # deploy the intent to the fellow ibn
    return getstate(idagnode)
end

"""
Handles intra-domain connectivity intents.
Delegates all constraints to a PathIntent
"""
function shortestavailpath!(ibn::IBN, dag::IntentDAG, idagnode::IntentDAGNode{R}, ::IntraIntent; k = 5) where {R<:ConnectivityIntent}
    conint = idagnode.intent
    src = getsrcdom(conint) == getid(ibn) ? getsrcdomnode(conint) : localnode(ibn, getsrc(conint), subnetwork_view=false)
    dst = getdstdom(conint) == getid(ibn) ? getdstdomnode(conint) : localnode(ibn, getdst(conint), subnetwork_view=false)
    paths = yen_k_shortest_paths(ibn.cgr.flatgr, src, dst, linklengthweights(ibn.cgr.flatgr), k).paths
#    interconstraints = Dict{Int, Vector{IntentConstraint}}()
    for path in paths
        pint = getcompliantintent(ibn, conint, PathIntent, path)
        if pint !== nothing && isavailable(ibn, dag, pint)
            childnode = addchild!(dag, idagnode.id, pint)
            #create a lowlevel intent for port allocation in the start and end node
            for lli in lowlevelintents(ibn, childnode.intent)
                # if another's ibn node inside the path, issue remoteintent
                if lli.node in transnodes(ibn, subnetwork_view = false)
                    pairconstr = intent2constraint(lli, ibn)
                    delegate_edgeintent(ibn, dag, childnode, pairconstr, shortestavailpath!)
#                    push2dict!(interconstraints, pairconstr.first, pairconstr.second)
                else
                    addchild!(dag, childnode.id, lli)
                end
            end
#            push2dict!(interconstraints, shortestavailpath!(ibn, dag, childnode, IntraIntent()))
            shortestavailpath!(ibn, dag, childnode, IntraIntent())
            try2setstate!(idagnode, dag, ibn, Val(compiled))
            break
        end
    end
    # Delegate edge intents if no parent to push
#    isroot(dag, idagnode) &&  delegate_edgeintents(ibn, dag, idagnode, interconstraints, shortestavailpath!)

#    return interconstraints
end

function shortestavailpath!(ibn::IBN, dag::IntentDAG, idagnode::IntentDAGNode{R}, ::IntraIntent) where {R<:PathIntent}
    pathint = idagnode.intent
    interconstraints = Dict{Int, Vector{IntentConstraint}}()
    cc = getfirst(x -> x isa CapacityConstraint, pathint.constraints)
    if cc !== nothing
        # choose transponder
        # TODO parametric
        transponders = sort(filter(x -> getrate(x) >= cc.drate, transponderset()),  by = x -> IBNFramework.getoptreach(x), rev=true)
        for transp in transponders
            if getoptreach(transp) < distance(ibn, pathint.path)
                error("Regeneration needed. Still not implemented.")
            else
                fs = [get_prop(ibn.cgr, e, :link) for e in edgeify(pathint.path)]
                startingslot = firstfit(fs, getslots(transp))
                speint = getcompliantintent(ibn, pathint, SpectrumIntent, pathint.path, getrate(transp), startingslot:startingslot+getslots(transp)-1)
                if speint !== nothing && isavailable(ibn, dag, speint)
                    childnode = addchild!(dag, idagnode.id, speint)
                    for lli in lowlevelintents(ibn, childnode.intent)
                        if lli.node in transnodes(ibn, subnetwork_view = false)
                            pairconstr = intent2constraint(lli, ibn)
                            delegate_edgeintent(ibn, dag, childnode, pairconstr, shortestavailpath!)
#                            push2dict!(interconstraints, pairconstr.first, pairconstr.second)
                        else
                            addchild!(dag, childnode.id, lli)
                        end
                    end
                    try2setstate!(childnode, dag, ibn, Val(compiled))
                    try2setstate!(idagnode, dag, ibn, Val(compiled))
                    break
                end
            end
        end
    end
#    return interconstraints
end

function shortestavailpath!(ibn::IBN, dag::IntentDAG, idagnode::IntentDAGNode{R}; k=5) where {R<:DomainConnectivityIntent}
    intent = getintent(idagnode)
    neibn, yenstates = calc_kshortestpath(ibn, intent)
    paths = reduce(vcat, getfield.(yenstates, :paths))
    dists = reduce(vcat, getfield.(yenstates, :dists))
    sortidx = sortperm(dists)
    dists .= dists[sortidx]
    paths .= paths[sortidx]
    for path in paths
        pint = getcompliantintent(ibn, intent, PathIntent, path)
        if pint !== nothing && isavailable(ibn, dag, pint)
            childnode = addchild!(dag, idagnode.id, pint)
            #create a lowlevel intent for port allocation in the start and end node
            for lli in lowlevelintents(ibn, childnode.intent)
                if lli.node in transnodes(ibn, subnetwork_view = false)
                    pairconstr = intent2constraint(lli, ibn)
                    delegate_edgeintent(ibn, dag, childnode, pairconstr, shortestavailpath!)
#                    push2dict!(interconstraints, pairconstr.first, pairconstr.second)
                else
                    addchild!(dag, childnode.id, lli)
                end
            end
            shortestavailpath!(ibn, dag, childnode, IntraIntent())
            try2setstate!(idagnode, dag, ibn, Val(compiled))
            break
        end
    end
    return getstate(idagnode)
end

function calc_kshortestpath(ibn::IBN, intent::DomainConnectivityIntent{Tuple{Int,Int}, Int}; k=5)
    neibn = getibn(ibn, getdst(intent))
    yenstates = [yen_k_shortest_paths(ibn.cgr.flatgr, getsrc(intent)[2], transnode, linklengthweights(ibn.cgr.flatgr), k) 
                 for transnode in nodesofcontroller(ibn, getindex(ibn, neibn))]
    return (neibn, yenstates)
end
function calc_kshortestpath(ibn::IBN, intent::DomainConnectivityIntent{Int, Tuple{Int,Int}}; k=5)
    neibn = getibn(ibn, getsrc(intent))
    yenstates = [yen_k_shortest_paths(ibn.cgr.flatgr, transnode, getdst(intent)[2], linklengthweights(ibn.cgr.flatgr), k) 
                 for transnode in nodesofcontroller(ibn, getindex(ibn, neibn))]
    return (neibn, yenstates)
end
