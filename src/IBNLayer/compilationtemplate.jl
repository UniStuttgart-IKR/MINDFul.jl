"""
$(TYPEDSIGNATURES)

A template compilation function that can be extended

Pass in the intent compilation algorithm `intentcompilationalgorithm`

Give in the following hook functions:
- `intradomainalgfun` is used as compilation algorithm for the intents handled internally. 
It should return a `Symbol` as a return code. 
Common return codes are found in `MINDFul.ReturnCodes`
```
intradomainalgfun(
    ibnf::IBNFramework, 
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    intentcompilationalgorithm::IntentCompilationAlgorithm
    ; datetime::DateTime
) -> Symbol
```

- `prioritizesplitnodes` is called when optical reach is not enough to have a lightpath end-to-end to serve the intent and a path to split was already selected.
The node selected will break the intent into two pieces with the node standing in between.
This function should return a vector of `GlobalNode`s with decreasing priority of which node should be chosen.
```
prioritizesplitnodes(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode,
    intentcompilationalgorithm::IntentCompilationAlgorithm,
) -> Vector{GlobalNode}
```

- `prioritizesplitbordernodes` is called to select the border node to work as the source node for the delegated intent in a neighboring domain.
This function should return a vector of `GlobalNode`s with decreasing priority of which node should be chosen.
```
prioritizesplitbordernodes(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    intentcompilationalgorithm::IntentCompilationAlgorithm)
) -> Vector{GlobalNode}
```
"""
@recvtime function compileintenttemplate!(
        ibnf::IBNFramework,
        idagnode::IntentDAGNode{<:ConnectivityIntent},
        intentcompilationalgorithm::IntentCompilationAlgorithm;
        verbose::Bool = false,
        intradomainalgfun::F1,
        externaldomainalgkeyword::Symbol,
        prioritizegrooming::F2 = prioritizegrooming_default,
        prioritizesplitnodes::F3 = prioritizesplitnodes_longestfirstshortestpath,
        prioritizesplitbordernodes::F4 = prioritizesplitbordernodes_shortestorshortestrandom
    ) where {F1 <: Function, F2 <: Function, F3 <: Function, F4 <: Function}
    sourceglobalnode = getsourcenode(getintent(idagnode))
    destinationglobalnode = getdestinationnode(getintent(idagnode))

    returncode::Symbol = ReturnCodes.FAIL
    verbose && @info("Compiling intent ", getidagnodeid(idagnode), getintent(idagnode))

    if !issuccess(returncode)
        # if didn't groom
        # if getibnfid(ibnf) == getibnfid(sourceglobalnode) == getibnfid(destinationglobalnode)
        if isinternalorborderintent(ibnf, getintent(idagnode); noremoteintent = true)
            # intra-domain
            returncode = intradomainalgfun(ibnf, idagnode, intentcompilationalgorithm; verbose, @passtime)
            # TODO  expect also an availability fail error here
            if returncode === ReturnCodes.FAIL_OPTICALREACH_OPTINIT || returncode === ReturnCodes.FAIL_SPECTRUM_OPTINIT || returncode === ReturnCodes.FAIL_OPTICALREACH
                verbose && @info("Compiling intent as whole failed with $(returncode). Attempting to split internal intent in two...")
                # get a node in between the shortest paths
                candidatesplitglobalnodes = prioritizesplitnodes(ibnf, idagnode, intentcompilationalgorithm)
                isempty(candidatesplitglobalnodes) && return ReturnCodes.FAIL_OPTICALREACH_OPTINIT_NONODESPLIT

                for splitglobalnode in candidatesplitglobalnodes
                    @assert uncompileintent!(ibnf, getidagnodeid(idagnode); @passtime) == ReturnCodes.SUCCESS
                    verbose && @info("Attenmpting splitting intent at GlobalNode", splitglobalnode)
                    returncode = splitandcompileintradomainconnecivityintent!(ibnf, idagnode, intentcompilationalgorithm, intradomainalgfun, splitglobalnode; verbose, @passtime)
                    issuccess(returncode) && break
                end
            end
            updateidagnodestates!(ibnf, idagnode; @passtime)
        elseif getibnfid(ibnf) == getibnfid(sourceglobalnode) && getibnfid(ibnf) !== getibnfid(destinationglobalnode)
            # source intra-domain , destination cross-domain
            # TODO availability split logic based on estimations
            # border-node
            if isbordernode(ibnf, destinationglobalnode)
                verbose && @info("Splitting at the border node")
                returncode = splitandcompilecrossdomainconnectivityintent(ibnf, idagnode, intentcompilationalgorithm, intradomainalgfun, externaldomainalgkeyword, destinationglobalnode; verbose, @passtime)
            else
                # select border node
                candidatedestinationglobalbordernodes = prioritizesplitbordernodes(ibnf, idagnode, intentcompilationalgorithm)
                isempty(candidatedestinationglobalbordernodes) && return ReturnCodes.FAIL_OPTICALREACH_OPTINIT_NONODESPLIT
                for destinationglobalbordernode in candidatedestinationglobalbordernodes
                    uncompileintent!(ibnf, getidagnodeid(idagnode); @passtime)
                    verbose && @info("Attempting to split cross intent at GlobalNode", destinationglobalbordernode)
                    returncode = splitandcompilecrossdomainconnectivityintent(ibnf, idagnode, intentcompilationalgorithm, intradomainalgfun, externaldomainalgkeyword, destinationglobalbordernode; verbose, @passtime)
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
@recvtime function splitandcompileintradomainconnecivityintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm, intradomainalgfun::F, splitglobalnode::GlobalNode; verbose::Bool = false) where {F <: Function}
    sourceglobalnode = getsourcenode(getintent(idagnode))
    destinationglobalnode = getdestinationnode(getintent(idagnode))
    intent = getintent(idagnode)
    idag = getidag(ibnf)

    # TODO : give some availability target 

    firsthalfintent = ConnectivityIntent(sourceglobalnode, splitglobalnode, getrate(intent), filter!(x ->!(x isa OpticalTerminateConstraint), getconstraints(intent)))
    firsthalfidagnode = addidagnode!(ibnf, firsthalfintent; parentids = [getidagnodeid(idagnode)], intentissuer = MachineGenerated(), @passtime)
    returncode = intradomainalgfun(ibnf, firsthalfidagnode, intentcompilationalgorithm; verbose, @passtime)
    updateidagnodestates!(ibnf, firsthalfidagnode; @passtime)
    issuccess(returncode) || return returncode

    # TODO : revise and calculate rest of availability

    secondhalfintent = ConnectivityIntent(splitglobalnode, destinationglobalnode, getrate(intent), filter(x -> !(x isa OpticalInitiateConstraint), getconstraints(intent)))
    secondhalfidagnode = addidagnode!(ibnf, secondhalfintent; parentids = [getidagnodeid(idagnode)], intentissuer = MachineGenerated(), @passtime)
    returncode = intradomainalgfun(ibnf, secondhalfidagnode, intentcompilationalgorithm; verbose, @passtime)
    updateidagnodestates!(ibnf, secondhalfidagnode; @passtime)
    return returncode
end


"""
$(TYPEDSIGNATURES)
"""
@recvtime function splitandcompilecrossdomainconnectivityintent(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm, intradomainalgfun::F, externaldomainalgkeyword::Symbol, mediatorbordernode::GlobalNode; verbose::Bool = false) where {F <: Function}
    idag = getidag(ibnf)
    intent = getintent(idagnode)
    returncode::Symbol = ReturnCodes.FAIL

    # TODO : give some availability target 

    internalintent = ConnectivityIntent(getsourcenode(intent), mediatorbordernode, getrate(intent), vcat(getconstraints(intent), OpticalTerminateConstraint(getdestinationnode(intent))))

    internalidagnode = addidagnode!(ibnf, internalintent; parentids = [getidagnodeid(idagnode)], intentissuer = MachineGenerated(), @passtime)
    returncode = intradomainalgfun(ibnf, internalidagnode, intentcompilationalgorithm; verbose, @passtime)
    updateidagnodestates!(ibnf, internalidagnode; @passtime)

    issuccess(returncode) || return returncode

    # if is groomed no need to continue
    any(x -> getintent(x) isa CrossLightpathIntent, getidagnodedescendants(idag, getidagnodeid(internalidagnode))) && return returncode

    # need first to compile that to get the optical choice
    # TODO : revise and calculate rest of availability
    opticalinitiateconstraint = getopticalinitiateconstraint(ibnf, getidagnodeid(internalidagnode))
    externalintent = ConnectivityIntent(mediatorbordernode, getdestinationnode(intent), getrate(intent), vcat(getconstraints(intent), opticalinitiateconstraint))
    externalidagnode = addidagnode!(ibnf, externalintent; parentids = [getidagnodeid(idagnode)], intentissuer = MachineGenerated(), @passtime)
    remoteibnfid = getibnfid(getdestinationnode(intent))
    internalremoteidagnode = remoteintent!(ibnf, externalidagnode, remoteibnfid; @passtime)

    # make a CrossLightpathIntent parent of last LightpathIntent and the Remote Intent
    # find the pair LightPathIntent for the RemoteIntent
    lpidagnode = getfirst(getidagnodedescendants(getidag(ibnf), getidagnodeid(internalidagnode))) do idagnode
        lightpathintent = getintent(idagnode)
        lightpathintent isa LightpathIntent || return false
        isonlyoptical(getdestinationnodeallocations(lightpathintent)) || return false
        lightpath = getpath(lightpathintent)
        length(lightpath) > 1 || return false
        getglobalnode(getibnag(ibnf), lightpath[end]) == mediatorbordernode || return false
        getglobalnode(getibnag(ibnf), lightpath[end - 1]) == getglobalnode_input(opticalinitiateconstraint) || return false
        getspectrumslotsrange(lightpathintent) == getspectrumslotsrange(opticalinitiateconstraint) || return false
        return true
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
        returncode = requestcompileintent_init!(ibnf, remoteibnfhandler, externalremoteidagnodeid, externaldomainalgkeyword, getdefaultcompilationalgorithmargs(Val(externaldomainalgkeyword)); verbose, @passtime)
    else
        returncode = getidagnodestate(internalremoteidagnode) in [IntentState.Installed, IntentState.Compiled] ? ReturnCodes.SUCCESS : ReturnCodes.FAIL_GROOMEDREMOTEINTENTSTATE
    end

    # check state of current internalremoteidagnode
    return returncode
end

"""
$(TYPEDSIGNATURES)
Return a single choice of [`GlobalNode`](@ref) and not several candidates.
If the target domain is known return the `GlobalNode` with the shortest distance.
If the target domain is unknown return the border node with the shortest distance, excluding the (if) source domain.
"""
function prioritizesplitbordernodes_shortestorshortestrandom(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm)
    ibnag = getibnag(ibnf)
    sourceglobalnode = getsourcenode(getintent(idagnode))
    sourcelocalnode = getlocalnode(ibnag, sourceglobalnode)
    destinationglobalnode = getdestinationnode(getintent(idagnode))
    borderlocals = getbordernodesaslocal(ibnf)
    # pick closest border node
    ibnagaweights = getweights(ibnag)
    foreach(edges(ibnag)) do ed
        if !getcurrentlinkstate(ibnf, ed; checkfirst = true)
            ibnagaweights[src(ed), dst(ed)] = typemax(eltype(ibnagaweights))
        end
    end
    hopdists = Graphs.dijkstra_shortest_paths(ibnag, sourcelocalnode, ibnagaweights).dists

    borderlocalsofdestdomain = filter(localnode -> getibnfid(getglobalnode(ibnag, localnode)) == getibnfid(destinationglobalnode), borderlocals)
    if !isempty(borderlocalsofdestdomain)
        # known domain
        sort!(borderlocalsofdestdomain; by = x -> hopdists[x])
        return [getglobalnode(ibnag, blodd) for blodd in borderlocalsofdestdomain]
    else
        # if unknown domain give it shortest distance border node
        borderlocalsofsrcdomain = filter(localnode -> getibnfid(getglobalnode(ibnag, localnode)) == getibnfid(sourceglobalnode), borderlocals)
        sort!(borderlocalsofsrcdomain; by = x -> hopdists[x])
        return [getglobalnode(ibnag, blosd) for blosd in borderlocalsofsrcdomain]
    end
end

"""
$(TYPEDSIGNATURES)

Return the [`GlobalNode`](@ref) contained in the shortest path that is the longest to reach given the optical reach situation.
The [`GlobalNode`](@ref) is used to break up the [`ConnectivityIntent`](@ref) into two.
"""
function prioritizesplitnodes_longestfirstshortestpath(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm)
    globalnodecandidates = GlobalNode[]
    ibnag = getibnag(ibnf)
    opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getintent(idagnode)))
    # I think that assert may not be needed and have to adjust for this case
    @assert !isnothing(opticalinitiateconstraint)
    opticalreach = getopticalreach(opticalinitiateconstraint)
    sourceglobalnode = getsourcenode(getintent(idagnode))
    sourcelocalnode = getlocalnode(ibnag, sourceglobalnode)
    destinationglobalnode = getdestinationnode(getintent(idagnode))
    destlocalnode = getlocalnode(ibnag, destinationglobalnode)
    yenstate = Graphs.yen_k_shortest_paths(ibnag, sourcelocalnode, destlocalnode, getweights(ibnag), getcandidatepathsnum(intentcompilationalgorithm))
    # customize per yenstate priority order
    for (dist, path) in zip(yenstate.dists, yenstate.paths)
        all(ed -> getcurrentlinkstate(ibnf, ed; checkfirst = true), edgeify(path)) || continue
        # the accumulated distance from 1st up to vorletzten node in path (vorletzten to brake intent)
        diststopathnodes = accumulate(+, getindex.([getweights(ibnag)], path[1:(end - 2)], path[2:(end - 1)]))
        for nodeinpathidx in reverse(eachindex(diststopathnodes))
            if opticalreach > diststopathnodes[nodeinpathidx]
                # check also if available slots
                spectrumslotsrange = getspectrumslotsrange(opticalinitiateconstraint)
                # +1 because we start measuring from the second node
                p = path[1:(nodeinpathidx + 1)]
                if all(getpathspectrumavailabilities(ibnf, p)[spectrumslotsrange])
                    if p[end] ∉ globalnodecandidates
                        push!(globalnodecandidates, getglobalnode(ibnag, path[nodeinpathidx + 1]))
                    end
                end
            end
        end

    end
    # split on the same node is possible eitherway (port allocations and so are checked after)
    push!(globalnodecandidates, getglobalnode(ibnag, sourcelocalnode))
    return globalnodecandidates
end

"""
$(TYPEDSIGNATURES)

AIntra domain compilation algorithm template.
Return function to do the intra domain compilation with the signature
```
intradomainalgfun(
    ibnf::IBNFramework, 
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    intentcompilationalgorithm::IntentCompilationAlgorithm
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
    intentcompilationalgorithm::IntentCompilationAlgorithm,
) -> Vector{Vector{LocalNode}}
```

Return a Vector of grooming possibilities.
Return a `Vector` of grooming possibilities: `Vector{Vector{Union{UUID, Edge{Int}}}}`
Each element is a `Vector` of either an intent `UUID` or a new connectivity intent defined with `Edge`.
```
prioritizegrooming(
    ibnf::IBNFramework, 
    idagnode::IntentDAGNode{<:ConnectivityIntent}, 
    intentcompilationalgorithm::IntentCompilationAlgorithm)
```

Return the candidate router ports with highest priority first
Return empty collection if non available.
```
prioritizerouterport(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    intentcompilationalgorithm::IntentCompilationAlgorithm,
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
    intentcompilationalgorithm::IntentCompilationAlgorithm,
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
    intentcompilationalgorithm::IntentCompilationAlgorithm,
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
    intentcompilationalgorithm::IntentCompilationAlgorithm,
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

    return @recvtime function (ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm; verbose::Bool = false)
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

        verbose && @info("Compiling intradomain intent ", getidagnodeid(idagnode), getintent(idagnode))
        returncode::Symbol = ReturnCodes.FAIL
        candidatepaths = prioritizepaths(ibnf, idagnode, intentcompilationalgorithm)

        lowlevelintentstoadd = LowLevelIntent[]
        prsrcallocations = [MutableEndNodeAllocations()]
        setlocalnode!(prsrcallocations[1], sourcelocalnode)
        prdstallocations = [MutableEndNodeAllocations()]
        setlocalnode!(prdstallocations[], destlocalnode)
        prspectrumslotsrange = [0:0]
        prlpath = [Vector{LocalNode}()]
        usedgrooming = false

        opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, constraints)
        if !isnothing(opticalinitiateconstraint) # cannot groom
            for protectedpaths in candidatepaths
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
                    if pi > length(prspectrumslotsrange)
                        push!(prlpath, path)
                    else
                        prlpath[pi] = path
                    end


                    verbose && @info("Testing path $(path)")
                    # find transmission module and mode
                    prspectrumslotsrange[pi] = getspectrumslotsrange(opticalinitiateconstraint)
                    if length(path) > 1
                        if getopticalreach(opticalinitiateconstraint) < getpathdistance(ibnag, path)
                            returncode = ReturnCodes.FAIL_OPTICALREACH_OPTINIT
                            continue
                        end
                        pathspectrumavailability = getpathspectrumavailabilities(ibnf, path)
                        if !all(pathspectrumavailability[prspectrumslotsrange[pi]])
                            returncode = ReturnCodes.FAIL_SPECTRUM_OPTINIT
                            continue
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
                            continue
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
                        returncode = intradomaincompilationtemplate_destination!(ibnf, idagnode, intentcompilationalgorithm, transmissionmodulecompat, opticalincomingnode, prspectrumslotsrange[pi], prioritizerouterport, prioritizetransmdlandmode, chooseoxcadddropport, dstallocations; verbose, @passtime)
                    end
                    issuccess(returncode) || break # if one protection path at least is not successfuly go check the next group of protected paths
                end
                # overall success return
                issuccess(returncode) && break
            end
        else
            returncode = ReturnCodes.FAIL_SRCROUTERPORT
            sourcerouteridxs = prioritizerouterport(ibnf, idagnode, intentcompilationalgorithm, sourcelocalnode)

            groomingpossibilities = prioritizegrooming(ibnf, idagnode, intentcompilationalgorithm; candidatepaths)
            groomingpossibilitiesidxs = collect(eachindex(groomingpossibilities))
            shortestpathdists = Graphs.johnson_shortest_paths(getibnag(ibnf)).dists

            for sourcerouteridx in sourcerouteridxs
                setrouterportindex!(prsrcallocations[1], sourcerouteridx)
                sourcerouterview = getrouterview(getnodeview(getibnag(ibnf), sourcelocalnode))
                sourcerouterportrate = getrate(getrouterport(sourcerouterview, sourcerouteridx))
                verbose && @info("Picking router port $(sourcerouteridx) at source node $(sourcelocalnode)")

                for protectedpaths in candidatepaths
                    deleteat!(prsrcallocations, 2:length(prsrcallocations))
                    deleteat!(prdstallocations, 2:length(prdstallocations))
                    deleteat!(prspectrumslotsrange, 2:length(prspectrumslotsrange))
                    deleteat!(prlpath, 2:length(prlpath))

                    for pi in eachindex(protectedpaths)
                        returncode = ReturnCodes.FAIL_CANDIDATEPATHS # restart fail for new protected path
                        if pi > length(prsrcallocations)
                            push!(prsrcallocations, MutableEndNodeAllocations())
                            setlocalnode!(prsrcallocations[pi], sourcelocalnode)
                            setrouterportindex!(prsrcallocations[pi], sourcerouteridx)
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

                        # try grooming
                        if all(x -> !(x isa NoGroomingConstraint) && !(x isa OpticalInitiateConstraint), getconstraints(getintent(idagnode)))
                            usedgrooming = true
                            for (groomingpossibilityidxidx, groomingpossibilityidx) in enumerate(groomingpossibilitiesidxs)
                                groomingpossibility = groomingpossibilities[groomingpossibilityidx]
                                # if protection indented only do grooming if it exactly matches the path ! ! !
                                if choosegroominornot(ibnf, protectedpaths, pi, shortestpathdists, groomingpossibility, intentcompilationalgorithm) # do grooming
                                    returncode = compilegroomingpossibility(ibnf, idagnode, groomingpossibility, intentcompilationalgorithm, var"#self#"; verbose, @passtime)
                                    if issuccess(returncode)
                                        deleteat!(groomingpossibilitiesidxs, groomingpossibilityidxidx)
                                        break
                                    end
                                end
                            end
                        end

                        # TODO what about protection here ? --> findout resulting spectrum of optical terminate if any and withhold that for next protection path
                        issuccess(returncode) && break
                        usedgrooming = false

                        # find transmission module and mode
                        sourcetransmissionmoduleviewpool = gettransmissionmoduleviewpool(sourcenodeview)
                        returncode = ReturnCodes.FAIL_SRCTRANSMDL
                        for (sourcetransmdlidx, sourcetransmissiomodeidx) in prioritizetransmdlandmode(ibnf, idagnode, intentcompilationalgorithm, sourcelocalnode, path, sourcerouterportrate)
                            sourcetransmissionmodule = sourcetransmissionmoduleviewpool[sourcetransmdlidx]
                            sourcetransmissionmode = gettransmissionmode(sourcetransmissionmodule, sourcetransmissiomodeidx)
                            ## define a TransmissionModuleCompatibility for the destination node
                            demandslotsneeded = getspectrumslotsneeded(sourcetransmissionmode)
                            transmissionmoderate = getrate(sourcetransmissionmode)
                            transmissionmodulename = getname(sourcetransmissionmodule)

                            transmissionmodulecompat = TransmissionModuleCompatibility(sourcerouterportrate, transmissionmoderate, demandslotsneeded, transmissionmodulename)

                            # TODO if opticalterminate spectrum must be found same for all protected paths
                            startingslot = choosespectrum(ibnf, idagnode, intentcompilationalgorithm, path, demandslotsneeded)
                            if isnothing(startingslot)
                                returncode = ReturnCodes.FAIL_SPECTRUM
                                continue
                            end

                            # are there oxc ports in the source ?
                            sourceadddropport = chooseoxcadddropport(ibnf, idagnode, intentcompilationalgorithm, sourcelocalnode)
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
                            prspectrumslotsrange[pi] = startingslot:(startingslot + demandslotsneeded - 1)

                            # double code with the first if
                            verbose && @info("Picked OXC LLIs at", prspectrumslotsrange[pi])

                            # successful source-path configuration
                            opticalterminateconstraint = getfirst(x -> x isa OpticalTerminateConstraint, constraints)
                            if !isnothing(opticalterminateconstraint)
                                # no need to do something more. add intents and return true
                                returncode = ReturnCodes.SUCCESS
                            else
                                # need to allocate a router port, a transmission module and mode, and an OXC configuration
                                opticalincomingnode = path[end - 1]
                                returncode = intradomaincompilationtemplate_destination!(ibnf, idagnode, intentcompilationalgorithm, transmissionmodulecompat, opticalincomingnode, prspectrumslotsrange[pi], prioritizerouterport, prioritizetransmdlandmode, chooseoxcadddropport, dstallocations; verbose, @passtime)
                            end
                            issuccess(returncode) && break
                        end
                        issuccess(returncode) || break # if one protection path at least is not successfuly go check the next group of protected paths

                    end
                    issuccess(returncode) && break
                end
                issuccess(returncode) && break
            end
            if !issuccess(returncode)
                # try out all grooming options as last chance
                usedgrooming = true
                if all(x -> !(x isa NoGroomingConstraint) && !(x isa OpticalInitiateConstraint), getconstraints(getintent(idagnode)))
                    for groomingpossibilityidx in groomingpossibilitiesidxs
                        groomingpossibility = groomingpossibilities[groomingpossibilityidx]
                        returncode = compilegroomingpossibility(ibnf, idagnode, groomingpossibility, intentcompilationalgorithm, var"#self#"; verbose, @passtime)
                        if issuccess(returncode)
                            break
                        end
                    end
                end
            end
        end
        if issuccess(returncode) && !usedgrooming
            if length(prsrcallocations) == length(prdstallocations) == length(prspectrumslotsrange) == length(prlpath) == 1
                plpi = LightpathIntent(prsrcallocations[1], prdstallocations[1], prspectrumslotsrange[1], prlpath[1])
            else
                plpi = ProtectedLightpathIntent(prsrcallocations, prdstallocations, prspectrumslotsrange, prlpath)
            end
            plpidagnode = addidagnode!(ibnf, plpi; parentids = [idagnodeid], intentissuer = MachineGenerated(), @passtime)
            returncode = compileintent!(ibnf, plpidagnode, intentcompilationalgorithm; verbose, @passtime)
        end

        return returncode
    end
end

"""
$(TYPEDSIGNATURES)

Returns ReturnCode on whether it managed to compile the grooming possibility passed.
"""
@recvtime function compilegroomingpossibility(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, groomingpossibility::Vector{Union{Edge{Int}, UUID}}, intentcompilationalgorithm::IntentCompilationAlgorithm, intradomainalgfun::F; verbose::Bool = false) where {F <: Function}
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
            returncode = intradomainalgfun(ibnf, lpidagnode, intentcompilationalgorithm; verbose, @passtime)
            updateidagnodestates!(ibnf, lpidagnode; @passtime)
        elseif lightpath isa UUID
            addidagedge!(ibnf, getidagnodeid(idagnode), lightpath; @passtime)
            returncode = ReturnCodes.SUCCESS
        end
        if !issuccess(returncode)
            @assert uncompileintent!(ibnf, getidagnodeid(idagnode); @passtime) == ReturnCodes.SUCCESS
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
    intentcompilationalgorithm::IntentCompilationAlgorithm,
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
    intentcompilationalgorithm::IntentCompilationAlgorithm,
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
    intentcompilationalgorithm::IntentCompilationAlgorithm,
    node::LocalNode
) -> Vector{Int}
```
"""
@recvtime function intradomaincompilationtemplate_destination!(
        ibnf::IBNFramework,
        idagnode::IntentDAGNode{<:ConnectivityIntent},
        intentcompilationalgorithm::IntentCompilationAlgorithm,
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
    destrouteridxs = prioritizerouterport(ibnf, idagnode, intentcompilationalgorithm, destlocalnode, getrate(transmissionmodulecompat))
    !isempty(destrouteridxs) || return ReturnCodes.FAIL_DSTROUTERPORT
    destrouteridx = first(destrouteridxs)
    destrouterportlli = RouterPortLLI(destlocalnode, destrouteridx)
    setrouterportindex!(mena, destrouteridx)

    destavailtransmdlidxs = getavailabletransmissionmoduleviewindex(destnodeview)
    desttransmissionmoduleviewpool = gettransmissionmoduleviewpool(destnodeview)
    # put GBPSf(Inf) because transmissionmodulecompat is already here
    destavailtransmdlmodeidxs = prioritizetransmdlmode(ibnf, idagnode, intentcompilationalgorithm, destlocalnode, nothing, GBPSf(Inf), transmissionmodulecompat)
    !isempty(destavailtransmdlmodeidxs) || return ReturnCodes.FAIL_DSTTRANSMDL
    destavailtransmdlmodeidx = first(destavailtransmdlmodeidxs)
    destavailtransmdlidx, desttransmodeidx = destavailtransmdlmodeidx[1], destavailtransmdlmodeidx[2]

    # allocate OXC configuration
    # template chooseoxcadddropport
    destadddropport = chooseoxcadddropport(ibnf, idagnode, intentcompilationalgorithm, destlocalnode)
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
function prioritizepaths_shortest(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm)
    ibnag = getibnag(ibnf)
    distweights = getweights(ibnag)
    sourcelocalnode = getlocalnode(ibnag, getsourcenode(getintent(idagnode)))
    destlocalnode = getlocalnode(ibnag, getdestinationnode(getintent(idagnode)))

    if sourcelocalnode == destlocalnode
        yenstate = Graphs.YenState([u"0.0km"], [[destlocalnode]])
    else
        yenstate = Graphs.yen_k_shortest_paths(ibnag, sourcelocalnode, destlocalnode, distweights, getcandidatepathsnum(intentcompilationalgorithm))
    end

    operatingpaths = filter(yenstate.paths) do path
        all(edgeify(path)) do ed
            getcurrentlinkstate(ibnf, ed; checkfirst = true)
        end
    end

    return [[opel] for opel in operatingpaths]
end

"Don't do grooming"
function prioritizegrooming_none(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm)
    groomingpossibilities = Vector{Vector{Union{UUID, Edge{Int}}}}()
    return groomingpossibilities
end

"""
$(TYPEDSIGNATURES)
    Return a Vector of grooming possibilities.
    Suggest grooming only if remains on the same path.
    Suggest grooming only if one extra router port pair is used.

    Return a `Vector` of grooming possibilities: `Vector{Vector{Union{UUID, Edge{Int}}}}`
    Each element is a `Vector` of either an intent `UUID` or a new connectivity intent defined with `Edge`.

    Sorting of the grooming possibilities is done just by minimizing lightpaths used
"""
function prioritizegrooming_default(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm; candidatepaths::Vector{Vector{Vector{LocalNode}}} = Vector{Vector{Vector{LocalNode}}}())
    intent = getintent(idagnode)
    srcglobalnode = getsourcenode(intent)
    dstglobalnode = getdestinationnode(intent)
    srcnode = getlocalnode(getibnag(ibnf), srcglobalnode)
    dstnode = getlocalnode(getibnag(ibnf), dstglobalnode)

    groomingpossibilities = Vector{Vector{Union{UUID, Edge{Int}}}}()

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

    # these are already fail-free
    candidatepaths = prioritizepaths_shortest(ibnf, idagnode, intentcompilationalgorithm)

    # intentuuid => LightpathRepresentation
    installedlightpaths = collect(pairs(getinstalledlightpaths(getidaginfo(getidag(ibnf)))))
    filter!(installedlightpaths) do (lightpathuuid, lightpathrepresentation)
        getresidualbandwidth(ibnf, lightpathuuid, lightpathrepresentation; onlyinstalled = false) >= getrate(intent) &&
            getidagnodestate(getidag(ibnf), lightpathuuid) == IntentState.Installed
    end

    for candidatepath in Iterators.flatten(candidatepaths)
        containedlightpaths = Vector{Vector{Int}}()
        containedlpuuids = UUID[]
        for (intentid, lightpathrepresentation) in installedlightpaths
            ff = findfirst( path -> issubpath(candidatepath, path), getpath(lightpathrepresentation))
            if !isnothing(ff)
                pathlightpathrepresentation = getpath(lightpathrepresentation)[ff]
                opttermconstraint = getfirst(c -> c isa OpticalTerminateConstraint, getconstraints(intent))
                if pathlightpathrepresentation[end] == dstnode && !isnothing(opttermconstraint)
                    if getterminatessoptically(lightpathrepresentation) && getdestinationnode(lightpathrepresentation) == getdestinationnode(opttermconstraint)
                        push!(containedlightpaths, pathlightpathrepresentation)
                        push!(containedlpuuids, intentid)
                    end
                else
                    push!(containedlightpaths, pathlightpathrepresentation)
                    push!(containedlpuuids, intentid)
                end
            end
        end

        ## starting lightpaths
        startinglightpathscollections = consecutivelightpathsidx(containedlightpaths, srcnode; startingnode = true)

        ## ending lightpaths
        endinglightpathscollections = consecutivelightpathsidx(containedlightpaths, dstnode; startingnode = false)

        for lightpathcollection in Iterators.flatten((startinglightpathscollections, endinglightpathscollections))
            lpc2insert = Vector{Union{UUID, Edge{Int}}}()
            for lpidx in lightpathcollection
                push!(lpc2insert, containedlpuuids[lpidx])
            end

            firstlightpath = containedlightpaths[lightpathcollection[1]]
            if firstlightpath[1] != srcnode
                pushfirst!(lpc2insert, Edge(srcnode, firstlightpath[1]))
            end
            lastlightpath = containedlightpaths[lightpathcollection[end]]
            if lastlightpath[end] != dstnode
                push!(lpc2insert, Edge(lastlightpath[end], dstnode))
            end

            # is it low-priority or high-priority ?
            # TODO: prioritize shortest paths as well
            index = searchsortedfirst(groomingpossibilities, lpc2insert; by = length)

            if index > length(groomingpossibilities) || groomingpossibilities[index] != lpc2insert #if not already inside
                insert!(groomingpossibilities, index, lpc2insert)
            end
        end

    end

    return groomingpossibilities
end

"""
$(TYPEDSIGNATURES)
"""
function prioritizerouterports_lowestrate(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm, node::LocalNode, transmissionmoderate::GBPSf = GBPSf(-Inf))
    routerview = getrouterview(getnodeview(getibnag(ibnf), node))
    portrates = getrate.(getrouterports(routerview))
    reservedrouterports = getrouterportindex.(values(getreservations(routerview)))
    stagedrouterports = getrouterportindex.(getstaged(routerview))
    filteredports = filter(1:getportnumber(routerview)) do x
        x ∉ reservedrouterports && x ∉ stagedrouterports && portrates[x] > getrate(getintent(idagnode)) && portrates[x] > transmissionmoderate
    end
    sort!(filteredports; by = x -> portrates[x])
    return filteredports
end

"""
$(TYPEDSIGNATURES)

Return the index with the lowest GBPS rate that can get deployed for the given demand rate and distance.
If non is find return `nothing`.
"""
function prioritizetransmdlmode_cheaplowrate(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm, node::LocalNode, path::Union{Nothing, Vector{LocalNode}}, routerportrate::GBPSf, transmdlcompat::Union{Nothing, TransmissionModuleCompatibility} = nothing)
    nodeview = getnodeview(getibnag(ibnf), node)
    demandrate = getrate(getintent(idagnode))
    availtransmdlidxs = getavailabletransmissionmoduleviewindex(nodeview)
    transmissionmoduleviewpool = gettransmissionmoduleviewpool(nodeview)
    returnpriorities = Tuple{Int, Int}[]
    transmdlperm = sortperm(by = x -> getcost(x), transmissionmoduleviewpool)
    filter!(i -> i ∈ availtransmdlidxs, transmdlperm)
    for transmdlidx in transmdlperm
        transmissionmodule = transmissionmoduleviewpool[transmdlidx]
        transmodes = gettransmissionmodes(transmissionmodule)
        transmodeidxs = sortperm(transmodes; by = getrate)
        for transmodeidx in transmodeidxs
            transmode = transmodes[transmodeidx]
            if !isnothing(path) && isnothing(transmdlcompat)
                if getopticalreach(transmode) >= getpathdistance(getibnag(ibnf), path) && getrate(transmode) >= demandrate && getrate(transmode) <= routerportrate
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
function choosespectrum_firstfit(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm, path::Vector{LocalNode}, demandslotsneeded::Int)
    # TODO : NOW, considered staged constraints
    pathspectrumavailability = getpathspectrumavailabilities(ibnf, path)
    return firstfit(pathspectrumavailability, demandslotsneeded)
end

"""
$(TYPEDSIGNATURES)

Return the uniformly random available oxc add/drop port and `nothing` if none found
"""
function chooseoxcadddropport_first(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm, node::LocalNode)
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

function choosegroominornot(ibnf::IBNFramework, protectedpaths::Vector{Vector{LocalNode}}, pi::Int, shortestpathdists::Matrix, groomingpossibility::Vector{Union{UUID, Edge{Int}}}, intentcompilationalg::IntentCompilationAlgorithm)
    path = protectedpaths[pi]
    nogroomingnewhops = sum(shortestpathdists[src(e), dst(e)] for e in Iterators.filter(x -> x isa Edge, groomingpossibility); init = 0.0)
    return nogroomingnewhops < length(path)
end
