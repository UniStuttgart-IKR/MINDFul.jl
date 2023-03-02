"$(TYPEDSIGNATURES)"
function compile!(ibn::IBN, idagn::IntentDAGNode{R}, algmethod::F; algargs...) where {R<:Union{ConnectivityIntent},F<:Function}
    iam(ibn, neibn) = getid(ibn) == getid(neibn)
    firstforeignibnnode(ibn::IBN) = getfirst(x -> ibn.controllers[NestedGraphs.subgraph(ibn.ngr,x)] isa IBN, [v for v in vertices(ibn.ngr)])
    firstnode(ibn::IBN, neibn::IBN) = getfirst(x -> ibn.controllers[NestedGraphs.subgraph(ibn.ngr,x)] == neibn, [v for v in vertices(ibn.ngr)])

    conint = idagn.intent
#    if getsrc(conint) == getdst(conint)
#        @info "Cannot compile a connectivity intent between the same node"
#        return getstate(idagn)
#    end
    if isintraintent(ibn, conint)
        state = algmethod(ibn, idagn, IntraIntent(); algargs...)
    else
        neibnsrc = getibn(ibn, getsrcdom(conint))
        neibndst = getibn(ibn, getdstdom(conint))
        if neibnsrc === nothing && neibndst !== nothing
            if iam(ibn,neibndst)
                neibn = first(getibns(ibn))
#                state = algmethod(ibn, neibn, idagn, InterIntent{IntentBackward}(); algargs...)
                #state = delegateintent!(ibn, neibndst, idagn, idagn.intent, algmethod; algargs...)
                for neibn in getibns(ibn) #it's logical so I don't really care whom I ask
                    state = delegateintent!(ibn, neibn, idagn, idagn.intent, algmethod; algargs...)
                    state == compiled && break
                end
            else
                error("Connectivity intent involves source and destination irrelevant to me: IBN $(getid(ibn))")
#                state = delegateintent!(ibn, neibndst, idagn, idagn.intent, algmethod; algargs...)
            end
        elseif neibnsrc !== nothing && neibndst === nothing
            if iam(ibn,neibnsrc)
                neibn = pickupneighboringdomain(ibn, conint)
                algmethod(ibn, neibn, idagn, InterIntent{IntentForward}(); algargs...)
            else
                state = delegateintent!(ibn, neibnsrc, idagn, idagn.intent, algmethod; algargs...)
            end
        elseif neibnsrc !== nothing && neibndst !== nothing
            if iam(ibn,neibnsrc)
                state = algmethod(ibn, neibndst, idagn, InterIntent{IntentForward}(); algargs...)
            elseif iam(ibn, neibndst)
                # state = algmethod(ibn, neibnsrc, idagn, InterIntent{IntentBackward}(); algargs...)
                state = delegateintent!(ibn, neibnsrc, idagn, getintent(idagn), algmethod; algargs...)
            else
                state = delegateintent!(ibn, neibnsrc, idagn, getintent(idagn), algmethod; algargs...)
            end
        elseif neibnsrc == nothing && neibndst == nothing
            error("Connectivity intent involves source and destination unknown to me: IBN $(getid(ibn))")
#            # talk to random IBN (this is where fun begins!)
#            for neibn in getibns(ibn)
#                delegateintent!(ibn, neibn, idagn, idagn.intent, algmethod; algargs...)
#                idagn.state == compiled && break
#            end
#            return false
        end
    end
    return idagn.state
end

"""
$(TYPEDSIGNATURES)

The connectivity intent has source node inside `ibn` but destination node unknown.
Decide whom to delegate the intent to.
"""
function pickupneighboringdomain(ibn::IBN, conint::ConnectivityIntent)
    neibns = collect(getibns(ibn))
    for neibn in neibns
        if any(gtc -> getnode(gtc)[1] == getid(neibn), filter(c -> c isa GoThroughConstraint, getconstraints(conint)))
            return neibn
        end
    end
    # otherwise randomly select one
    # return neibns[rand(eachindex(neibns))]
    return first(neibns)
end

"$(TYPEDSIGNATURES)"
function compile!(ibn::IBN, idagn::IntentDAGNode, ::Type{LightpathIntent}, path, transmodl, lightpathtype; algargs...)
    dag = getintentdag(ibn)
    lpint = getcompliantintent(ibn, getintent(idagn), LightpathIntent, path, transmodl, lightpathtype)
    isnothing(lpint) && error("Could not create a LightpathIntent")
    # see if there is already such a lightpath; if yes, groom it in.
    if lightpathtype ∈ [borderinitiatelightpath, border2borderlightpath]
        uuidlp = searchforlightpathsameinitialreqs(dag, lpint)
        if !isnothing(uuidlp)
            add_edge!(dag, getid(idagn), uuidlp, nothing)
            return getintentnode(ibn, uuidlp)
        end
    end
    isavailable(ibn, lpint) || error("intent resources are not available")
    lpintnode = addchild!(dag, getid(idagn), lpint)
    for lli in lowlevelintents(lpintnode.intent)
        addchild!(dag, lpintnode.id, lli)
    end
    return lpintnode
end

"$(TYPEDSIGNATURES)"
function compile!(ibn::IBN, lpintnode::IntentDAGNode{<:LightpathIntent}, ::Type{<:SpectrumIntent}, lightpathtype, spallocfun=firstfit)
    dag = getintentdag(ibn)

    if lightpathtype in [borderinitiatelightpath, border2borderlightpath]
        bicidx = findfirst(c-> c isa BorderInitiateConstraint, getconstraints(getintent(lpintnode)))
        lpr = getreqs(getconstraints(getintent(lpintnode))[bicidx])
        spslots = lpr.spslots
    else
        fs = [getlink(ibn, e) for e in edgeify(getpath(getintent(lpintnode)))]
        trmdlslots = getfreqslots(gettransmodl(getintent(lpintnode)))
        startingslot = spallocfun(fs, trmdlslots)
        startingslot === nothing && error("Not enough slots for transmission module chosen")
        spslots = startingslot:startingslot+trmdlslots-1
    end
    speint = getcompliantintent(ibn, getintent(lpintnode), SpectrumIntent, getpath(getintent(lpintnode)), getrate(getintent(lpintnode)), spslots)
    speint === nothing && error("Could not create a SpectrumAllocationIntent")

    if isavailable(ibn, speint)
        speintnode = addchild!(dag, getid(lpintnode), speint)
        for lli in lowlevelintents(speintnode.intent)
            addchild!(dag, speintnode.id, lli)
        end
        return speintnode
#        try2setstate!(speintnode, ibn, Val(compiled); time)
#        try2setstate!(idagnode, ibn, Val(compiled); time)
    else
        return nothing
    end
end

#---- following a short example `algmethod` ----
#
"""
$(TYPEDSIGNATURES) 

Handles intra-domain connectivity intents.
If path can be reached with a transmission module, it selects the one with lowest cost and mode with lowest slots.
If it cannot be reached, it breaks it down in the middle to 2 connectivity intents.
Intent source and destination are always finishing up in the router.
No grooming is supported.
"""
function shortestavailpath!(ibn::IBN, idagnode::IntentDAGNode{R}, ::IntraIntent; time, k = 100) where {R<:ConnectivityIntent}
    conint = getintent(idagnode)
    source = localnode(ibn, getsrc(conint); subnetwork_view=false)
    dest = localnode(ibn, getdst(conint); subnetwork_view=false)

    yenpaths = yen_k_shortest_paths(getgraph(ibn), source, dest, linklengthweights(ibn), k)
    deployfirstavailablepath!(ibn, idagnode, yenpaths.paths, yenpaths.dists; time)
    return getstate(idagnode)
end

"""
$(TYPEDSIGNATURES)

`paths` have the paths and `dists` the corresponding distances in km
Every time allocates new transmission modules, i.e., no grooming supported.
"""
function deployfirstavailablepath!(ibn::IBN, idagnode::IntentDAGNode, paths, dists; time)
    conint = getintent(idagnode)
    for (path,dist) in zip(paths, dists)
        bicidx = findfirst(c -> c isa BorderInitiateConstraint, getconstraints(conint))
        if !isnothing(bicidx)
            bic = getconstraints(conint)[bicidx]
            # Trivially compile the border connectivity intent right here right now
            # get compatible transmission module from LightpathRequirements in destination path[1]
            transmodl = pickcheapesttransmodl(ibn, bic.reqs, path[1])
            realsource = localnode(ibn, src(bic.edg); subnetwork_view=false)
            lptype1 = borderinitiatelightpath
            lpintnode = compile!(ibn, idagnode, LightpathIntent, [realsource, path[1]], transmodl, lptype1)
            speintnode = compile!(ibn, lpintnode, SpectrumIntent, lptype1)
#            deleteat!(getconstraints(conint), bicidx)
            try2setstate!(speintnode, ibn, Val(compiled); time)
            path[end] == path[1] && break
        end
        lptype = fulllightpath
        if any(c -> c isa BorderTerminateConstraint, getconstraints(conint))
            lptype = borderterminatelightpath
        end

        breakandcontinue = false
        for gtc in filter(c -> c isa GoThroughConstraint ,getconstraints(conint))
            if getnode(gtc)[1] == getid(ibn)
                if localnode(ibn, getnode(gtc); subnetwork_view=false) ∉ path
                    breakandcontinue = true
                    break;
                end
            end
        end
        breakandcontinue && continue

        transmodl = pickcheapesttransmodl(ibn, dist, path[1])
        if isnothing(transmodl) # break up path in 2 connectivity intents
            error("Appropriate transmission module doesn't exist. Need to break up connectivity intent in 2. Still not implemented.")
        else
            consavailspslots = reduce(.&, [getspectrumslots(getlink(ibn, e)) for e in edgeify(path)])
            longestconsecutiveblock(==(true), consavailspslots) >= getfreqslots(transmodl) || continue
            lpintnode = compile!(ibn, idagnode, LightpathIntent, path, transmodl, lptype)
            speintnode = compile!(ibn, lpintnode, SpectrumIntent, lptype, firstfit)
            try2setstate!(speintnode, ibn, Val(compiled); time)
            break
        end
    end
end

"""
$(TYPEDSIGNATURES)

Return transmission module and mode to use.
If none is appropriate, return `nothing`
"""
function pickcheapesttransmodl(ibn::IBN, optreachreq::Real, source::Int)
    sortedtransmodls = sort(gettransmodulespool(getmlnode(ibn, source)), by=trmdl->getcost(trmdl))
    for transmodl in sortedtransmodls
        toselect = findmin(x -> ustrip(getoptreach(x)) >= optreachreq ? getfreqslots(x) : +Inf, gettransmissionmodes(transmodl))
        if !isnothing(toselect)
            copied = deepcopy(transmodl)
            setselection!(copied, toselect[2])
            return copied
        end
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

If none is appropriate, return `nothing`
"""
function pickcheapesttransmodl(ibn::IBN, lpr::LightpathRequirements, source::Int)
    sortedtransmodls = sort(gettransmodulespool(getmlnode(ibn, source)), by=trmdl->getcost(trmdl))
    for transmodl in sortedtransmodls
        ff = findfirst(gettransmissionmodes(transmodl)) do transprop 
            length(lpr.spslots) == getfreqslots(transprop) && lpr.optreach <= getoptreach(transprop) &&
            lpr.rate <= getrate(transprop)
        end
        if !isnothing(ff)
            copied = deepcopy(transmodl)
            setselection!(copied, ff)
            return copied
        end
    end
    return nothing
end

"$(TYPEDSIGNATURES) Handles interdomain connectivity intents"
function shortestavailpath!(myibn::IBN, neibn::IBN, idagnode::IntentDAGNode{T}, iid::InterIntent{R} ;
                time, k=5)  where {T<:ConnectivityIntent, R<:IntentDirection}
    dag = getintentdag(myibn)
    iidforward = R <: IntentForward
    conint = getintent(idagnode)

    globalizedbordernodes = globalnode.([myibn], bordernodes(myibn; subnetwork_view=false))
    bordergtc = getfirst(gtc -> getnode(gtc) in globalizedbordernodes ,filter(c -> c isa GoThroughConstraint, getconstraints(conint)))

    if iidforward
        if getdst(conint) in globalizedbordernodes
            myintent = ConnectivityIntent(getsrc(conint), getdst(conint), getrate(conint),
                                          vcat(BorderTerminateConstraint() , getconstraints(conint)), getconditions(conint))
        elseif !isnothing(bordergtc)
            myintent = ConnectivityIntent(getsrc(conint), getnode(bordergtc), getrate(conint),
                                          vcat(BorderTerminateConstraint() , getconstraints(conint)), getconditions(conint))
        else
            myintent = DomainConnectivityIntent(getsrc(conint), getid(neibn), getrate(conint),
                                          vcat(BorderTerminateConstraint() , getconstraints(conint)), getconditions(conint))
        end
    else
        if getsrc(conint) in globalizedbordernodes
            myintent = ConnectivityIntent(getdst(conint), getsrc(conint), getrate(conint),
                          vcat(ReverseConstraint(), BorderTerminateConstraint() , getconstraints(conint)), getconditions(conint))
        elseif !isnothing(bordergtc)
            myintent = ConnectivityIntent(getdst(conint), getnode(bordergtc), getrate(conint),
                                          vcat(BorderTerminateConstraint() , getconstraints(conint)), getconditions(conint))
        else
            myintent = DomainConnectivityIntent(getdst(conint), getid(neibn), getrate(conint),
                                  vcat(ReverseConstraint(), BorderTerminateConstraint() , getconstraints(conint)), getconditions(conint))
        end
    end
    domint = addchild!(dag, getid(idagnode), myintent)
    state = compile!(myibn,  domint, shortestavailpath!; time)

    # create an intent for fellow ibn
    if state == compiled
        globalviewpath = getcompiledintentpath(myibn, getid(domint))
        updatedconstraints = adjustNpropagate_constraints!(myibn, idagnode)
        transnode = globalviewpath[end]
        lpr = getlastlightpathrequirements(myibn, getid(domint))
        initconstr = BorderInitiateConstraint(NestedEdge(globalviewpath[end-1:end]...), lpr)
        if iidforward
            remintent = ConnectivityIntent(transnode, getdst(conint), getrate(conint),
                                           vcat(initconstr, updatedconstraints), getconditions(myintent))
        else
            remintent = ConnectivityIntent(transnode, getsrc(conint), getrate(conint),
                           vcat(ReverseConstraint() , initconstr, updatedconstraints), getconditions(myintent))
        end
        success = delegateintent!(myibn, neibn, idagnode, remintent, shortestavailpath!; time)
    end
    try2setstate!(idagnode, myibn, Val(compiled); time)
    return getstate(idagnode)
end

"$(TYPEDSIGNATURES)"
function shortestavailpath!(ibn::IBN, idagnode::IntentDAGNode{R}; time, k=100) where {R<:DomainConnectivityIntent}
    dag = getintentdag(ibn)
    intent = getintent(idagnode)

    srcdsts = getintrasrcdst(ibn, getintent(idagnode))

    yenpaths = [psds  for (source,dest) in srcdsts for psds in 
        let yenpaths = yen_k_shortest_paths(getgraph(ibn), source, dest, linklengthweights(ibn), k);
            zip(yenpaths.paths, yenpaths.dists)
        end]

    sort!(yenpaths; by = yp -> yp[2])
    deployfirstavailablepath!(ibn, idagnode, getfield.(yenpaths, 1), getfield.(yenpaths, 2); time)

    return getstate(idagnode)
end

"$(TYPEDSIGNATURES) Return a collection of valid sources and destinations combinations in the intranet"
function getintrasrcdst(ibn::IBN, intent::DomainConnectivityIntent{Tuple{Int,Int}, Int})
    neibnidx = getlocalibnindex(ibn, getdst(intent))
    dests = nodesofcontroller(ibn, neibnidx)
    [(localnode(ibn, getsrc(intent); subnetwork_view=false),d) for d in dests]
end

"$(TYPEDSIGNATURES) Return a collection of valid sources and destinations combinations in the intranet"
function getintrasrcdst(ibn::IBN, intent::DomainConnectivityIntent{Int, Tuple{Int,Int}})
    neibnidx = getlocalibnindex(ibn, getsrc(intent))
    sours = nodesofcontroller(ibn, neibnidx)
    [(s, localnode(ibn, getdst(intent); subnetwork_view=false)) for s in sours]
end
