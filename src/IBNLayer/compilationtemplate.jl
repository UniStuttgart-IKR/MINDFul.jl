"""
$(TYPEDSIGNATURES)

A template compilation function that can be extended

Give in the following hook functions:
- `intradomainalgfun` is used as compilation algorithm for the intents handled internally. 
It should return a `Symbol` as a return code. 
Common return codes are found in `MINDFul.ReturnCodes`
```
intradomainalgfun(
    ibnf::IBNFramework, 
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    ; datetime::DateTime
) -> Symbol
```

- `prioritizesplitnodes` is called when optical reach is not enough to have a lightpath end-to-end to serve the intent and a path to split was already selected.
The node selected will break the intent into two pieces with the node standing in between.
This function should return a vector of `SplitGlobalNode`s with decreasing priority of which node should be chosen.
The same split node might be returned multiple times, but with different availability requirements.
```
prioritizesplitnodes(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode,
) -> Vector{GlobalNode}
```

- `prioritizesplitbordernodes` is called to select the border node to work as the source node for the delegated intent in a neighboring domain.
This function should return a vector of `SplitGlobalNode`s with decreasing priority of which node should be chosen.
The same split node might be returned multiple times, but with different availability requirements.
```
prioritizesplitbordernodes(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
) -> Vector{GlobalNode}
```
"""
@recvtime function compileintenttemplate!(
        ibnf::IBNFramework,
        idagnode::IntentDAGNode{<:ConnectivityIntent};
        verbose::Bool = false,
        intradomainalgfun::F1,
        prioritizegrooming::F2 = prioritizegrooming_default,
        prioritizesplitnodes::F3 = prioritizesplitnodes_longestfirstshortestpath,
        prioritizesplitbordernodes::F4 = prioritizesplitbordernodes_shortestorshortestrandom,
        cachedintentresult = Dict{ConnectivityIntent, Symbol}(),
        maximumsplitlevel::Int = 1
        # maximumsplitlevel::Int = typemax(Int)
    ) where {F1 <: Function, F2 <: Function, F3 <: Function, F4 <: Function}
    sourceglobalnode = getsourcenode(getintent(idagnode))
    destinationglobalnode = getdestinationnode(getintent(idagnode))

    returncode::Symbol = ReturnCodes.FAIL
    verbose && @info("Compiling intent ", getidagnodeid(idagnode), getintent(idagnode))

    limitedsplitconstraint = getfirst(c -> c isa LimitedSplitConstraint, getconstraints(getintent(idagnode)))
    finalmaximumsplitlevel = isnothing(limitedsplitconstraint) ? maximumsplitlevel : min(maximumsplitlevel, getmaximumsplitlevel(limitedsplitconstraint))
    currentsplitlevel = isnothing(limitedsplitconstraint) ? 0 : getsplitlevel(limitedsplitconstraint)

    verbose && @info("splitting level: $(currentsplitlevel)")

    if !issuccess(returncode)
        # if didn't groom
        if isinternalorborderintent(ibnf, getintent(idagnode); noremoteintent = true)
            # intra-domain
            returncode = haskey(cachedintentresult, getintent(idagnode)) ? cachedintentresult[getintent(idagnode)] : intradomainalgfun(ibnf, idagnode, cachedintentresult; verbose, @passtime)
            if !haskey(cachedintentresult, getintent(idagnode)) 
                cachedintentresult[getintent(idagnode)] = returncode
            end
            if returncode === ReturnCodes.FAIL_OPTICALREACH_OPTINIT || returncode === ReturnCodes.FAIL_SPECTRUM_OPTINIT || returncode === ReturnCodes.FAIL_SRCTRANSMDL
                verbose && @info("Compiling intent as whole failed with $(returncode). Attempting to split internal intent $(getintent(idagnode)) in two...")
                returncodetemp, _ = uncompileintent!(ibnf, getidagnodeid(idagnode); @passtime) 
                @assert returncodetemp == ReturnCodes.SUCCESS

                if currentsplitlevel < finalmaximumsplitlevel
                    # get a node in between the shortest paths
                    candidatesplitglobalnodes = prioritizesplitnodes(ibnf, idagnode)
                    isempty(candidatesplitglobalnodes) && return ReturnCodes.FAIL_OPTICALREACH_OPTINIT_NONODESPLIT

                    for splitglobalnode in candidatesplitglobalnodes
                        verbose && @info("Attenmpting splitting intent $(getintent(idagnode)) at GlobalNode", splitglobalnode)
                        returncode = splitandcompileintradomainconnecivityintent!(
                            ibnf, 
                            idagnode, 
                            intradomainalgfun, 
                            splitglobalnode,
                            cachedintentresult; 
                            verbose, 
                            prioritizegrooming,
                            prioritizesplitnodes,
                            prioritizesplitbordernodes,
                            maximumsplitlevel,
                            @passtime)
                        if issuccess(returncode)
                            break
                        else
                            returncodetemp, _ = uncompileintent!(ibnf, getidagnodeid(idagnode); @passtime)
                            @assert returncodetemp == ReturnCodes.SUCCESS
                        end
                    end
                end
            end
            updateidagnodestates!(ibnf, idagnode; @passtime)
        elseif getibnfid(ibnf) == getibnfid(sourceglobalnode) && getibnfid(ibnf) !== getibnfid(destinationglobalnode)
            # source intra-domain , destination cross-domain
            # border-node
            if isbordernode(ibnf, destinationglobalnode)
                verbose && @info("Splitting at the border node")
                masteravcon = getfirst(x -> x isa AvailabilityConstraint, getconstraints(getintent(idagnode)))
                if isnothing(masteravcon)
                    destinationsplitglobalnode = SplitGlobalNode(destinationglobalnode)
                else
                    destinationsplitglobalnode = SplitGlobalNode(destinationglobalnode, masteravcon, nothing)
                end
                returncode = splitandcompilecrossdomainconnectivityintent(ibnf, idagnode, intradomainalgfun, destinationsplitglobalnode, cachedintentresult; verbose, @passtime)
            else
                # select border node
                candidatedestinationglobalbordernodes = prioritizesplitbordernodes(ibnf, idagnode)
                isempty(candidatedestinationglobalbordernodes) && return ReturnCodes.FAIL_OPTICALREACH_OPTINIT_NONODESPLIT
                for destinationglobalbordernode in candidatedestinationglobalbordernodes
                    uncompileintent!(ibnf, getidagnodeid(idagnode); @passtime)
                    verbose && @info("Attempting to split cross intent at GlobalNode", destinationglobalbordernode)
                    returncode = splitandcompilecrossdomainconnectivityintent(ibnf, idagnode, intradomainalgfun, destinationglobalbordernode, cachedintentresult; verbose, @passtime)
                    issuccess(returncode) && break
                end
            end
        end
    end
    return returncode
end

"""
$(TYPEDSIGNATURES)

Splits connectivity intent on `splitglobalnode` with O-E-O conversion
"""
@recvtime function splitandcompileintradomainconnecivityintent!(
    ibnf::IBNFramework, 
    idagnode::IntentDAGNode{<:ConnectivityIntent}, 
    intradomainalgfun::F, 
    splitglobalnode::SplitGlobalNode, 
    cachedintentresult::Dict{ConnectivityIntent, Symbol}; 
    verbose::Bool,
    prioritizegrooming::F2 = prioritizegrooming_default,
    prioritizesplitnodes::F3 = prioritizesplitnodes_longestfirstshortestpath,
    prioritizesplitbordernodes::F4 = prioritizesplitbordernodes_shortestorshortestrandom,
    maximumsplitlevel::Int
    ) where {F <: Function, F2 <: Function, F3 <: Function, F4 <: Function}

    sourceglobalnode = getsourcenode(getintent(idagnode))
    destinationglobalnode = getdestinationnode(getintent(idagnode))
    intent = getintent(idagnode)
    idag = getidag(ibnf)

    masteravcon = getfirst(x -> x isa AvailabilityConstraint, getconstraints(intent))

    limitedsplitconstraint = getfirst(c -> c isa LimitedSplitConstraint, getconstraints(getintent(idagnode)))
    finalmaximumsplitlevel = isnothing(limitedsplitconstraint) ? maximumsplitlevel : min(maximumsplitlevel, getmaximumsplitlevel(limitedsplitconstraint))

    newfirsthalfconstraints = Vector{AbstractIntentConstraint}(filter(x ->!(x isa OpticalTerminateConstraint) && !(x isa LimitedSplitConstraint) && !(x isa AvailabilityConstraint), getconstraints(intent)))
    if !isnothing(limitedsplitconstraint)
        push!(newfirsthalfconstraints, LimitedSplitConstraint(getsplitlevel(limitedsplitconstraint) + 1, finalmaximumsplitlevel))
    else
        push!(newfirsthalfconstraints, LimitedSplitConstraint(1, finalmaximumsplitlevel))
    end
    firsthalfavailabilityconstraint = getfirsthalfavailabilityconstraint(splitglobalnode)
    if !isnothing(firsthalfavailabilityconstraint)
        push!(newfirsthalfconstraints, firsthalfavailabilityconstraint)
    end

    firsthalfintent = ConnectivityIntent(sourceglobalnode, getglobalnode(splitglobalnode), getrate(intent), newfirsthalfconstraints)
    firsthalfidagnode = addidagnode!(ibnf, firsthalfintent; parentids = [getidagnodeid(idagnode)], intentissuer = MachineGenerated(), @passtime)
    returncode = haskey(cachedintentresult, firsthalfintent) ? cachedintentresult[firsthalfintent] : compileintenttemplate!(
                                ibnf, 
                                firsthalfidagnode; 
                                verbose,
                                intradomainalgfun = intradomainalgfun,
                                prioritizesplitnodes = prioritizesplitnodes_longestfirstshortestpath,
                                prioritizesplitbordernodes = prioritizesplitbordernodes_shortestorshortestrandom,
                                cachedintentresult = cachedintentresult,
                                maximumsplitlevel = finalmaximumsplitlevel, 
                                @passtime)
        # intradomainalgfun(ibnf, firsthalfidagnode, intentcompilationalgorithm, cachedintentresult; verbose, @passtime)

    if !haskey(cachedintentresult, firsthalfintent) 
        cachedintentresult[firsthalfintent] = returncode
    end
    updateidagnodestates!(ibnf, firsthalfidagnode; @passtime)
    issuccess(returncode) || return returncode


    newsecondhalfconstraints = Vector{AbstractIntentConstraint}(filter(x ->!(x isa OpticalInitiateConstraint) && !(x isa LimitedSplitConstraint) && !(x isa AvailabilityConstraint), getconstraints(intent)))
    if !isnothing(limitedsplitconstraint)
        push!(newsecondhalfconstraints, LimitedSplitConstraint(getsplitlevel(limitedsplitconstraint) + 1, finalmaximumsplitlevel))
    else
        push!(newsecondhalfconstraints, LimitedSplitConstraint(1, finalmaximumsplitlevel))
    end
    # revise and calculate rest of availability
    if !isnothing(masteravcon)
        firsthaldfestimatedavailability = estimateintentavailability(ibnf, firsthalfidagnode)
        secondhalfavailabilityconstraint = calcsecondhalfavailabilityconstraint(ibnf, firsthaldfestimatedavailability, masteravcon)
        push!(newsecondhalfconstraints, secondhalfavailabilityconstraint)
    end

    secondhalfintent = ConnectivityIntent(getglobalnode(splitglobalnode), destinationglobalnode, getrate(intent), newsecondhalfconstraints)
    secondhalfidagnode = addidagnode!(ibnf, secondhalfintent; parentids = [getidagnodeid(idagnode)], intentissuer = MachineGenerated(), @passtime)
    returncode = haskey(cachedintentresult, secondhalfintent) ? cachedintentresult[secondhalfintent] :  compileintenttemplate!(
                                ibnf, 
                                secondhalfidagnode; 
                                verbose,
                                intradomainalgfun = intradomainalgfun,
                                prioritizesplitnodes = prioritizesplitnodes_longestfirstshortestpath,
                                prioritizesplitbordernodes = prioritizesplitbordernodes_shortestorshortestrandom,
                                cachedintentresult = cachedintentresult,
                                maximumsplitlevel = finalmaximumsplitlevel, 
                                @passtime)


        # intradomainalgfun(ibnf, secondhalfidagnode, intentcompilationalgorithm, cachedintentresult; verbose, @passtime)
    if !haskey(cachedintentresult, secondhalfintent) 
        cachedintentresult[secondhalfintent] = returncode
    end
    updateidagnodestates!(ibnf, secondhalfidagnode; @passtime)
    return returncode
end


"""
$(TYPEDSIGNATURES)
"""
@recvtime function splitandcompilecrossdomainconnectivityintent(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intradomainalgfun::F, splitbordernode::SplitGlobalNode, cachedintentresult::Dict{ConnectivityIntent, Symbol}; verbose::Bool = false) where {F <: Function}
    idag = getidag(ibnf)
    intent = getintent(idagnode)
    returncode::Symbol = ReturnCodes.FAIL

    masteravcon = getfirst(x -> x isa AvailabilityConstraint, getconstraints(intent))

    internalintentconstraints = Vector{AbstractIntentConstraint}(filter(x -> !(x isa AvailabilityConstraint), getconstraints(intent)))
    push!(internalintentconstraints, OpticalTerminateConstraint(getdestinationnode(intent)))
    firsthalfavailabilityconstraint = getfirsthalfavailabilityconstraint(splitbordernode)
    if !isnothing(firsthalfavailabilityconstraint)
        push!(internalintentconstraints, firsthalfavailabilityconstraint)
    end

    internalintent = ConnectivityIntent(getsourcenode(intent), getglobalnode(splitbordernode), getrate(intent), internalintentconstraints)

    internalidagnode = addidagnode!(ibnf, internalintent; parentids = [getidagnodeid(idagnode)], intentissuer = MachineGenerated(), @passtime)
    returncode = haskey(cachedintentresult, internalintent) ? cachedintentresult[internalintent] : intradomainalgfun(ibnf, internalidagnode, cachedintentresult; verbose, @passtime)
    if !haskey(cachedintentresult, internalintent) 
        cachedintentresult[internalintent] = returncode
    end
    updateidagnodestates!(ibnf, internalidagnode; @passtime)

    issuccess(returncode) || return returncode

    # if is groomed no need to continue
    any(x -> getintent(x) isa CrossLightpathIntent, getidagnodedescendants(idag, getidagnodeid(internalidagnode))) && return returncode
    opticalinitiateconstraint = getopticalinitiateconstraint(ibnf, getidagnodeid(internalidagnode))
    externalintentconstraints = Vector{AbstractIntentConstraint}(filter(x -> !(x isa AvailabilityConstraint), getconstraints(intent)))
    push!(externalintentconstraints, opticalinitiateconstraint)
    # revise and calculate rest of availability
    if !isnothing(masteravcon)
        firsthaldfestimatedavailability = estimateintentavailability(ibnf, internalidagnode)
        secondhalfavailabilityconstraint = calcsecondhalfavailabilityconstraint(ibnf, firsthaldfestimatedavailability, masteravcon)
        push!(externalintentconstraints, secondhalfavailabilityconstraint)
    end

    externalintent = ConnectivityIntent(getglobalnode(splitbordernode), getdestinationnode(intent), getrate(intent), externalintentconstraints)
    externalidagnode = addidagnode!(ibnf, externalintent; parentids = [getidagnodeid(idagnode)], intentissuer = MachineGenerated(), @passtime)
    remoteibnfid = getibnfid(getdestinationnode(intent))
    internalremoteidagnode = remoteintent!(ibnf, externalidagnode, remoteibnfid; @passtime)

    # make a CrossLightpathIntent parent of last LightpathIntent and the Remote Intent
    # find the pair LightPathIntent for the RemoteIntent
    lpidagnode = getfirst(getidagnodedescendants(getidag(ibnf), getidagnodeid(internalidagnode))) do idagnode
        plightpathintent = getintent(idagnode)
        if plightpathintent isa LightpathIntent
            isonlyoptical(getdestinationnodeallocations(plightpathintent)) || return false
            lightpath = getpath(plightpathintent)
            length(lightpath) > 1 || return false
            getglobalnode(getibnag(ibnf), lightpath[end]) == getglobalnode(splitbordernode) || return false
            getglobalnode(getibnag(ibnf), lightpath[end - 1]) == getglobalnode_input(opticalinitiateconstraint) || return false
            getspectrumslotsrange(plightpathintent) == getspectrumslotsrange(opticalinitiateconstraint) || return false
            return true
        elseif plightpathintent isa ProtectedLightpathIntent
            all(x -> isonlyoptical(x), getprdestinationnodeallocations(plightpathintent)) || return false
            prlightpaths = getprpath(plightpathintent)
            all(x -> length(x) > 1, prlightpaths) || return false
            all(lightpath -> getglobalnode(getibnag(ibnf), lightpath[end]) == getglobalnode(splitbordernode), prlightpaths) || return false
            all(lightpath -> getglobalnode(getibnag(ibnf), lightpath[end - 1]) == getglobalnode_input(opticalinitiateconstraint), prlightpaths) || return false
            all(spectrumslotrange -> spectrumslotrange == getspectrumslotsrange(opticalinitiateconstraint), getprspectrumslotsrange(plightpathintent)) || return false
            return true
        end
        return false
    end
    @assert !isnothing(lpidagnode)
    # remove previous idagnodes
    # @info "removing", getntent(externalidagnode)
    # removeidagnode!(idag, getidagnodeid(externalidagnode))
    idagnodelpparents = getidagnodeparents(idag, getidagnodeid(lpidagnode))
    @assert length(idagnodelpparents) == 1
    lpparentidagnode = first(idagnodelpparents)
    # removeidagnode!(idag, lpparentidagnodeid)
    # add crosslightpath substitute
    crosslightpathintent = CrossLightpathIntent(getintent(lpparentidagnode), externalintent)
    crosslpidagnode = addidagnode!(ibnf, crosslightpathintent; parentids = [getidagnodeid(idagnode)], childids = [getidagnodeid(internalremoteidagnode), getidagnodeid(lpidagnode)], intentissuer = MachineGenerated(), @passtime)


    if getidagnodestate(internalremoteidagnode) == IntentState.Uncompiled
        # getintent brings in the internal RemoteIntent
        externalremoteidagnodeid = getidagnodeid(getintent(internalremoteidagnode))
        # compile internalremoteidagnode
        remoteibnfhandler = getibnfhandler(ibnf, remoteibnfid)
        # compilationaglorithmkeyword = getcompilationalgorithmkeyword(intentcompilationalgorithm)
        returncode = requestcompileintent_init!(ibnf, remoteibnfhandler, externalremoteidagnodeid; verbose, @passtime)
    else
        returncode = getidagnodestate(internalremoteidagnode) in [IntentState.Installed, IntentState.Compiled] ? ReturnCodes.SUCCESS : ReturnCodes.FAIL_GROOMEDREMOTEINTENTSTATE
    end

    # check state of current internalremoteidagnode
    return returncode
end

"""
$(TYPEDSIGNATURES)
Return a priority list of [`GlobalNode`](@ref).
If the target domain is known return the `GlobalNode` with the shortest distance.
If the target domain is unknown return the border node with the shortest distance, excluding the (if) source domain.
"""
function prioritizesplitbordernodes_shortestorshortestrandom(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent})
    ibnag = getibnag(ibnf)
    intentcomp = getintcompalg(ibnf)
    sourceglobalnode = getsourcenode(getintent(idagnode))
    sourcelocalnode = getlocalnode(ibnag, sourceglobalnode)
    destinationglobalnode = getdestinationnode(getintent(idagnode))
    borderlocals = getbordernodesaslocal(ibnf)
    # pick closest border node
    ibnagaweights = getibnagweights(getcachedresults(intentcomp))
    # foreach(edges(ibnag)) do ed
    #     if !getcurrentlinkstate(ibnf, ed; checkfirst = true)
    #         ibnagaweights[src(ed), dst(ed)] = typemax(eltype(ibnagaweights))
    #     end
    # end
    # TODO : perf: it's already cached
    hopdists = Graphs.dijkstra_shortest_paths(ibnag, sourcelocalnode, ibnagaweights).dists

    borderlocalsofdestdomain = filter(localnode -> getibnfid(getglobalnode(ibnag, localnode)) == getibnfid(destinationglobalnode), borderlocals)
    if !isempty(borderlocalsofdestdomain)
        # known domain
        sort!(borderlocalsofdestdomain; by = x -> hopdists[x])
        return [calcicrosssplitglobalnode(ibnf::IBNFramework, getintent(idagnode), getglobalnode(ibnag, blodd)) for blodd in borderlocalsofdestdomain]
    else
        # if unknown domain give it shortest distance border node
        borderlocalsofsrcdomain = filter(localnode -> getibnfid(getglobalnode(ibnag, localnode)) == getibnfid(sourceglobalnode), borderlocals)
        sort!(borderlocalsofsrcdomain; by = x -> hopdists[x])
        return [calcicrosssplitglobalnode(ibnf::IBNFramework, getintent(idagnode), getglobalnode(ibnag, blosd)) for blosd in borderlocalsofsrcdomain]
    end
end

"""
Almost same code as `calcintrasplitglobalnode`
"""
function calcicrosssplitglobalnode(ibnf::IBNFramework, intent::ConnectivityIntent, splitglobalnodeonly::GlobalNode)
    masteravcon = getfirst(x -> x isa AvailabilityConstraint, getconstraints(intent))
    if !isnothing(masteravcon)
        srcnode = getlocalnode(getibnag(ibnf), getsourcenode(intent))
        splitnode = getlocalnode(getibnag(ibnf), splitglobalnodeonly)
        dstglobalnode = getdestinationnode(intent)
        dstnode = getlocalnode(getibnag(ibnf), getdestinationnode(intent))
        # calculate availability first half
        firsthalfavailability = estimateintraconnectionavailability(ibnf, srcnode, splitnode)
        # calculate availability second half
        secondhalfavailability = estimatecrossconnectionavailability(ibnf, GlobalEdge(splitglobalnodeonly, dstglobalnode))
        # make decision
        firsthalfavailabilityconstraint, secondhalfavailabilityconstraint = choosecrosssplitavailabilities(masteravcon, firsthalfavailability, secondhalfavailability, getintcompalg(ibnf))
        return SplitGlobalNode(splitglobalnodeonly, firsthalfavailabilityconstraint, secondhalfavailabilityconstraint)
    else
        return SplitGlobalNode(splitglobalnodeonly) 
    end
end

"""
$(TYPEDSIGNATURES)

Return the [`GlobalNode`](@ref) contained in the shortest path that is the longest to reach given the optical reach situation.
The [`GlobalNode`](@ref) is used to break up the [`ConnectivityIntent`](@ref) into two.
This is irrelevant to all availabilities decision. It just adapts the availability constraints based on the estimations.
"""
function prioritizesplitnodes_longestfirstshortestpath(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent})
    globalnodecandidates = SplitGlobalNode[]
    ibnag = getibnag(ibnf)
    opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getintent(idagnode)))
    # I think that assert may not be needed and have to adjust for this case

    intentcomp = getintcompalg(ibnf)

    ibnagweights = getibnagweights(getcachedresults(intentcomp))
    sourceglobalnode = getsourcenode(getintent(idagnode))
    sourcelocalnode = getlocalnode(ibnag, sourceglobalnode)
    destinationglobalnode = getdestinationnode(getintent(idagnode))
    destlocalnode = getlocalnode(ibnag, destinationglobalnode)
    yenstatepaths = getyenpathsdict(getcachedresults(intentcomp))[Edge(sourcelocalnode, destlocalnode)]
    yenstatedists = getyenpathsdistsdict(getcachedresults(intentcomp))[Edge(sourcelocalnode, destlocalnode)]
    if !isnothing(opticalinitiateconstraint)
        opticalreach = getopticalreach(opticalinitiateconstraint)
        # customize per yenstate priority order
        for (dist, path) in zip(yenstatedists, yenstatepaths)
            all(ed -> getcurrentlinkstate(ibnf, ed; checkfirst = true), edgeify(path)) || continue
            # the accumulated distance from 1st up to vorletzten node in path (vorletzten to brake intent)
            diststopathnodes = accumulate(+, getindex.([ibnagweights], path[1:(end - 2)], path[2:(end - 1)]))
            for nodeinpathidx in reverse(eachindex(diststopathnodes))
                if opticalreach > diststopathnodes[nodeinpathidx]
                    # check also if available slots
                    spectrumslotsrange = getspectrumslotsrange(opticalinitiateconstraint)
                    # +1 because we start measuring from the second node
                    p = path[1:(nodeinpathidx + 1)]
                    if all(getpathspectrumavailabilities(ibnf, p)[spectrumslotsrange])
                        if p[end] ∉ globalnodecandidates
                            intrasplitglobalnode = calcintrasplitglobalnode(ibnf, getintent(idagnode), getglobalnode(ibnag, path[nodeinpathidx + 1])) 
                            if intrasplitglobalnode ∉ globalnodecandidates
                                push!(globalnodecandidates, intrasplitglobalnode)
                            end
                        end
                    end
                end
            end
        end
        # split on the same node is possible eitherway (port allocations and so are checked after)
        push!(globalnodecandidates, calcintrasplitglobalnode(ibnf, getintent(idagnode), getglobalnode(ibnag, sourcelocalnode)))
    else
        for path in yenstatepaths
            all(ed -> getcurrentlinkstate(ibnf, ed; checkfirst = true), edgeify(path)) || continue
            for sn in reverse(path)
                if sn == path[end] || sn == path[1] 
                    continue
                end
                intrasplitglobalnode = calcintrasplitglobalnode(ibnf, getintent(idagnode), getglobalnode(ibnag, sn)) 
                if intrasplitglobalnode ∉ globalnodecandidates
                    push!(globalnodecandidates, intrasplitglobalnode)
                end
            end
        end
    end
    return globalnodecandidates
end

"""
$(TYPEDSIGNATURES)
"""
function calcintrasplitglobalnode(ibnf::IBNFramework, intent::ConnectivityIntent, splitglobalnodeonly::GlobalNode)
    masteravcon = getfirst(x -> x isa AvailabilityConstraint, getconstraints(intent))
    intentcomp = getintcompalg(ibnf)

    if !isnothing(masteravcon)
        srcnode = getlocalnode(getibnag(ibnf), getsourcenode(intent))
        splitnode = getlocalnode(getibnag(ibnf), splitglobalnodeonly)
        dstnode = getlocalnode(getibnag(ibnf), getdestinationnode(intent))
        # calculate availability first half
        firsthalfavailability = estimateintraconnectionavailability(ibnf, srcnode, splitnode)
        # calculate availability second half
        secondhalfavailability = estimateintraconnectionavailability(ibnf, splitnode, dstnode)
        # make decision
        firsthalfavailabilityconstraint, secondhalfavailabilityconstraint = chooseintrasplitavailabilities(masteravcon, firsthalfavailability, secondhalfavailability, intentcomp)
        return SplitGlobalNode(splitglobalnodeonly, firsthalfavailabilityconstraint, secondhalfavailabilityconstraint)
    else
        return SplitGlobalNode(splitglobalnodeonly) 
    end
end

"""
$(TYPEDSIGNATURES)

AIntra domain compilation algorithm template.
Return function to do the intra domain compilation with the signature
```
intradomainalgfun(
    ibnf::IBNFramework, 
    idagnode::IntentDAGNode{<:ConnectivityIntent},
) -> Symbol
```

The returned algorithm can be customized as follows.

The major selection process is made on the source.

Interfaces needed:
```
getcandidatepathsnum(
    intentcompilationalgorithm::IntentCompilationAlgorithm)
 -> Int
```

Return the candidate paths with highest priority first as `Vector{Vector{Int}}}`.
Return empty collection if non available.
TODO docts protection: Protection paths... shouldnt end on border node !
```
prioritizepaths(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
) -> Vector{Vector{LocalNode}}
```

Return a Vector of grooming possibilities.
Return a `Vector` of grooming possibilities: `Vector{Vector{Union{UUID, Edge{Int}}}}`
Each element is a `Vector` of either an intent `UUID` or a new connectivity intent defined with `Edge`.
```
prioritizegrooming(
    ibnf::IBNFramework, 
    idagnode::IntentDAGNode{<:ConnectivityIntent}, 
```

Return the candidate router ports with highest priority first
Return empty collection if non available.
```
prioritizerouterport(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    node::LocalNode
) -> Vector{Int}
```

Return the transmission module index and the transmission mode index of that module as a `Vector{Tuple{Int, Int}}` with the first being the transmission module index and the second the transmission mode.
If this is calculated for the source node (default) pass `path::Vector{LocalNode}` and `transmdlcompat::Nothing`.
If this is calculated for the destination node pass `path::Nothing` and `transmdlcompat::TransmissionModuleCompatibility`
Return empty collection if non available.
```
prioritizetransmdlandmode(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    node::LocalNode,
    path::Union{Nothing, Vector{LocalNode}},
    transmdlcompat::Union{Nothing, TransmissionModuleCompatibility}=nothing
) -> Vector{Tuple{Int, Int}}
```

Return the first index of the spectrum slot range to be allocated.
If none found, return `nothing`
```
choosespectrum(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    path::Vector{LocalNode},
    demandslotsneeded::Int
) -> Vector{Int}
```

Return the index of the add/drop OXC port to allocate at node `node`
If none found, return `nothing`
```
chooseoxcadddropport(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    node::LocalNode
) -> Vector{Int}
```
"""
@recvtime function intradomaincompilationtemplate(;
        prioritizepaths = prioritizepaths_shortest,
        prioritizegrooming = prioritizegrooming_default,
        prioritizerouterport = prioritizerouterports_lowestrate,
        prioritizetransmdlandmode = prioritizetransmdlmode_cheaplowrate,
        choosespectrum = choosespectrum_firstfit,
        chooseoxcadddropport = chooseoxcadddropport_first,
    )

    return @recvtime function (ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, cachedintentresult::Dict{ConnectivityIntent, Symbol}; verbose::Bool = false)
        # needed variables
        ibnag = getibnag(ibnf)
        idag = getidag(ibnf)
        idagnodeid = getidagnodeid(idagnode)
        intent = getintent(idagnode)
        sourceglobalnode = getsourcenode(intent)
        sourcelocalnode = getlocalnode(ibnag, sourceglobalnode)
        sourcenodeview = getnodeview(ibnag, sourcelocalnode)
        destinationglobalnode = getdestinationnode(intent)
        destlocalnode = getlocalnode(ibnag, destinationglobalnode)
        destnodeview = getnodeview(ibnag, destlocalnode)
        demandrate = getrate(intent)
        constraints = getconstraints(intent)
        intentcomp = getintcompalg(ibnf)

        verbose && @info("Compiling intradomain intent ", getidagnodeid(idagnode), getintent(idagnode))
        returncode::Symbol = ReturnCodes.FAIL
        candidatepaths = prioritizepaths(ibnf, idagnode)
        verbose && @info("Calculated candidatepaths $(candidatepaths)")

        lowlevelintentstoadd = LowLevelIntent[]
        prsrcallocations = [MutableEndNodeAllocations()]
        setlocalnode!(prsrcallocations[1], sourcelocalnode)
        prdstallocations = [MutableEndNodeAllocations()]
        setlocalnode!(prdstallocations[], destlocalnode)
        prspectrumslotsrange = [0:0]
        prlpath = [Vector{LocalNode}()]
        usedgrooming = false

        ibnagweights = getibnagweights(getcachedresults(intentcomp))

        opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, constraints)
        if !isnothing(opticalinitiateconstraint) # cannot groom
            for protectedpaths in candidatepaths
                verbose && @info("Testing protected paths $(protectedpaths)")
                deleteat!(prsrcallocations, 2:length(prsrcallocations))
                deleteat!(prdstallocations, 2:length(prdstallocations))
                deleteat!(prspectrumslotsrange, 2:length(prspectrumslotsrange))
                deleteat!(prlpath, 2:length(prlpath))


                for pi in eachindex(protectedpaths)
                    returncode = ReturnCodes.FAIL_CANDIDATEPATHS # restart fail for new protected path
                    if pi > length(prsrcallocations)
                        push!(prsrcallocations, MutableEndNodeAllocations())
                        setlocalnode!(prsrcallocations[pi], sourcelocalnode)
                        setforopticalinitiate!(prsrcallocations[pi])
                    end
                    srcallocations = prsrcallocations[pi]

                    if pi > length(prdstallocations)
                        push!(prdstallocations, MutableEndNodeAllocations())
                        setlocalnode!(prdstallocations[pi], destlocalnode)
                    end
                    dstallocations = prdstallocations[pi]

                    if pi > length(prspectrumslotsrange)
                        push!(prspectrumslotsrange, 0:0)
                    end

                    path = protectedpaths[pi]
                    if pi > length(prlpath)
                        push!(prlpath, path)
                    else
                        prlpath[pi] = path
                    end


                    verbose && @info("Testing path $(path)")
                    # find transmission module and mode
                    prspectrumslotsrange[pi] = getspectrumslotsrange(opticalinitiateconstraint)
                    if length(path) > 1
                        if getopticalreach(opticalinitiateconstraint) < getpathdistance3(ibnagweights, path)
                            returncode = ReturnCodes.FAIL_OPTICALREACH_OPTINIT
                            break
                        end
                        pathspectrumavailability = getpathspectrumavailabilities(ibnf, path)
                        if !all(pathspectrumavailability[prspectrumslotsrange[pi]])
                            returncode = ReturnCodes.FAIL_SPECTRUM_OPTINIT
                            break
                        end
                    end

                    transmissionmodulecompat = gettransmissionmodulecompat(opticalinitiateconstraint)
                    verbose && @info("Solving for initial transmission module compatibility", transmissionmodulecompat)

                    sourceadddropport = nothing
                    setadddropport!(srcallocations, sourceadddropport)
                    opticalinitincomingnode = something(getlocalnode(ibnag, getglobalnode_input(opticalinitiateconstraint)))
                    if length(path) == 1
                        oxcview = getoxcview(getnodeview(ibnag, path[]))
                        hassameallocation = any(values(getreservations(oxcview))) do oxclli
                            getlocalnode_input(oxclli) == opticalinitincomingnode || return false
                            getlocalnode(oxclli) == path[] || return false
                            getspectrumslotsrange(oxclli) == prspectrumslotsrange[pi] || return false
                            return true
                        end
                        if hassameallocation
                            returncode = ReturnCodes.FAIL_SAMEOXCLLI
                            break
                        end
                    end
                    setlocalnode_input!(srcallocations, opticalinitincomingnode)

                    # double code with the second if
                    setadddropport!(dstallocations, nothing)
                    verbose && @info("Picked OXC LLIs with initial constraints", prspectrumslotsrange[pi])

                    # successful source-path configuration
                    opticalterminateconstraint = getfirst(x -> x isa OpticalTerminateConstraint, constraints)
                    if !isnothing(opticalterminateconstraint)
                        # no need to do something more. add intents and return true
                        returncode = ReturnCodes.SUCCESS
                    else
                        opticalincomingnode = length(path) == 1 ? opticalinitincomingnode : path[end - 1]
                        returncode = intradomaincompilationtemplate_destination!(ibnf, idagnode, transmissionmodulecompat, opticalincomingnode, prspectrumslotsrange[pi], prioritizerouterport, prioritizetransmdlandmode, chooseoxcadddropport, dstallocations; verbose, @passtime)
                    end
                    issuccess(returncode) || break # if one protection path at least is not successfuly go check the next group of protected paths
                end
                # overall success return
                issuccess(returncode) && break
            end
        else
            returncode = ReturnCodes.FAIL_CANDIDATEPATHS
            sourcerouteridxs = prioritizerouterport(ibnf, idagnode, sourcelocalnode)


            for protectedpaths in candidatepaths
                deleteat!(prsrcallocations, 2:length(prsrcallocations))
                deleteat!(prdstallocations, 2:length(prdstallocations))
                deleteat!(prspectrumslotsrange, 2:length(prspectrumslotsrange))
                deleteat!(prlpath, 2:length(prlpath))

                # try grooming
                if all(x -> !(x isa NoGroomingConstraint) && !(x isa OpticalInitiateConstraint), getconstraints(getintent(idagnode)))
                    usedgrooming = true
                    groomingpossibilities = prioritizegrooming(ibnf, idagnode, protectedpaths)

                    for groomingpossibility in groomingpossibilities
                        verbose && @info("Try grooming possibility $(groomingpossibility)")
                        # if protection indented only do grooming if it exactly matches the path ! ! !
                        verbose && @info("Selected grooming")
                        returncode = compilegroomingpossibility(ibnf, idagnode, groomingpossibility, var"#self#", cachedintentresult; verbose, @passtime)
                        issuccess(returncode) && break
                    end
                end

                # TODO what about protection here ? --> findout resulting spectrum of optical terminate if any and withhold that for next protection path
                issuccess(returncode) && break
                usedgrooming = false

                path1 = protectedpaths[1]
                protectedpathsspectrumavailabilities = [getpathspectrumavailabilities(ibnf, path) for path in protectedpaths]
                protectedpathsspectrumavailability = reduce(.&, protectedpathsspectrumavailabilities)
                protecteddemandslotsneeded = 0
                for pi in eachindex(protectedpaths)
                    returncode = ReturnCodes.FAIL_CANDIDATEPATHS # restart fail for new protected path
                    if pi > length(prsrcallocations)
                        push!(prsrcallocations, MutableEndNodeAllocations())
                        setlocalnode!(prsrcallocations[pi], sourcelocalnode)
                    end
                    srcallocations = prsrcallocations[pi]

                    if pi > length(prdstallocations)
                        push!(prdstallocations, MutableEndNodeAllocations())
                        setlocalnode!(prdstallocations[pi], destlocalnode)
                    end
                    dstallocations = prdstallocations[pi]

                    if pi > length(prspectrumslotsrange)
                        push!(prspectrumslotsrange, 0:0)
                    end

                    path = protectedpaths[pi]
                    if pi > length(prlpath)
                        push!(prlpath, path)
                    else
                        prlpath[pi] = path
                    end
                    verbose && @info("Testing path $(path)")

                    # find transmission module and mode
                    returncode = ReturnCodes.FAIL_SRCROUTERPORT
                    for sourcerouteridx in sourcerouteridxs
                        setrouterportindex!(prsrcallocations[pi], sourcerouteridx)
                        sourcerouterview = getrouterview(getnodeview(getibnag(ibnf), sourcelocalnode))
                        sourcerouterportrate = getrate(getrouterport(sourcerouterview, sourcerouteridx))
                        verbose && @info("Picking router port $(sourcerouteridx) at source node $(sourcelocalnode)")

                        sourcetransmissionmoduleviewpool = gettransmissionmoduleviewpool(sourcenodeview)
                        returncode = ReturnCodes.FAIL_SRCTRANSMDL
                        for (sourcetransmdlidx, sourcetransmissiomodeidx) in prioritizetransmdlandmode(ibnf, idagnode, sourcelocalnode, path, sourcerouterportrate)
                            sourcetransmissionmodule = sourcetransmissionmoduleviewpool[sourcetransmdlidx]
                            sourcetransmissionmode = gettransmissionmode(sourcetransmissionmodule, sourcetransmissiomodeidx)
                            ## define a TransmissionModuleCompatibility for the destination node
                            demandslotsneeded = getspectrumslotsneeded(sourcetransmissionmode)
                            transmissionmoderate = getrate(sourcetransmissionmode)
                            transmissionmodulename = getname(sourcetransmissionmodule)

                            transmissionmodulecompat = TransmissionModuleCompatibility(sourcerouterportrate, transmissionmoderate, demandslotsneeded, transmissionmodulename)

                            opticalterminateconstraint = getfirst(x -> x isa OpticalTerminateConstraint, constraints)
                            if !isnothing(opticalterminateconstraint)
                                protecteddemandslotsneeded = max(protecteddemandslotsneeded, demandslotsneeded)
                                startingslot = choosespectrum(ibnf, protectedpathsspectrumavailability, protecteddemandslotsneeded)
                            else
                                startingslot = choosespectrum(ibnf, protectedpathsspectrumavailabilities[pi], demandslotsneeded)
                            end
                            if isnothing(startingslot)
                                returncode = ReturnCodes.FAIL_SPECTRUM
                                continue
                            end

                            # are there oxc ports in the source ?
                            sourceadddropport = chooseoxcadddropport(ibnf, idagnode, sourcelocalnode)
                            if isnothing(sourceadddropport)
                                returncode = ReturnCodes.FAIL_SRCOXCADDDROPPORT
                                continue
                            end
                            setadddropport!(srcallocations, sourceadddropport)

                            sourcetransmissionmodulelli = TransmissionModuleLLI(sourcelocalnode, sourcetransmdlidx, sourcetransmissiomodeidx, sourcerouteridx, sourceadddropport)
                            settransmissionmoduleviewpoolindex!(srcallocations, sourcetransmdlidx)
                            settransmissionmodesindex!(srcallocations, sourcetransmissiomodeidx)
                            verbose && @info("Picking transmission module at source node", sourcetransmissionmodulelli)

                            opticalinitincomingnode = nothing
                            setlocalnode_input!(srcallocations, opticalinitincomingnode)
                            if !isnothing(opticalterminateconstraint)
                                # all optical terminates should have the same spectrum to give a single wavelength to the optical initiate
                                for pii in 1:pi
                                    prspectrumslotsrange[pii] = startingslot:(startingslot + demandslotsneeded - 1)
                                end
                            else
                                prspectrumslotsrange[pi] = startingslot:(startingslot + demandslotsneeded - 1)
                            end

                            # double code with the first if
                            verbose && @info("Picked OXC LLIs at", prspectrumslotsrange[pi])

                            # successful source-path configuration
                            if !isnothing(opticalterminateconstraint)
                                # no need to do something more. add intents and return true
                                returncode = ReturnCodes.SUCCESS
                            else
                                # need to allocate a router port, a transmission module and mode, and an OXC configuration
                                opticalincomingnode = path[end - 1]
                                returncode = intradomaincompilationtemplate_destination!(ibnf, idagnode, transmissionmodulecompat, opticalincomingnode, prspectrumslotsrange[pi], prioritizerouterport, prioritizetransmdlandmode, chooseoxcadddropport, dstallocations; verbose, @passtime)
                            end
                            issuccess(returncode) && break
                        end
                        issuccess(returncode) && break
                    end
                    issuccess(returncode) || break # if one protection path at least is not successfuly go check the next group of protected paths
                end
                issuccess(returncode) && break
            end

            # desperate grooming attempt
            # if !issuccess(returncode)
            #     # try out all grooming options as last chance
            #     usedgrooming = true
            #     if all(x -> !(x isa NoGroomingConstraint) && !(x isa OpticalInitiateConstraint), getconstraints(getintent(idagnode)))
            #         for groomingpossibilityidx in groomingpossibilitiesidxs
            #             verbose && @info("Try last resort grooming possibility $(groomingpossibilityidx)/$(length(groomingpossibilitiesidxs))")
            #             groomingpossibility = groomingpossibilities[groomingpossibilityidx]
            #             returncode = compilegroomingpossibility(ibnf, idagnode, groomingpossibility, var"#self#", cachedintentresult; verbose, @passtime)
            #             if issuccess(returncode)
            #                 break
            #             end
            #         end
            #     end
            # end
        end
        if issuccess(returncode) && !usedgrooming
            if length(prsrcallocations) == length(prdstallocations) == length(prspectrumslotsrange) == length(prlpath) == 1
                plpi = LightpathIntent(prsrcallocations[1], prdstallocations[1], prspectrumslotsrange[1], prlpath[1])
            else
                plpi = ProtectedLightpathIntent(prsrcallocations, prdstallocations, prspectrumslotsrange, prlpath)
            end
            plpidagnode = addidagnode!(ibnf, plpi; parentids = [idagnodeid], intentissuer = MachineGenerated(), @passtime)
            returncode = compileintent!(ibnf, plpidagnode; verbose, @passtime)
        end

        verbose && @info("$(getidagnodeid(idagnode)): About to return $(returncode)")
        return returncode
    end
end

"""
$(TYPEDSIGNATURES)

Returns ReturnCode on whether it managed to compile the grooming possibility passed.
"""
@recvtime function compilegroomingpossibility(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, groomingpossibility::Vector{Union{Edge{Int}, UUID}}, intradomainalgfun::F, cachedintentresult::Dict{ConnectivityIntent, Symbol}; verbose::Bool = false) where {F <: Function}
    verbose && @info("Investigating grooming possibility", groomingpossibility)
    returncode = ReturnCodes.FAIL
    lplength = length(groomingpossibility)
    for (lpidx, lightpath) in enumerate(groomingpossibility)
        # put NoGroomingConstraint in all Intents Generated here
        if lightpath isa Edge
            lpsourcenode = getglobalnode(getibnag(ibnf), src(lightpath))
            lpdstnode = getglobalnode(getibnag(ibnf), dst(lightpath))
            if lpidx == lplength
                opttermconstraint = getfirst(x -> x isa OpticalTerminateConstraint, getconstraints(getintent(idagnode)))
                if !isnothing(opttermconstraint)
                    lpintent = ConnectivityIntent(lpsourcenode, lpdstnode, getrate(getintent(idagnode)), [NoGroomingConstraint(), opttermconstraint])
                else
                    lpintent = ConnectivityIntent(lpsourcenode, lpdstnode, getrate(getintent(idagnode)), [NoGroomingConstraint()])
                end
            else
                lpintent = ConnectivityIntent(lpsourcenode, lpdstnode, getrate(getintent(idagnode)), [NoGroomingConstraint()])
            end
            lpidagnode = addidagnode!(ibnf, lpintent; parentids = [getidagnodeid(idagnode)], intentissuer = MachineGenerated(), @passtime)
            # var#self# is the non documented way to reference the self anonymous function
            returncode = haskey(cachedintentresult, lpintent) ? cachedintentresult[lpintent] : intradomainalgfun(ibnf, lpidagnode, cachedintentresult; verbose, @passtime)
            if !haskey(cachedintentresult, lpintent) 
                cachedintentresult[lpintent] = returncode
            end
            updateidagnodestates!(ibnf, lpidagnode; @passtime)
        elseif lightpath isa UUID
            addidagedge!(ibnf, getidagnodeid(idagnode), lightpath; @passtime)
            returncode = ReturnCodes.SUCCESS
        end
        if !issuccess(returncode)
            returncodetemp, _ = uncompileintent!(ibnf, getidagnodeid(idagnode); @passtime)
            @assert returncodetemp == ReturnCodes.SUCCESS
            break
        end
    end
    return returncode
end

"""
$(TYPEDSIGNATURES)
Takes care of the final node (destination).
Return the returncode of the procedure.
Also mutate `lowlevelintentstoadd` to add the low-level intents found.

The following functions must be passed in (entry point from [`intradomaincompilationtemplate`](@ref))

Return the candidate router ports with highest priority first
Return empty collection if non available.
```
prioritizerouterport(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    node::LocalNode
) -> Vector{Int}
```

Return the transmission module index and the transmission mode index of that module as a `Vector{Tuple{Int, Int}}` with the first being the transmission module index and the second the transmission mode.
If this is calculated for the source node (default) pass `path::Vector{LocalNode}` and `transmdlcompat::Nothing`.
If this is calculated for the destination node pass `path::Nothing` and `transmdlcompat::TransmissionModuleCompatibility`
Return empty collection if non available.
```
prioritizetransmdlandmode(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    node::LocalNode,
    path::Union{Nothing, Vector{LocalNode}},
    routerportrate::GBPSf,
    transmdlcompat::Union{Nothing, TransmissionModuleCompatibility}=nothing
) -> Vector{Tuple{Int, Int}}
```

Return the index of the add/drop OXC port to allocate at node `node`
If none found, return `nothing`
```
chooseoxcadddropport(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    node::LocalNode
) -> Vector{Int}
```
"""
@recvtime function intradomaincompilationtemplate_destination!(
        ibnf::IBNFramework,
        idagnode::IntentDAGNode{<:ConnectivityIntent},
        transmissionmodulecompat,
        opticalincomingnode::Int,
        spectrumslotsrange::UnitRange{Int},
        prioritizerouterport::F1,
        prioritizetransmdlmode::F2,
        chooseoxcadddropport::F3,
        mena::MutableEndNodeAllocations;
        verbose::Bool = false
    ) where {F1 <: Function, F2 <: Function, F3 <: Function}

    verbose && @info("Solving intent at the destination", getidagnodeid(idagnode))

    ibnag = getibnag(ibnf)
    idag = getidag(ibnf)
    idagnodeid = getidagnodeid(idagnode)
    intent = getintent(idagnode)
    destinationglobalnode = getdestinationnode(intent)
    destlocalnode = getlocalnode(destinationglobalnode)
    destnodeview = getnodeview(ibnag, destlocalnode)

    setlocalnode!(mena, destlocalnode)

    # need to allocate a router port and a transmission module and mode
    # template chooserouterport
    destrouteridxs = prioritizerouterport(ibnf, idagnode, destlocalnode, getrate(transmissionmodulecompat))
    !isempty(destrouteridxs) || return ReturnCodes.FAIL_DSTROUTERPORT
    destrouteridx = first(destrouteridxs)
    destrouterportlli = RouterPortLLI(destlocalnode, destrouteridx)
    setrouterportindex!(mena, destrouteridx)

    destavailtransmdlidxs = getavailabletransmissionmoduleviewindex(destnodeview)
    desttransmissionmoduleviewpool = gettransmissionmoduleviewpool(destnodeview)
    # put GBPSf(Inf) because transmissionmodulecompat is already here
    destavailtransmdlmodeidxs = prioritizetransmdlmode(ibnf, idagnode, destlocalnode, nothing, GBPSf(Inf), transmissionmodulecompat)
    !isempty(destavailtransmdlmodeidxs) || return ReturnCodes.FAIL_DSTTRANSMDL
    destavailtransmdlmodeidx = first(destavailtransmdlmodeidxs)
    destavailtransmdlidx, desttransmodeidx = destavailtransmdlmodeidx[1], destavailtransmdlmodeidx[2]

    # allocate OXC configuration
    # template chooseoxcadddropport
    destadddropport = chooseoxcadddropport(ibnf, idagnode, destlocalnode)
    !isnothing(destadddropport) || return ReturnCodes.FAIL_DSTOXCADDDROPPORT
    oxclli = OXCAddDropBypassSpectrumLLI(destlocalnode, opticalincomingnode, destadddropport, 0, spectrumslotsrange)
    setlocalnode_input!(mena, opticalincomingnode)
    setadddropport!(mena, destadddropport)
    # setlocalnode_output!(mena, 0)

    desttransmissionmodulelli = TransmissionModuleLLI(destlocalnode, destavailtransmdlidx, desttransmodeidx, destrouteridx, destadddropport)
    settransmissionmoduleviewpoolindex!(mena, destavailtransmdlidx)
    settransmissionmodesindex!(mena, desttransmodeidx)

    return ReturnCodes.SUCCESS
end

"""
$(TYPEDSIGNATURES)
"""
function prioritizepaths_shortest(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent})
    ibnag = getibnag(ibnf)
    sourcelocalnode = getlocalnode(ibnag, getsourcenode(getintent(idagnode)))
    destlocalnode = getlocalnode(ibnag, getdestinationnode(getintent(idagnode)))

    intentcomp = getintcompalg(ibnf)
    yenstatepaths = getyenpathsdict(getcachedresults(intentcomp))[Edge(sourcelocalnode, destlocalnode)]

    operatingpaths = filter(yenstatepaths) do path
        all(edgeify(path)) do ed
            getcurrentlinkstate(ibnf, ed; checkfirst = true)
        end
    end

    # TODO : perf unneeded allocations
    return [[opel] for opel in operatingpaths]
end

"Don't do grooming"
function prioritizegrooming_none(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent})
    groomingpossibilities = Vector{Vector{Union{UUID, Edge{Int}}}}()
    return groomingpossibilities
end


"""
$(TYPEDSIGNATURES)

Return a Dict{Edge{LocalNode}, Vector{GroomingPossibility}}
"""
function prioritizegrooming_default(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, protectedpaths::Vector{Vector{LocalNode}})
    groomingpossibilities = Vector{Vector{Union{UUID, Edge{Int}}}}()

    intent = getintent(idagnode)
    srcglobalnode = getsourcenode(intent)
    dstglobalnode = getdestinationnode(intent)
    srcnode = getlocalnode(getibnag(ibnf), srcglobalnode)
    dstnode = getlocalnode(getibnag(ibnf), dstglobalnode)

    if !(getibnfid(ibnf) == getibnfid(srcglobalnode) == getibnfid(dstglobalnode))
        if isbordernode(ibnf, srcglobalnode)
            any(x -> x isa OpticalInitiateConstraint, getconstraints(intent)) || return groomingpossibilities
        elseif isbordernode(ibnf, dstglobalnode)
            any(x -> x isa OpticalTerminateConstraint, getconstraints(intent)) || return groomingpossibilities
        else
            # cross domain intent
            # find lightpath combinations regardless of paths
            return groomingpossibilities
        end
    end

    installedlightpaths = collect(pairs(getinstalledlightpaths(getidaginfo(getidag(ibnf)))))

    # intentuuid => LightpathRepresentation

    containedlightpaths = Vector{Vector{Int}}()
    containedlpuuids = UUID[]
    installedlightpaths = collect(pairs(getinstalledlightpaths(getidaginfo(getidag(ibnf)))))
    if length(protectedpaths) <= 1
        candidatepath = protectedpaths[1]
        for (intentid, lightpathrepresentation) in installedlightpaths
            getstartsoptically(lightpathrepresentation) && continue
              # Protected paths will not be groomed
            if length(getpath(lightpathrepresentation)) <= 1 && getidagnodestate(getidag(ibnf), intentid) == IntentState.Installed
                # have to find exactly the candidatepath
                pathlightpathrepresentation = getpath(lightpathrepresentation)[1]
                if issubpath(candidatepath, pathlightpathrepresentation)
                    opttermconstraint = getfirst(c -> c isa OpticalTerminateConstraint, getconstraints(intent))
                    if !isnothing(opttermconstraint)
                        if getterminatessoptically(lightpathrepresentation) && getdestinationnode(lightpathrepresentation) == getdestinationnode(opttermconstraint)
                            if getresidualbandwidth(ibnf, intentid, lightpathrepresentation; onlyinstalled = false) >= getrate(intent)
                                push!(containedlightpaths, pathlightpathrepresentation)
                                push!(containedlpuuids, intentid)
                            end
                        end
                    else
                        if getresidualbandwidth(ibnf, intentid, lightpathrepresentation; onlyinstalled = false) >= getrate(intent)
                            push!(containedlightpaths, pathlightpathrepresentation)
                            push!(containedlpuuids, intentid)
                        end
                    end
                end
            end
        end
        # build up the possible OEO lightpaths
        # I want a combination of lightpaths in `containedlightpaths` such that exactly `candidatepath` is produced
        lightpathcollections = consecutivelightpathsidx(containedlightpaths, candidatepath)
        for lpcol in lightpathcollections
            push!(groomingpossibilities, Vector{Union{UUID, Edge{Int}}}( [containedlpuuids[lpcoli] for lpcoli in lpcol] ) )
        end
    else
        # need to find an installedlightpath with exactly this protection if any
        for (intentid, lightpathrepresentation) in installedlightpaths
            getstartsoptically(lightpathrepresentation) && continue
            if length(getpath(lightpathrepresentation)) == length(protectedpaths) # && getidagnodestate(getidag(ibnf), intentid) == IntentState.Installed
                # have to find exactly the candidatepath
                if all(pl -> pl[1] == pl[2], zip(protectedpaths, getpath(lightpathrepresentation)))
                    opttermconstraint = getfirst(c -> c isa OpticalTerminateConstraint, getconstraints(intent))
                    if !isnothing(opttermconstraint)
                        if getterminatessoptically(lightpathrepresentation) && getdestinationnode(lightpathrepresentation) == getdestinationnode(opttermconstraint)
                            if getresidualbandwidth(ibnf, intentid, lightpathrepresentation; onlyinstalled = false) >= getrate(intent)
                                push!(groomingpossibilities, Vector{Union{UUID, Edge{Int}}}( [intentid] ) )
                            end
                        end
                    else
                        if getresidualbandwidth(ibnf, intentid, lightpathrepresentation; onlyinstalled = false) >= getrate(intent)
                            push!(groomingpossibilities, Vector{Union{UUID, Edge{Int}}}( [intentid] ) )
                        end
                    end
                end
            end
        end
    end

    sort!(groomingpossibilities; by=length)

    return groomingpossibilities
end

"""
$(TYPEDSIGNATURES)

Same as `prioritizerouterports_lowestrate` but with a `sort!` in the end
"""
function prioritizerouterports_lowestrate(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, node::LocalNode, transmissionmoderate::GBPSf = GBPSf(-Inf))
    routerview = getrouterview(getnodeview(getibnag(ibnf), node))
    portrates = getrate.(getrouterports(routerview))
    reservedrouterports = getrouterportindex.(values(getreservations(routerview)))
    stagedrouterports = getrouterportindex.(getstaged(routerview))
    filteredports = filter(1:getportnumber(routerview)) do x
        x ∉ reservedrouterports && x ∉ stagedrouterports && portrates[x] >= getrate(getintent(idagnode)) && portrates[x] >= transmissionmoderate
    end
    sort!(filteredports; by = x -> portrates[x])
    return filteredports
end

"""
$(TYPEDSIGNATURES)
"""
function prioritizerouterports_default(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, node::LocalNode, transmissionmoderate::GBPSf = GBPSf(-Inf))
    routerview = getrouterview(getnodeview(getibnag(ibnf), node))
    portrates = getrate.(getrouterports(routerview))
    reservedrouterports = getrouterportindex.(values(getreservations(routerview)))
    stagedrouterports = getrouterportindex.(getstaged(routerview))
    filteredports = filter(1:getportnumber(routerview)) do x
        x ∉ reservedrouterports && x ∉ stagedrouterports && portrates[x] >= getrate(getintent(idagnode)) && portrates[x] >= transmissionmoderate
    end
    return filteredports
end

"""
$(TYPEDSIGNATURES)

Same as `prioritizetransmdlmode_default` with a `sortperm!`
Return the index with the lowest GBPS rate that can get deployed for the given demand rate and distance.
If non is find return `nothing`.
"""
function prioritizetransmdlmode_cheaplowrate(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, node::LocalNode, path::Union{Nothing, Vector{LocalNode}}, routerportrate::GBPSf, transmdlcompat::Union{Nothing, TransmissionModuleCompatibility} = nothing)
    nodeview = getnodeview(getibnag(ibnf), node)
    ibnagweights = getibnagweights(getcachedresults(getintcompalg(ibnf)))
    demandrate = getrate(getintent(idagnode))
    availtransmdlidxs = getavailabletransmissionmoduleviewindex(nodeview)
    transmissionmoduleviewpool = gettransmissionmoduleviewpool(nodeview)
    returnpriorities = Tuple{Int, Int}[]
    transmdlperm = sortperm(by = x -> getcost(x), transmissionmoduleviewpool)
    filter!(i -> i ∈ availtransmdlidxs, transmdlperm)
    transmodeidxs = zeros(Int, 10) # don't expect more than 10 modes
    for transmdlidx in transmdlperm
        transmissionmodule = transmissionmoduleviewpool[transmdlidx]
        transmodes = gettransmissionmodes(transmissionmodule)
        transmodeidxsview = view(transmodeidxs, 1:length(transmodes))
        sortperm!(transmodeidxsview, transmodes; by = getrate)
        for transmodeidx in transmodeidxsview
            transmode = transmodes[transmodeidx]
            if !isnothing(path) && isnothing(transmdlcompat)
                if getopticalreach(transmode) >= getpathdistance3(ibnagweights, path) && getrate(transmode) >= demandrate && getrate(transmode) <= routerportrate
                    push!(returnpriorities, (transmdlidx, transmodeidx))
                end
            elseif isnothing(path) && !isnothing(transmdlcompat)
                if istransmissionmoduleandmodecompatible(transmissionmodule, transmodeidx, transmdlcompat)
                    push!(returnpriorities, (transmdlidx, transmodeidx))
                end
            end
        end
    end
    return returnpriorities
end

"""
$(TYPEDSIGNATURES)
"""
function prioritizetransmdlmode_default(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, node::LocalNode, path::Union{Nothing, Vector{LocalNode}}, routerportrate::GBPSf, transmdlcompat::Union{Nothing, TransmissionModuleCompatibility} = nothing)
    nodeview = getnodeview(getibnag(ibnf), node)
    ibnagweights = getibnagweights(getcachedresults(getintcompalg(ibnf)))
    demandrate = getrate(getintent(idagnode))
    availtransmdlidxs = getavailabletransmissionmoduleviewindex(nodeview)
    transmissionmoduleviewpool = gettransmissionmoduleviewpool(nodeview)
    returnpriorities = Tuple{Int, Int}[]
    transmdlperm = eachindex(transmissionmoduleviewpool)
    filter!(i -> i ∈ availtransmdlidxs, transmdlperm)
    for transmdlidx in transmdlperm
        transmissionmodule = transmissionmoduleviewpool[transmdlidx]
        transmodes = gettransmissionmodes(transmissionmodule)
        transmodeidxs = sortperm(transmodes; by = getrate)
        for transmodeidx in transmodeidxs
            transmode = transmodes[transmodeidx]
            if !isnothing(path) && isnothing(transmdlcompat)
                if getopticalreach(transmode) >= getpathdistance3(ibnagweights, path) && getrate(transmode) >= demandrate && getrate(transmode) <= routerportrate
                    push!(returnpriorities, (transmdlidx, transmodeidx))
                end
            elseif isnothing(path) && !isnothing(transmdlcompat)
                if istransmissionmoduleandmodecompatible(transmissionmodule, transmodeidx, transmdlcompat)
                    push!(returnpriorities, (transmdlidx, transmodeidx))
                end
            end
        end
    end
    return returnpriorities
end

"""
$(TYPEDSIGNATURES)
"""
function choosespectrum_firstfit(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, path::Vector{LocalNode}, demandslotsneeded::Int)
    pathspectrumavailability = getpathspectrumavailabilities(ibnf, path)
    return firstfit(pathspectrumavailability, demandslotsneeded)
end

"""
$(TYPEDSIGNATURES)
"""
function choosespectrum_firstfit(ibnf::IBNFramework, pathspectrumavailability::AbstractVector{Bool}, demandslotsneeded::Int)
    return firstfit(pathspectrumavailability, demandslotsneeded)
end

function choosespectrum_firstfit(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, prpath::Vector{Vector{LocalNode}}, demandslotsneeded::Int)
    path1 = prpath[1]
    pathspectrumavailability = getpathspectrumavailabilities(ibnf, path1)
    for i in 2:length(prpath)
        pathspectrumavailability .&= getpathspectrumavailabilities(ibnf, prpath[i])
    end
    return firstfit(pathspectrumavailability, demandslotsneeded)
end

"""
$(TYPEDSIGNATURES)

Return the uniformly random available oxc add/drop port and `nothing` if none found
"""
function chooseoxcadddropport_first(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, node::LocalNode)
    oxcview = getoxcview(getnodeview(getibnag(ibnf), node))
    reservedoxcadddropports = getadddropport.(values(getreservations(oxcview)))
    stagedoxcadddropports = getadddropport.(values(getstaged(oxcview)))
    for adddropport in 1:getadddropportnumber(oxcview)
        if adddropport ∉ reservedoxcadddropports && adddropport ∉ stagedoxcadddropports
            return adddropport
        end
    end
    return nothing
end

function choosegroominornot(ibnf::IBNFramework{A,B,C,D,F}, protectedpaths::Vector{Vector{LocalNode}}, pi::Int, groomingpossibility::Vector{Union{UUID, Edge{Int}}}) where {A,B,C,D,F}
    ibnagweights = getibnagweights(getcachedresults(getintcompalg(ibnf)))
    path = protectedpaths[pi]
    nogroomingnewhops = sum(
        let
            length(getyenpathsdict(getcachedresults(getintcompalg(ibnf)))[Edge(src(e), dst(e))][1])
        end
        for e in Iterators.filter(x -> x isa Edge, groomingpossibility); init = 0.0)
    return nogroomingnewhops < length(path)
end

"""
$(TYPEDSIGNATURES)
"""
function estimateintraconnectionavailability(ibnf::IBNFramework, srcnode::LocalNode, dstnode::LocalNode)
    return nothing
end

"""
$(TYPEDSIGNATURES)
"""
function estimatecrossconnectionavailability(ibnf::IBNFramework, srcnode::GlobalNode, dstnode::GlobalNode)
    return nothing
end

"""
$(TYPEDSIGNATURES)
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

"""
$(TYPEDSIGNATURES)
"""
@recvtime function updatelogintentcomp!(ibnf::IBNFramework{A,B,C,D,E}) where {A,B,C,D,E}
    return nothing
end
