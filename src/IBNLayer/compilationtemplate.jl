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
    ) where{F1<:Function, F2<:Function, F3<:Function, F4<:Function}
    sourceglobalnode = getsourcenode(getintent(idagnode))
    destinationglobalnode = getdestinationnode(getintent(idagnode))

    returncode::Symbol = ReturnCodes.FAIL
    verbose && @info("Compiling intent ", getidagnodeid(idagnode), getintent(idagnode))

    # get grooming possibilites and handle them
    # grooming not possible for OpticalInitiateConstraint
    if all(x -> !(x isa NoGroomingConstraint) && !(x isa OpticalInitiateConstraint), getconstraints(getintent(idagnode)))
        groomingpossibilities = prioritizegrooming(ibnf, idagnode, intentcompilationalgorithm)
        for groomingpossibility in groomingpossibilities
            for lightpath in groomingpossibility
                # put NoGroomingConstraint in all Intents Generated here 
                if lightpath isa Edge 
                    lpsourcenode = GlobalNode(getibnfid(ibnf), src(lightpath))
                    lpdstnode = GlobalNode(getibnfid(ibnf), dst(lightpath))
                    lpintent = ConnectivityIntent(lpsourcenode, lpdstnode, getrate(getintent(idagnode)), [NoGroomingConstraint()])
                    lpidagnode = addidagnode!(ibnf, lpintent; parentid = getidagnodeid(idagnode), intentissuer = MachineGenerated(), @passtime)
                    returncode = intradomainalgfun(ibnf, lpidagnode, intentcompilationalgorithm; verbose)
                    updateidagnodestates!(ibnf, lpidagnode; @passtime)
                elseif lightpath isa UUID
                    addidagedge!(ibnf, getidagnodeid(idagnode), lightpath)
                    returncode = ReturnCodes.SUCCESS
                end
                if !issuccess(returncode)
                    # TODO uncompile and restart to go to next grooming possibility
                    break
                end
            end
            if issuccess(returncode)
                break
            end
        end
    end
    if !issuccess(returncode)
        # if didn't groom
        if getibnfid(ibnf) == getibnfid(sourceglobalnode) == getibnfid(destinationglobalnode)
            # intra-domain
            returncode = intradomainalgfun(ibnf, idagnode, intentcompilationalgorithm; verbose, @passtime)
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
            updateidagnodestates!(ibnf, idagnode)
        elseif getibnfid(ibnf) == getibnfid(sourceglobalnode) && getibnfid(ibnf) !== getibnfid(destinationglobalnode)
            # source intra-domain , destination cross-domain
            # border-node
            if isbordernode(ibnf, destinationglobalnode)
                verbose && @info("Splitting at the border node")
                returncode = splitandcompilecrossdomainconnectivityintent(ibnf, idagnode, intentcompilationalgorithm, intradomainalgfun, externaldomainalgkeyword, destinationglobalnode; @passtime)
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

Splits connectivity intent on `splitglobalnode`
"""
@recvtime function splitandcompileintradomainconnecivityintent!(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm,intradomainalgfun::F, splitglobalnode::GlobalNode; verbose::Bool = false) where {F<:Function}
    sourceglobalnode = getsourcenode(getintent(idagnode))
    destinationglobalnode = getdestinationnode(getintent(idagnode))
    intent = getintent(idagnode)
    idag = getidag(ibnf)
    firsthalfintent = ConnectivityIntent(sourceglobalnode, splitglobalnode, getrate(intent), getconstraints(intent))
    firsthalfidagnode = addidagnode!(ibnf, firsthalfintent; parentid = getidagnodeid(idagnode), intentissuer = MachineGenerated(), @passtime)
    returncode = intradomainalgfun(ibnf, firsthalfidagnode, intentcompilationalgorithm; verbose)
    updateidagnodestates!(ibnf, firsthalfidagnode; @passtime)
    issuccess(returncode) || return returncode

    secondhalfintent = ConnectivityIntent(splitglobalnode, destinationglobalnode, getrate(intent), filter(x -> !(x isa OpticalInitiateConstraint), getconstraints(intent)))
    secondhalfidagnode = addidagnode!(ibnf, secondhalfintent; parentid = getidagnodeid(idagnode), intentissuer = MachineGenerated(), @passtime)
    returncode = intradomainalgfun(ibnf, secondhalfidagnode, intentcompilationalgorithm; verbose)
    updateidagnodestates!(ibnf, secondhalfidagnode; @passtime)
    return returncode
end


"""
$(TYPEDSIGNATURES)
"""
@recvtime function splitandcompilecrossdomainconnectivityintent(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm, intradomainalgfun::F, externaldomainalgkeyword::Symbol, mediatorbordernode::GlobalNode; verbose::Bool = false) where {F<:Function}
    idag = getidag(ibnf)
    intent = getintent(idagnode)
    returncode::Symbol = ReturnCodes.FAIL

    internalintent = ConnectivityIntent(getsourcenode(intent), mediatorbordernode, getrate(intent), vcat(getconstraints(intent), OpticalTerminateConstraint()))

    internalidagnode = addidagnode!(ibnf, internalintent; parentid = getidagnodeid(idagnode), intentissuer = MachineGenerated(), @passtime)
    returncode = intradomainalgfun(ibnf, internalidagnode, intentcompilationalgorithm; verbose, @passtime)
    updateidagnodestates!(ibnf, internalidagnode; @passtime)

    issuccess(returncode) || return returncode
   
    # need first to compile that to get the optical choice
    opticalinitiateconstraint = getopticalinitiateconstraint(ibnf, getidagnodeid(internalidagnode))
    externalintent = ConnectivityIntent(mediatorbordernode, getdestinationnode(intent), getrate(intent), vcat(getconstraints(intent), opticalinitiateconstraint))
    externalidagnode = addidagnode!(ibnf, externalintent; parentid = getidagnodeid(idagnode), intentissuer = MachineGenerated(), @passtime)
    remoteibnfid = getibnfid(getdestinationnode(intent))
    internalremoteidagnode = remoteintent!(ibnf, externalidagnode, remoteibnfid; @passtime)
    # getintent brings in the internal RemoteIntent
    externalremoteidagnodeid = getidagnodeid(getintent(internalremoteidagnode))

    # compile internalremoteidagnode
    remoteibnfhandler = getibnfhandler(ibnf, remoteibnfid)
    # compilationaglorithmkeyword = getcompilationalgorithmkeyword(intentcompilationalgorithm)
    returncode = requestcompileintent_init!(ibnf, remoteibnfhandler, externalremoteidagnodeid, externaldomainalgkeyword, getdefaultcompilationalgorithmargs(Val(externaldomainalgkeyword)); verbose, @passtime)

    # check state of current internalremoteidagnode
    return returncode
end

"""
$(TYPEDSIGNATURES)
    Return a Vector of grooming possibilities.
    Suggest grooming only if remains on the same path.
    Suggest grooming only if one extra router port pair is used.

    Return a `Vector` of grooming possibilities: `Vector{Vector{Union{UUID, Edge{Int}}}}`
    Each element is a `Vector` of either an intent `UUID` or a new connectivity intent defined with `Edge`.
"""
function prioritizegrooming_default(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm)
    intent = getintent(idagnode)
    srcglobalnode = getsourcenode(intent)
    dstglobalnode = getdestinationnode(intent)
    srcnode = getlocalnode(getibnag(ibnf), srcglobalnode)
    dstnode = getlocalnode(getibnag(ibnf), dstglobalnode)

    groomingpossibilities = Vector{Vector{Union{UUID, Edge{Int}}}}()

    getibnfid(ibnf) == getibnfid(srcglobalnode) == getibnfid(dstglobalnode) || return groomingpossibilities

    candidatepaths = prioritizepaths_shortest(ibnf, idagnode, intentcompilationalgorithm)

    # intentuuid => LightpathRepresentation
    installedlightpaths = collect(pairs(getinstalledlightpaths(getidaginfo(getidag(ibnf)))))
    for candidatepath in candidatepaths
        containedinstalledlightpaths = filter(installedlightpaths) do (intentid, lightpathrepresentation)
            issubpath(candidatepath, getpath(lightpathrepresentation)) || return false
            if getpath(lightpathrepresentation)[end] == dstnode && any(c -> c isa OpticalTerminateConstraint, getconstraints(getintent(idagnode)))
                if getterminatessoptically(lightpathrepresentation)
                    return true
                else
                    return false
                end
            end
            return true
        end

        containedlightpaths = getpath.(getindex.(containedinstalledlightpaths, 2)) 
        # find the combination of lightaths.

        ## starting lightpaths
        startinglightpathscollections = consecutivelightpathsidx(containedlightpaths, srcnode; startingnode=true)
       
        ## ending lightpaths
        endinglightpathscollections = consecutivelightpathsidx(containedlightpaths, dstnode; startingnode=false)

        for lightpathcollection in Iterators.flatten((startinglightpathscollections, endinglightpathscollections))
            # some filtering: e.g. no same lightpath combinations 

            lpc2insert = Vector{Union{UUID, Edge{Int}}}()
            for lpidx in lightpathcollection
                push!(lpc2insert, containedinstalledlightpaths[lpidx][1])
            end

            firstlightpath = containedlightpaths[lightpathcollection[1]]
            if firstlightpath[1] != srcnode
                pushfirst!(lpc2insert, Edge(srcnode, firstlightpath[1]))
            end
            lastlightpath = containedlightpaths[lightpathcollection[end]]
            if lastlightpath[end] != dstnode
                push!(lpc2insert, Edge(lastlightpath[end], dstnode))
            end

            index = searchsortedfirst(groomingpossibilities, lpc2insert) 
            # TODO sort grooming options ; by = fewerlightpathsinvolved)
            if index > length(groomingpossibilities) || groomingpossibilities[index] != lpc2insert #if not already inside
                insert!(groomingpossibilities, index, lpc2insert)
            end
        end

    end

    return groomingpossibilities
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
    borderlocals = getbordernodesaslocal(ibnf);
    # pick closest border node
    ibnagaweights = getweights(ibnag)
    foreach(edges(ibnag)) do ed
        if !getcurrentlinkstate(ibnf, ed; checkfirst=true)
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
Not several candidates are returned but only a single choice.
"""
function prioritizesplitnodes_longestfirstshortestpath(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm)
    globalnodecandidates = GlobalNode[]
    ibnag = getibnag(ibnf)
    opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(getintent(idagnode)))
    @assert !isnothing(opticalinitiateconstraint)
    opticalreach = getopticalreach(opticalinitiateconstraint)
    sourceglobalnode = getsourcenode(getintent(idagnode))
    sourcelocalnode = getlocalnode(ibnag, sourceglobalnode)
    destinationglobalnode = getdestinationnode(getintent(idagnode))
    destlocalnode = getlocalnode(ibnag, destinationglobalnode)
    yenstate = Graphs.yen_k_shortest_paths(ibnag, sourcelocalnode, destlocalnode, getweights(ibnag), getcandidatepathsnum(intentcompilationalgorithm))
    # customize per yenstate priority order
    for (dist, path) in zip(yenstate.dists, yenstate.paths)
        all(ed -> getcurrentlinkstate(ibnf, ed; checkfirst=true), edgeify(path)) || continue
        # the accumulated distance from 1st up to vorletzten node in path (vorletzten to brake intent)
        diststopathnodes = accumulate(+, getindex.([getweights(ibnag)], path[1:end-2], path[2:end-1]))
        for nodeinpathidx in reverse(eachindex(diststopathnodes))
            if opticalreach > diststopathnodes[nodeinpathidx]
                # check also if available slots
                spectrumslotsrange = getspectrumslotsrange(opticalinitiateconstraint)
                # +1 because we start measuring from the second node
                p = path[1:nodeinpathidx+1]
                if all(getpathspectrumavailabilities(ibnf, p)[spectrumslotsrange])
                    if p[end] ∉ globalnodecandidates
                        push!(globalnodecandidates, getglobalnode(ibnag, path[nodeinpathidx+1]))
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
```
prioritizepaths(
    ibnf::IBNFramework,
    idagnode::IntentDAGNode{<:ConnectivityIntent},
    intentcompilationalgorithm::IntentCompilationAlgorithm,
) -> Vector{Vector{LocalNode}}
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
    prioritizerouterport = prioritizerouterports_lowestrate,
    prioritizetransmdlandmode = prioritizetransmdlmode_cheaplowrate,
    choosespectrum = choosespectrum_firstfit,
    chooseoxcadddropport = chooseoxcadddropport_first,
    )

    return @recvtime function(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm; verbose::Bool = false)
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
        srcallocations = MutableEndNodeAllocations()
        setlocalnode!(srcallocations, sourcelocalnode)
        dstallocations = MutableEndNodeAllocations()
        setlocalnode!(dstallocations, destlocalnode)
        spectrumslotsrange = 0:0
        lpath = Vector{LocalNode}()

        opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, constraints)
        if !isnothing(opticalinitiateconstraint) # cannot groom
            setrouterportindex!(srcallocations, nothing)
            settransmissionmoduleviewpoolindex!(srcallocations, nothing)
            settransmissionmodesindex!(srcallocations, nothing)
            returncode = ReturnCodes.FAIL_CANDIDATEPATHS
            for path in candidatepaths
                lpath = path
                lowlevelintentsbuffer = LowLevelIntent[]
                verbose && @info("Testing path $(path)")
                # find transmission module and mode
                spectrumslotsrange = getspectrumslotsrange(opticalinitiateconstraint)
                if length(path) > 1
                    if getopticalreach(opticalinitiateconstraint) < getpathdistance(ibnag, path)
                        returncode = ReturnCodes.FAIL_OPTICALREACH_OPTINIT
                        continue
                    end
                    pathspectrumavailability = getpathspectrumavailabilities(ibnf, path)
                    if !all(pathspectrumavailability[spectrumslotsrange])
                        returncode = ReturnCodes.FAIL_SPECTRUM_OPTINIT
                        continue
                    end
                end

                transmissionmodulecompat = gettransmissionmodulecompat(opticalinitiateconstraint)
                verbose && @info("Solving for initial transmission module compatibility", transmissionmodulecompat)

                sourceadddropport = nothing
                setadddropport!(srcallocations, sourceadddropport)
                opticalinitincomingnode = something(getlocalnode(ibnag, getglobalnode_input(opticalinitiateconstraint)))
                setlocalnode_input!(srcallocations, opticalinitincomingnode)

                # double code with the second if
                setadddropport!(dstallocations, nothing)
                oxcadddropbypassspectrumllis = generatelightpathoxcadddropbypassspectrumlli(path, spectrumslotsrange; sourceadddropport, opticalinitincomingnode, destadddropport = nothing)
                foreach(oxcadddropbypassspectrumllis) do lli
                    push!(lowlevelintentsbuffer, lli)
                end
                verbose && @info("Picked OXC LLIs with initial constraints", spectrumslotsrange)
            
                # successful source-path configuration
                opticalterminateconstraint = getfirst(x -> x isa OpticalTerminateConstraint, constraints)
                if !isnothing(opticalterminateconstraint)
                    # no need to do something more. add intents and return true
                    returncode = ReturnCodes.SUCCESS
                else
                    opticalincomingnode = length(path) == 1 ? opticalinitincomingnode : path[end-1]
                    returncode = intradomaincompilationtemplate_destination!(ibnf, idagnode, intentcompilationalgorithm,lowlevelintentsbuffer, transmissionmodulecompat, opticalincomingnode, spectrumslotsrange, prioritizerouterport, prioritizetransmdlandmode, chooseoxcadddropport, dstallocations; verbose, @passtime)
                end
                if issuccess(returncode) 
                    push!(lowlevelintentstoadd, lowlevelintentsbuffer...)
                    break
                end
            end
        else
            returncode = ReturnCodes.FAIL_SRCROUTERPORT
            sourcerouteridxs = prioritizerouterport(ibnf, idagnode, intentcompilationalgorithm, sourcelocalnode)
            for sourcerouteridx in sourcerouteridxs
                setrouterportindex!(srcallocations, sourcerouteridx)
                lowlevelintentsbuffer1 = LowLevelIntent[]
                verbose && @info("Picking router port $(sourcerouteridx) at source node $(sourcelocalnode)")
                sourcerouterportlli = RouterPortLLI(sourcelocalnode, sourcerouteridx)
                push!(lowlevelintentsbuffer1, sourcerouterportlli)

                returncode = ReturnCodes.FAIL_CANDIDATEPATHS
                for path in candidatepaths
                    lpath = path
                    lowlevelintentsbuffer2 = LowLevelIntent[]
                    verbose && @info("Testing path $(path)")
                    # find transmission module and mode
                    sourcetransmissionmoduleviewpool = gettransmissionmoduleviewpool(sourcenodeview)
                    returncode = ReturnCodes.FAIL_SRCTRANSMDL
                    for (sourcetransmdlidx, sourcetransmissiomodeidx) in prioritizetransmdlandmode(ibnf, idagnode, intentcompilationalgorithm, sourcelocalnode, path)
                        lowlevelintentsbuffer3 = LowLevelIntent[]
                        sourcetransmissionmodule = sourcetransmissionmoduleviewpool[sourcetransmdlidx]
                        sourcetransmissionmode = gettransmissionmode(sourcetransmissionmodule, sourcetransmissiomodeidx)
                        ## define a TransmissionModuleCompatibility for the destination node
                        demandslotsneeded = getspectrumslotsneeded(sourcetransmissionmode)
                        transmissionmoderate = getrate(sourcetransmissionmode)
                        transmissionmodulename = getname(sourcetransmissionmodule)

                        transmissionmodulecompat = TransmissionModuleCompatibility(transmissionmoderate, demandslotsneeded, transmissionmodulename)

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

                        push!(lowlevelintentsbuffer3, sourcetransmissionmodulelli)

                        opticalinitincomingnode = nothing
                        setlocalnode_input!(srcallocations, opticalinitincomingnode)
                        spectrumslotsrange = startingslot:(startingslot + demandslotsneeded - 1)

                        # double code with the first if
                        oxcadddropbypassspectrumllis = generatelightpathoxcadddropbypassspectrumlli(path, spectrumslotsrange; sourceadddropport, opticalinitincomingnode, destadddropport = nothing)

                        foreach(oxcadddropbypassspectrumllis) do lli
                            push!(lowlevelintentsbuffer3, lli)
                        end
                        verbose && @info("Picked OXC LLIs at", spectrumslotsrange)
    
                        # successful source-path configuration
                        opticalterminateconstraint = getfirst(x -> x isa OpticalTerminateConstraint, constraints)
                        if !isnothing(opticalterminateconstraint)
                            # no need to do something more. add intents and return true
                            returncode = ReturnCodes.SUCCESS
                        else
                            # need to allocate a router port, a transmission module and mode, and an OXC configuration
                            opticalincomingnode = path[end-1]
                            returncode = intradomaincompilationtemplate_destination!(ibnf, idagnode, intentcompilationalgorithm, lowlevelintentsbuffer3, transmissionmodulecompat, opticalincomingnode, spectrumslotsrange, prioritizerouterport, prioritizetransmdlandmode, chooseoxcadddropport, dstallocations; verbose, @passtime)
                        end
                        if issuccess(returncode)
                            push!(lowlevelintentsbuffer2, lowlevelintentsbuffer3...)
                            break
                        end
                    end
                    if issuccess(returncode)
                        push!(lowlevelintentsbuffer1, lowlevelintentsbuffer2...)
                        break
                    end
                end
                if issuccess(returncode)
                    push!(lowlevelintentstoadd, lowlevelintentsbuffer1...)
                    break
                end
            end
        end
        lpi = LightpathIntent(srcallocations, dstallocations, spectrumslotsrange, lpath)
        lpidagnode = addidagnode!(ibnf, lpi; parentid=idagnodeid, intentissuer=MachineGenerated(), @passtime)
        return compileintent!(ibnf, lpidagnode, intentcompilationalgorithm; verbose)
        ## add intent and it's LLI
        # foreach(lowlevelintentstoadd) do lli
        #     stageaddidagnode!(ibnf, lli; parentid = idagnodeid, intentissuer = MachineGenerated(), @passtime)
        # end
        # return returncode
    end
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
    lowlevelintentstoadd,
    transmissionmodulecompat,
    opticalincomingnode::Int,
    spectrumslotsrange::UnitRange{Int},
    prioritizerouterport::F1,
    prioritizetransmdlmode::F2,
    chooseoxcadddropport::F3,
    mena::MutableEndNodeAllocations;
    verbose::Bool = false) where {F1<:Function, F2<:Function, F3<:Function}

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
    destrouteridxs = prioritizerouterport(ibnf, idagnode, intentcompilationalgorithm, destlocalnode)
    !isempty(destrouteridxs) || return ReturnCodes.FAIL_DSTROUTERPORT
    destrouteridx = first(destrouteridxs)
    destrouterportlli = RouterPortLLI(destlocalnode, destrouteridx)
    push!(lowlevelintentstoadd, destrouterportlli)
    setrouterportindex!(mena, destrouteridx)

    destavailtransmdlidxs = getavailabletransmissionmoduleviewindex(destnodeview)
    desttransmissionmoduleviewpool = gettransmissionmoduleviewpool(destnodeview)
    destavailtransmdlmodeidxs = prioritizetransmdlmode(ibnf, idagnode, intentcompilationalgorithm, destlocalnode, nothing, transmissionmodulecompat)
    !isempty(destavailtransmdlmodeidxs) || return ReturnCodes.FAIL_DSTTRANSMDL
    destavailtransmdlmodeidx = first(destavailtransmdlmodeidxs)
    destavailtransmdlidx, desttransmodeidx = destavailtransmdlmodeidx[1], destavailtransmdlmodeidx[2] 

    # allocate OXC configuration
    # template chooseoxcadddropport
    destadddropport = chooseoxcadddropport(ibnf, idagnode, intentcompilationalgorithm, destlocalnode)
    !isnothing(destadddropport) || return ReturnCodes.FAIL_DSTOXCADDDROPPORT
    oxclli = OXCAddDropBypassSpectrumLLI(destlocalnode, opticalincomingnode, destadddropport, 0, spectrumslotsrange)
    push!(lowlevelintentstoadd, oxclli)
    setlocalnode_input!(mena, opticalincomingnode)
    setadddropport!(mena, destadddropport)
    # setlocalnode_output!(mena, 0)

    desttransmissionmodulelli = TransmissionModuleLLI(destlocalnode, destavailtransmdlidx, desttransmodeidx, destrouteridx, destadddropport)
    push!(lowlevelintentstoadd, desttransmissionmodulelli)
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
            getcurrentlinkstate(ibnf, ed; checkfirst=true)
        end
    end

    return operatingpaths
end

"""
$(TYPEDSIGNATURES)
"""
function prioritizerouterports_lowestrate(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm, node::LocalNode)
    routerview = getrouterview(getnodeview(getibnag(ibnf), node))
    portrates = getrate.(getrouterports(routerview))
    reservedrouterports = getrouterportindex.(values(getreservations(routerview)))
    stagedrouterports = getrouterportindex.(getstaged(routerview))
    filteredports = filter(1:getportnumber(routerview)) do x
        x ∉ reservedrouterports && x ∉ stagedrouterports && portrates[x] > getrate(getintent(idagnode))
    end
    sort!(filteredports; by = x -> portrates[x])
    return filteredports
end

"""
$(TYPEDSIGNATURES)

Return the index with the lowest GBPS rate that can get deployed for the given demand rate and distance.
If non is find return `nothing`.
"""
function prioritizetransmdlmode_cheaplowrate(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, intentcompilationalgorithm::IntentCompilationAlgorithm, node::LocalNode, path::Union{Nothing, Vector{LocalNode}}, transmdlcompat::Union{Nothing, TransmissionModuleCompatibility}=nothing)
    nodeview = getnodeview(getibnag(ibnf), node)
    demandrate = getrate(getintent(idagnode))
    availtransmdlidxs = getavailabletransmissionmoduleviewindex(nodeview)
    transmissionmoduleviewpool = gettransmissionmoduleviewpool(nodeview)
    returnpriorities = Tuple{Int,Int}[]
    transmdlperm = sortperm(by = x -> getcost(x) , transmissionmoduleviewpool)
    filter!(i -> i ∈ availtransmdlidxs, transmdlperm)
    for transmdlidx in transmdlperm
        transmissionmodule = transmissionmoduleviewpool[transmdlidx]
        transmodes = gettransmissionmodes(transmissionmodule)
        transmodeidxs = sortperm(transmodes; by = getrate)
        for transmodeidx in transmodeidxs
            transmode = transmodes[transmodeidx]
            if !isnothing(path) && isnothing(transmdlcompat)
                if getopticalreach(transmode) >= getpathdistance(getibnag(ibnf), path) && getrate(transmode) >= demandrate
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

