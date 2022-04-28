function compile!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode{R}, algmethod::F; algargs...) where {R<:Union{ConnectivityIntent},F<:Function}
    iam(ibn, neibn) = getid(ibn) == getid(neibn)
    firstforeignibnnode(ibn::IBN) = getfirst(x -> ibn.controllers[CompositeGraphs.domain(ibn.cgr,x)] isa IBN, [v for v in vertices(ibn.cgr)])
    firstnode(ibn::IBN, neibn::IBN) = getfirst(x -> ibn.controllers[CompositeGraphs.domain(ibn.cgr,x)] == neibn, [v for v in vertices(ibn.cgr)])

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
                state = algmethod(ibn, dag, neibn, idagn, InterIntent{IntentBackward}(); algargs...)
            else
                state = delegateintent!(ibn, neibndst, idagn, algmethod; algargs...)
            end
        elseif neibnsrc !== nothing && neibndst === nothing
            if iam(ibn,neibnsrc)
                neibn = first(getibns(ibn))
                state = algmethod(ibn, neibn, idagn, InterIntent{IntentForward}(); algargs...)
            else
                state = delegateintent!(ibn, neibnsrc, idagn, algmethod; algargs...)
            end
        elseif neibnsrc !== nothing && neibndst !== nothing
            if iam(ibn,neibnsrc)
                state = algmethod(ibn, neibndst, dag, idagn, InterIntent{IntentForward}(); algargs...)
            elseif iam(ibn, neibndst)
                state = algmethod(ibn, neibnsrc, dag, idagn, InterIntent{IntentBackward}(); algargs...)
            else
                state = delegateintent!(ibn, neibnsrc, idagn, algmethod; algargs...)
            end
        elseif neibnsrc == nothing && neibndst == nothing
            # talk to random IBN (this is where fun begins!)
            neibn = first(getibns(ibn))
            state = delegateintent!(ibn, neibn, idagn, algmethod; algargs...)
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
        lli = NodeSpectrumIntent(node, CompositeGraphs.edge(ibn.cgr, cedg), sreqs.frslots, sreqs.bandwidth)
        addchild!(dag, getid(idn), lli)
    end
    try2setstate!(idn, dag, ibn, Val(compiled))
end

"""
To solve an EdgeIntent, we basically need to only satisfy the constraints
"""
function kshortestpath_opt!(ibn::IBN, dag::IntentDAG, idagnode::IntentDAGNode{R}) where {R<:EdgeIntent}
    intent = getintent(idagnode)
    if applicable(iterate, getconstraints(intent))
        for constr in getconstraints(intent)
            compile!(ibn, dag, idagnode, constr)
        end
    else
        compile!(ibn, dag, idagnode, getconstraints(intent))
    end
end

function kshortestpath!(ibnp::IBN, ibnc::IBN, intr::IntentDAGNode{ConnectivityIntent}, iid::InterIntent{R}; k=5) where R<:IntentDirection
    iidforward = R <: IntentForward
    if iidforward
        myintent = DomainConnectivityIntent(getsrc(intr), getid(ibnc), getconstraints(intr), getconditions(intr), missing, uncompiled)
    else
        myintent = DomainConnectivityIntent(getid(ibnc), getdst(intr) , getconstraints(intr), getconditions(intr), missing, uncompiled)
    end
    intentchildtr = addchild!(intr, myintent)
    success = compile!(ibnp, intentchildtr, kshortestpath!; k=k)
    success || return false

    # create an intent for fellow ibn
    compchild = getcompilation(intentchildtr)
    if iidforward
        transnode = (getid(ibnc), ibnp.cgr.vmap[compchild.path[end]][2])
        remintent = ConnectivityIntent(transnode, getdst(intr), getconstraints(intr), getconditions(intr), missing, uncompiled)
    else
        transnode = (getid(ibnc), ibnp.cgr.vmap[compchild.path[1]][2])
        remintent = ConnectivityIntent(getsrc(intr), transnode, getconstraints(intr), getconditions(intr), missing, uncompiled)
    end

    # deploy the intent to the fellow ibn
    success = delegateintent!(ibnp, ibnc, intr, remintent, kshortestpath!; k=k)
    success || return false
end

function kshortestpath!(ibn::IBN, intr::IntentDAGNode{R}, ::IntraIntent; k = 5) where {R<:ConnectivityIntent}
    src = getsrcdom(intr) == getid(ibn) ? getsrcdomnode(intr) : localnode(ibn, getsrc(intr), subnetwork_view=false)
    dst = getdstdom(intr) == getid(ibn) ? getdstdomnode(intr) : localnode(ibn, getdst(intr), subnetwork_view=false)
    paths = yen_k_shortest_paths(ibn.cgr.flatgr, src, dst, linklengthweights(ibn.cgr.flatgr), k).paths
    # TODO what about other constraints
    cap = [c.capacity for c in getconstraints(intr) if c isa CapacityConstraint][]
    # take first path which is available
    for path in paths
        if isavailable(ibn, path, cap)
            setcompilation!(intr, ConnectivityIntentCompilation(path, cap))
            return true
        end
    end
    return false
end

function kshortestpath_opt!(ibnp::IBN, ibnc::IBN, dag::IntentDAG, idagnode::IntentDAGNode{T}, iid::InterIntent{R} ;
                k=5)  where {T<:ConnectivityIntent, R<:IntentDirection}
    iidforward = R <: IntentForward
    conint = idagnode.intent
    if iidforward
        myintent = DomainConnectivityIntent(getsrc(conint), getid(ibnc), getconstraints(conint), getconditions(conint))
    else
        myintent = DomainConnectivityIntent(getid(ibnc), getdst(conint) , getconstraints(conint), getconditions(conint))
    end
    intentchildtr = addchild!(dag, getid(idagnode), myintent)
    success = compile!(ibnp, dag, intentchildtr, kshortestpath_opt!; k=k)
    success || return false

    # create an intent for fellow ibn
    compchild = getcompilation(intentchildtr)
    if iidforward
        transnode = (getid(ibnc), ibnp.cgr.vmap[compchild.path[end]][2])
        remintent = ConnectivityIntent(transnode, getdst(intr), getconstraints(intr), getconditions(intr), missing, uncompiled)
    else
        transnode = (getid(ibnc), ibnp.cgr.vmap[compchild.path[1]][2])
        remintent = ConnectivityIntent(getsrc(intr), transnode, getconstraints(intr), getconditions(intr), missing, uncompiled)
    end

    # deploy the intent to the fellow ibn
    success = delegateintent!(ibnp, ibnc, intr, remintent, kshortestpath!; k=k)
    success || return false
end

"Delegates all constraints to a PathIntent"
function kshortestpath_opt!(ibn::IBN, dag::IntentDAG, idagnode::IntentDAGNode{R}, ::IntraIntent; k = 5) where {R<:ConnectivityIntent}
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
                    delegate_edgeintent(ibn, dag, childnode, pairconstr, kshortestpath_opt!)
#                    push2dict!(interconstraints, pairconstr.first, pairconstr.second)
                else
                    addchild!(dag, childnode.id, lli)
                end
            end
#            push2dict!(interconstraints, kshortestpath_opt!(ibn, dag, childnode, IntraIntent()))
            kshortestpath_opt!(ibn, dag, childnode, IntraIntent())
            try2setstate!(idagnode, dag, ibn, Val(compiled))
            break
        end
    end

    # Delegate edge intents if no parent to push
#    isroot(dag, idagnode) &&  delegate_edgeintents(ibn, dag, idagnode, interconstraints, kshortestpath_opt!)

#    return interconstraints
end

function kshortestpath_opt!(ibn::IBN, dag::IntentDAG, idagnode::IntentDAGNode{R}, ::IntraIntent) where {R<:PathIntent}
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
                            delegate_edgeintent(ibn, dag, childnode, pairconstr, kshortestpath_opt!)
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

function kshortestpath_opt!(ibn::IBN, dag::IntentDAG, idagnode::IntentDAGNode{R}; k=5) where {R<:DomainConnectivityIntent}
    intent = getintent(idagnode)
    neibn, yenstates = calc_kshortestpath(ibn, intent)
    paths = reduce(vcat, getfield.(yenstates, :paths))
    dists = reduce(vcat, getfield.(yenstates, :dists))
    sortidx = sortperm(dists)
    dists .= dists[sortidx]
    paths .= paths[sortidx]
    for path in paths
        pint = getcompliant_pathintent(ibn, intent, path)
        if pint !== nothing && isavailable(ibn, dag, pint)
            childnode = addchild!(dag, idagnode.id, pint)
            #create a lowlevel intent for port allocation in the start and end node
            for lli in lowlevelintents(ibn, childnode.intent)
                addchild!(dag, childnode.id, lli)
            end
            kshortestpath_opt!(ibn, dag, childnode, IntraIntent())
            try2setstate!(idagnode, dag, ibn, Val(compiled))
            break
        end
    end
    return getstate(idagnode)
end

function kshortestpath!(ibn::IBN, intenttr::IntentDAGNode{R}; k=5) where {R<:DomainConnectivityIntent}
    success = false
    neibn, yenstates = calc_kshortestpath(ibn, intenttr)
    paths = reduce(vcat, getfield.(yenstates, :paths))
    dists = reduce(vcat, getfield.(yenstates, :dists))
    sortidx = sortperm(dists)
    dists .= dists[sortidx]
    paths .= paths[sortidx]
    # TODO check constraints feasibility
    cap = [c.capacity for c in getconstraints(intenttr) if c isa CapacityConstraint][]
    for path in paths
        if isavailable(ibn, path, cap)
            setcompilation!(intenttr, ConnectivityIntentCompilation(paths[1], cap))
            return true
        end
    end
    return success
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
