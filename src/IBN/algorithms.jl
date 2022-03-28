"Compile intent using shortest path"
function shortestpathcompilation!(ibn::IBN, intenttr::IntentTree{ConnectivityIntent})
    #intent can be completely handled inside the IBN network
    if isintraintent(ibn, intenttr)
        #TODO adaptation for id
        path = yen_k_shortest_paths(ibn.cgr.flatgr, getsrc(intenttr)[2], getdst(intenttr)[2], linklengthweights(ibn.cgr.flatgr), 1).paths[]
        cap = [c.capacity for c in getconstraints(intenttr) if c isa CapacityConstraint][]
        setcompilation!(intenttr, ConnectivityIntentCompilation(path, cap))
        return true
    else
        #randomly pick an IBN neighborhood if intent.dst is not one of them
        # pick a transition point based on shortest path
        # deploy!
        # create an intent to connect to IBN without specifying node ? then get compilation and create the next intent.

        # neibn could be also the same ibn as now
        neibnsrc = getibn(ibn, getsrc(intenttr)[1])
        neibndst = getibn(ibn, getdst(intenttr)[1])
        if neibnsrc === nothing && neibndst !== nothing
            # check if I am the neibn
#            IBNConnectivityIntent(getsrc(intent))
            if getid(neibndst) == getid(ibn)
                # TODO the constraint will probably need to change (e.g. delay split)
                # get a random IBN to help
                neibn = first(getibns(ibn))
                IBNConnectivityIntent(getsrc(intenttr), getid(ibn), getconstraints(intenttr), getconditions(intenttr),
                                      RemoteIntentCompilation(neibn, missing), uninstalled)
            else
                remintent = newintent(intenttr.data, RemoteIntentCompilation(neibndst, missing))
                addchild!(intenttr, remintent)
            end
        elseif neibnsrc !== nothing && neibndst === nothing
            nothing
        elseif neibnsrc !== nothing && neibndst !== nothing
            if getid(neibnsrc) == getid(ibn)
                myintent = IBNConnectivityIntent(getsrc(intenttr), getid(neibndst), getconstraints(intenttr), getconditions(intenttr),
                                      missing, uncompiled)
                intentchildtr = addchild!(intenttr, myintent)
                #compile it
                shortestpathcompilation!(ibn, intentchildtr)
                setstate!(intentchildtr, compiled)
                compchild = getcompilation(intentchildtr)

                transnode = (getid(neibndst), ibn.cgr.vmap[compchild.path[end]][2])
                remintent = ConnectivityIntent(transnode, getdst(intenttr), getconstraints(intenttr), getconditions(intenttr), missing, uncompiled)
                remintenttr = addchild!(intenttr, remintent)
                remidx = addintent(ibn, neibndst, newintent(remintenttr.data))
                setcompilation!(remintent, RemoteIntentCompilation(neibndst, remidx))
                #compile the remote intent
                deployed = deploy!(ibn, neibndst, remidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus())
                if !deployed
                    error("could not deploy the intent")
                else
                    setstate!(neibndst.intents[remidx], compiled)
                    setstate!(intenttr, compiled)
                end

            elseif getid(neibndst) == getid(ibn)
                nothing
            else
                nothing
            end
        else
            @warn("cannot communicate to any of the two ibns")
        end
        @warn("inter-IBN intents WIP for `shortestpathcompilation`")
        return true
    end
end


"connect src IBNs without specific src/dst node requirements"
function shortestpathcompilation!(ibn::IBN, intenttr::IntentTree{IBNConnectivityIntent{Tuple{Int, Int}, Int}})
    neibnsrc = getibn(ibn, getsrc(intenttr)[1])
    neibndst = getibn(ibn, getdst(intenttr))
    if neibnsrc === nothing && neibndst !== nothing
        nothing
    elseif neibnsrc !== nothing && neibndst === nothing
        nothing
    elseif neibnsrc !== nothing && neibndst !== nothing
        if getid(neibnsrc) == getid(ibn)
            yenstates = [yen_k_shortest_paths(ibn.cgr.flatgr, getsrc(intenttr)[2], transnode, linklengthweights(ibn.cgr.flatgr), 1) 
                         for transnode in nodesofcontroller(ibn, getindex(ibn, neibndst))]
            paths = reduce(vcat, getfield.(yenstates, :paths))
            dists = reduce(vcat, getfield.(yenstates, :dists))
            sortidx = sortperm(dists)
            dists .= dists[sortidx]
            paths .= paths[sortidx]
            # TODO check constraints feasibility
            cap = [c.capacity for c in getconstraints(intenttr) if c isa CapacityConstraint][]
            setcompilation!(intenttr, ConnectivityIntentCompilation(paths[1], cap))
        elseif getid(neibndst) == getid(ibn)
            nothing
        else
            nothing
        end
    else
        @warn("cannot communicate to any of the two ibns")
    end
end
