abstract type IntentDomain end
struct IntraIntent <: IntentDomain end
abstract type IntentDirection end
struct IntentForward <: IntentDirection end
struct IntentBackward <: IntentDirection end
struct InterIntent{R<:IntentDirection} <: IntentDomain end
InterIntent() = InterIntent{IntentForward}()

function compile!(ibn::IBN, intr::IntentTree{R}, algmethod::F; algargs...) where {R<:Union{ConnectivityIntent},F<:Function}
    iam(ibn, neibn) = getid(ibn) == getid(neibn)
    firstforeignibnnode(ibn::IBN) = getfirst(x -> ibn.controllers[CompositeGraphs.domain(ibn.cgr,x)] isa IBN, [v for v in vertices(ibn.cgr)])
    firstnode(ibn::IBN, neibn::IBN) = getfirst(x -> ibn.controllers[CompositeGraphs.domain(ibn.cgr,x)] == neibn, [v for v in vertices(ibn.cgr)])

    success = false
    if isintraintent(ibn, intr)
        success = algmethod(ibn, intr, IntraIntent(); algargs...)
    else
        neibnsrc = getibn(ibn, getsrcdom(intr))
        neibndst = getibn(ibn, getdstdom(intr))
        if neibnsrc === nothing && neibndst !== nothing
            if iam(ibn,neibndst)
                neibn = first(getibns(ibn))
                success = algmethod(ibn, neibn, intr, InterIntent{IntentBackward}(); algargs...)
            else
                success = delegatecompilation!(ibn, neibndst, intr, algmethod; algargs...)
            end
        elseif neibnsrc !== nothing && neibndst === nothing
            if iam(ibn,neibnsrc)
                neibn = first(getibns(ibn))
                success = algmethod(ibn, neibn, intr, InterIntent{IntentForward}(); algargs...)
            else
                success = delegatecompilation!(ibn, neibnsrc, intr, algmethod; algargs...)
            end
        elseif neibnsrc !== nothing && neibndst !== nothing
            if iam(ibn,neibnsrc)
                success = algmethod(ibn, neibndst, intr, InterIntent{IntentForward}(); algargs...)
            elseif iam(ibn, neibndst)
                success = algmethod(ibn, neibnsrc, intr, InterIntent{IntentBackward}(); algargs...)
            else
                success = delegatecompilation!(ibn, neibnsrc, intr, algmethod; algargs...)
            end
        elseif neibnsrc == nothing && neibndst == nothing
            # talk to random IBN (this is where fun begins!)
            neibn = first(getibns(ibn))
            success = delegatecompilation!(ibn, neibn, intr, algmethod; algargs...)
            return false
        end
    end
    success && setstate!(intr, compiled)
    return success
end

function kshortestpath!(ibnp::IBN, ibnc::IBN, intr::IntentTree{ConnectivityIntent}, iid::InterIntent{R}; k=5) where R<:IntentDirection
    iidforward = R isa IntentForward
    if iidforward
        myintent = IBNConnectivityIntent(getsrc(intr), getid(ibnc), getconstraints(intr), getconditions(intr), missing, uncompiled)
    else
        myintent = IBNConnectivityIntent(getid(ibnc), getdst(intr) , getconstraints(intr), getconditions(intr), missing, uncompiled)
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
    success = delegateinheritcompilation!(ibnp, ibnc, intr, remintent, kshortestpath!; k=k)
    success || return false
end

function kshortestpath!(ibn::IBN, intr::IntentTree{ConnectivityIntent}, ::IntraIntent; k = 5)
    paths = yen_k_shortest_paths(ibn.cgr.flatgr, getsrc(intr)[2], getdst(intr)[2], linklengthweights(ibn.cgr.flatgr), k).paths
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

function kshortestpath!(ibn::IBN, intenttr::IntentTree{R}; k=5) where {R<:IBNConnectivityIntent}
    success = false
    neibn, yenstates = kshortestpathcalc(ibn, intenttr)
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

function kshortestpathcalc(ibn::IBN, intenttr::IntentTree{IBNConnectivityIntent{Tuple{Int,Int}, Int}}; k=5)
    neibn = getibn(ibn, getdst(intenttr))
    yenstates = [yen_k_shortest_paths(ibn.cgr.flatgr, getsrc(intenttr)[2], transnode, linklengthweights(ibn.cgr.flatgr), k) 
                 for transnode in nodesofcontroller(ibn, getindex(ibn, neibn))]
    return (neibn, yenstates)
end
function kshortestpathcalc(ibn::IBN, intenttr::IntentTree{IBNConnectivityIntent{Int, Tuple{Int,Int}}}; k=5)
    neibn = getibn(ibn, getsrc(intenttr))
    yenstates = [yen_k_shortest_paths(ibn.cgr.flatgr, transnode, getdst(intenttr)[2], linklengthweights(ibn.cgr.flatgr), k) 
                 for transnode in nodesofcontroller(ibn, getindex(ibn, neibn))]
    return (neibn, yenstates)
end
