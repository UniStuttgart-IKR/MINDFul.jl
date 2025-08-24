function issatisfied(ibnf::IBNFramework, intentid::UUID, orderedllis::Vector{<:LowLevelIntent}; noextrallis = true, verbose::Bool = false)
    return issatisfied(ibnf, getidagnode(getidag(ibnf), intentid), orderedllis; noextrallis, verbose)
end
function issatisfied(ibnf::IBNFramework, intentid::UUID; onlyinstalled = true, noextrallis = true, verbose::Bool = false, choosealternativeorder::Int = 0)
    return issatisfied(ibnf, getidagnode(getidag(ibnf), intentid); onlyinstalled, noextrallis, verbose, choosealternativeorder)
end
function getlogicallliorder(ibnf::IBNFramework, intentuuid::UUID; onlyinstalled = true, verbose::Bool = false, choosealternativeorder::Int = 0)
    return getlogicallliorder(ibnf, getidagnode(getidag(ibnf), intentuuid); onlyinstalled, verbose, choosealternativeorder)
end

"""
$(TYPEDSIGNATURES)

Steps by step check if `ibnf` satisfies the intent
For now works only with local view.
The options are:
- onlyinstalled: only consideres installed intents
- noextrallis: all LLI must be used
- orderedllis: pass list to access ordered llis
- choosealternativeorder::Int. `0` to error in case multiple logical orders are available and the index of the alternative otherwise.

The function is not a definite assertion.
The following cases are not covered:
- transmission module compatibility
- optical reach
"""
function issatisfied(ibnf::IBNFramework, idagnode::IntentDAGNode{<:Union{CrossLightpathIntent, ConnectivityIntent}}; onlyinstalled = true, noextrallis = true, verbose::Bool = false, choosealternativeorder::Int = 0)
    idagnodechildren = getidagnodechildren(getidag(ibnf), idagnode)
    if length(idagnodechildren) == 1 && getintent(idagnodechildren[1]) isa RemoteIntent
        return issatisfied(ibnf, idagnodechildren[1]; onlyinstalled, noextrallis, verbose, choosealternativeorder)
    else
        orderedllis = getlogicallliorder(ibnf, idagnode; onlyinstalled, verbose, choosealternativeorder)
        return issatisfied(ibnf, idagnode, orderedllis; noextrallis, verbose)
    end
end

function issatisfied(ibnf::IBNFramework, idagnode::IntentDAGNode{<:RemoteIntent}; onlyinstalled = true, noextrallis = true, verbose::Bool = false, choosealternativeorder::Int = 0)
    remoteintent = getintent(idagnode)
    if getisinitiator(remoteintent)
        ibnfhandler = getibnfhandler(ibnf, getibnfid(remoteintent))
        requestissatisfied_init(ibnf, ibnfhandler, getidagnodeid(remoteintent); onlyinstalled, noextrallis, choosealternativeorder)
    else
        idagnodechildren = getidagnodechildren(getidag(ibnf), idagnode)
        length(idagnodechildren) == 1 || return false
        return issatisfied(ibnf, idagnodechildren[1]; onlyinstalled, noextrallis, verbose, choosealternativeorder)
    end
end

function issatisfied(ibnf::IBNFramework, idagnode::IntentDAGNode{<:Union{CrossLightpathIntent, ConnectivityIntent}}, orderedllis::Vector{<:LowLevelIntent}; noextrallis = true, verbose::Bool = false)
    idag = getidag(ibnf)
    ibnag = getibnag(ibnf)
    if getintent(idagnode) isa ConnectivityIntent
        conintent = getintent(idagnode)
    elseif getintent(idagnode) isa CrossLightpathIntent
        conintent = getlightpathconnectivityintent(getintent(idagnode))
    end
    sourcelocalnode = getlocalnode(ibnag, getsourcenode(conintent))
    destlocalnode = getlocalnode(ibnag, getdestinationnode(conintent))
    constraints = getconstraints(conintent)

    istotalsatisfied = true

    @returnfalseiffalse(verbose, !isempty(orderedllis))


    # check first
    firstlli = orderedllis[1]
    opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, constraints)
    if !isnothing(opticalinitiateconstraint)
        if !(
                firstlli isa OXCAddDropBypassSpectrumLLI && getlocalnode(firstlli) == sourcelocalnode &&
                    getlocalnode_input(firstlli) == something(getlocalnode(getibnag(ibnf), getglobalnode_input(opticalinitiateconstraint)))
            )
            istotalsatisfied = false
        end
    else
        if !(firstlli isa RouterPortLLI) || getlocalnode(firstlli) != sourcelocalnode
            istotalsatisfied = false
        end
    end

    # check last
    lastlli = orderedllis[end]
    opticalterminateconstraint = getfirst(x -> x isa OpticalTerminateConstraint, constraints)
    if !isnothing(opticalterminateconstraint)
        if !(lastlli isa OXCAddDropBypassSpectrumLLI) || getlocalnode_output(lastlli) != destlocalnode
            @returnfalseiffalse(verbose, false)
        end
    else
        if lastlli isa OXCAddDropBypassSpectrumLLI
            # search for child connectivity intent that starts from lastlli and finishes at destination node
            globalllinode = getglobalnode(ibnag, getlocalnode(lastlli))
            globalllinode_output = getglobalnode(ibnag, getlocalnode_output(lastlli))

            idagnodeconnectivityintent = getfirst(getidagnodedescendants(idag, getidagnodeid(idagnode); includeroot = true)) do idagnodedesc
                @returnfalseiffalse(verbose, getintent(idagnodedesc) isa ConnectivityIntent || getintent(idagnodedesc) isa CrossLightpathIntent)
                conintent = getintent(idagnodedesc) isa ConnectivityIntent ? getintent(idagnodedesc) : getremoteconnectivityintent(getintent(idagnodedesc))
                @returnfalseiffalse(verbose, globalllinode_output == getsourcenode(conintent))
                @returnfalseiffalse(verbose, getdestinationnode(conintent) == getdestinationnode(getintent(idagnode)))
                # there needs to be an OpticalInitiate
                initconstraint = getfirst(x -> x isa OpticalInitiateConstraint, getconstraints(conintent))
                @returnfalseiffalse(verbose, !isnothing(initconstraint))
                @returnfalseiffalse(verbose, getspectrumslotsrange(lastlli) == getspectrumslotsrange(initconstraint))
                @returnfalseiffalse(verbose, globalllinode == getglobalnode_input(initconstraint))
                return true
            end

            @returnfalseiffalse(verbose, !isnothing(idagnodeconnectivityintent))
            allowuninstalled = any(getidagnodellis(idag, getidagnodeid(idagnode))) do idagnodelli
                if getintent(idagnodelli) ∈ orderedllis
                    return getidagnodestate(idagnodelli) != IntentState.Installed
                end
            end
            if getintent(idagnodeconnectivityintent) isa CrossLightpathIntent
                remoteidagnode = getfirst(x -> getintent(x) isa RemoteIntent, getidagnodechildren(idag, getidagnodeid(idagnodeconnectivityintent)))
                @returnfalseiffalse(verbose, !isnothing(remoteidagnode))
                istotalsatisfied &= issatisfied(ibnf, getidagnodeid(remoteidagnode); onlyinstalled = !allowuninstalled, noextrallis, verbose)
            else
                istotalsatisfied &= issatisfied(ibnf, getidagnodeid(idagnodeconnectivityintent); onlyinstalled = !allowuninstalled, noextrallis, verbose)
            end
        elseif !(lastlli isa RouterPortLLI) || getlocalnode(lastlli) != destlocalnode
            @returnfalseiffalse(verbose, false)
        end
    end

    # TODO
    # - optical reach
    # - groomed intents do not surpass the resources capacity

    if noextrallis
        istotalsatisfied &= (length(getidagnodellis(idag, getidagnodeid(idagnode))) == length(orderedllis))
        @returniffalse(verbose, istotalsatisfied)
    end

    return istotalsatisfied
end

function getlogicallliorder(ibnf::IBNFramework, idagnode::IntentDAGNode{<:RemoteIntent}; onlyinstalled = true, verbose::Bool = false, choosealternativeorder::Int = 0)
    idagnodechildren = getidagnodechildren(getidag(ibnf), idagnode)
    length(idagnodechildren) == 1 || return false
    return getlogicallliorder(ibnf, idagnodechildren[1]; onlyinstalled, verbose, choosealternativeorder)
end

function getlogicallliorder(ibnf::IBNFramework, idagnode::IntentDAGNode{<:Union{CrossLightpathIntent, ConnectivityIntent}}; onlyinstalled = true, verbose::Bool = false, choosealternativeorder::Int = 0)
    idag = getidag(ibnf)
    ibnag = getibnag(ibnf)

    # get all LLIs
    idagnodellis = getidagnodellis(idag, getidagnodeid(idagnode))
    llis = getintent.(idagnodellis)
    # orderedllis = empty(llis)
    orderedllis = LowLevelIntent[]
    isempty(idagnodellis) && return orderedllis

    if onlyinstalled
        filter!(x -> getidagnodestate(x) == IntentState.Installed, idagnodellis)
    end
    llis = getintent.(idagnodellis)


    if getintent(idagnode) isa ConnectivityIntent
        conintent = getintent(idagnode)
    elseif getintent(idagnode) isa CrossLightpathIntent
        conintent = getlightpathconnectivityintent(getintent(idagnode))
    end

    sourcelocalnode = getlocalnode(ibnag, getsourcenode(conintent))
    destlocalnode = getlocalnode(ibnag, getdestinationnode(conintent))
    constraints = getconstraints(conintent)

    # find the first LLI
    opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, constraints)
    if !isnothing(opticalinitiateconstraint)
        lliidx1 = findfirst(llis) do lli
            lli isa OXCAddDropBypassSpectrumLLI && getlocalnode(lli) == sourcelocalnode &&
                getlocalnode_input(lli) == something(getlocalnode(getibnag(ibnf), getglobalnode_input(opticalinitiateconstraint)))
        end
    else
        lliidx1 = findfirst(llis) do lli
            lli isa RouterPortLLI && getlocalnode(lli) == sourcelocalnode && getrouterportrate(ibnf, lli) >= getrate(conintent)
        end
    end

    lliidx_start = !isnothing(lliidx1) ? lliidx1 : let
            lliidx1_cands = findall(llis) do lli
                singlenextchoice = length(getafterlliidx(ibnf, conintent, llis, lli)) == 1
                singlenextchoice && return false
                nodestnode = getlocalnode(lli) !== destlocalnode
                return nodestnode
        end
            if length(lliidx1_cands) == 1
                lliidx1_cands[1]
        elseif length(lliidx1_cands) == 2
                # there are only two points. Will pick the one that gives a longer series.
                series1 = _getlogicallliorder_coreloop(ibnf, deepcopy(llis), conintent, lliidx1_cands[1])
                series2 = _getlogicallliorder_coreloop(ibnf, deepcopy(llis), conintent, lliidx1_cands[2])
                length(series1) > length(series2) ? lliidx1_cands[1] : lliidx1_cands[2]
        else
                nothing
        end
    end

    isnothing(lliidx_start) && return orderedllis

    return _getlogicallliorder_coreloop(ibnf, llis, conintent, lliidx_start; verbose, choosealternativeorder)
end

function _getlogicallliorder_coreloop(ibnf, llis, conintent::ConnectivityIntent, startingindex::Int, orderedllis = LowLevelIntent[]; verbose::Bool = false, choosealternativeorder::Int = 0)
    push!(orderedllis, popat!(llis, startingindex))
    # continue to the second and so on...
    validcontinuity = true
    while !isempty(llis) && validcontinuity
        let lastlli = orderedllis[end]
            if lastlli isa RouterPortLLI
                nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                if length(nextlliidx) != 1
                    if iszero(choosealternativeorder)  || choosealternativeorder > length(nextlliidx) 
                        validcontinuity = false
                    else
                        push!(orderedllis, popat!(llis, nextlliidx[choosealternativeorder]))
                    end
                else
                    push!(orderedllis, popat!(llis, first(nextlliidx)))
                end
            elseif lastlli isa TransmissionModuleLLI
                nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                if length(nextlliidx) != 1
                    if iszero(choosealternativeorder)  || choosealternativeorder > length(nextlliidx) 
                        validcontinuity = false
                    else
                        push!(orderedllis, popat!(llis, nextlliidx[choosealternativeorder]))
                    end
                else
                    push!(orderedllis, popat!(llis, first(nextlliidx)))
                end
            elseif lastlli isa OXCAddDropBypassSpectrumLLI
                nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                if length(nextlliidx) != 1
                    if iszero(choosealternativeorder)  || choosealternativeorder > length(nextlliidx) 
                        validcontinuity = false
                    else
                        push!(orderedllis, popat!(llis, nextlliidx[choosealternativeorder]))
                    end
                else
                    push!(orderedllis, popat!(llis, first(nextlliidx)))
                end
            end
        end
    end

    return orderedllis
end

"""
$(TYPEDSIGNATURES)

Return all next logical low level intent indices from `llis` given that now signal is positioned in `RouterPortLLI`
such that the `conintent` is satisfied.
Return an empty vector if no logical next is found.
"""
function getafterlliidx(ibnf::IBNFramework, conintent::ConnectivityIntent, llis, rplli::RouterPortLLI; verbose::Bool = false)
    lli_idx = findall(llis) do lli
        if lli isa TransmissionModuleLLI
            getlocalnode(lli) == getlocalnode(rplli) || return false
            getrouterportindex(lli) == getrouterportindex(rplli) || return false
            transmissionmode = gettransmissionmode(ibnf, lli)
            getrate(transmissionmode) >= getrate(conintent) || return false
            getrate(transmissionmode) <= getrouterportrate(ibnf, rplli) || return false
            return true
        elseif lli isa RouterPortLLI
            getlocalnode(lli) == getlocalnode(rplli) || return false
            return true
        end
        return false
    end
    return lli_idx
end

"""
$(TYPEDSIGNATURES)

Return all next logical low level intent indices from `llis` given that now signal is positioned in `TransmissionModuleLLI`
such that the `conintent` is satisfied.
Return an empty vector if no logical next is found.
"""
function getafterlliidx(ibnf::IBNFramework, conintent::ConnectivityIntent, llis, tmlli::TransmissionModuleLLI; verbose::Bool = false)
    lli_idx = findall(llis) do lli
        if lli isa RouterPortLLI
            getlocalnode(lli) == getlocalnode(tmlli) || return false
            getrouterportindex(lli) == getrouterportindex(tmlli) || return false
            transmissionmode = gettransmissionmode(ibnf, tmlli)
            getrate(transmissionmode) <= getrouterportrate(ibnf, lli) || return false
            return true
        elseif lli isa OXCAddDropBypassSpectrumLLI
            getlocalnode(lli) == getlocalnode(tmlli) || return false
            isaddportallocation(lli) || return false
            getadddropport(lli) == getadddropport(tmlli) || return false
            transmissionmode = gettransmissionmode(ibnf, tmlli)
            length(getspectrumslotsrange(lli)) == getspectrumslotsneeded(transmissionmode) || return false
            return true
        end
        return false
    end
    return lli_idx
end

"""
$(TYPEDSIGNATURES)

Return all next logical low level intent indices from `llis` given that now signal is positioned in `OXCAddDropBypassSpectrumLLI`
such that the `conintent` is satisfied.
Return an empty vector if no logical next is found.
"""
function getafterlliidx(ibnf::IBNFramework, conintent::ConnectivityIntent, llis, oxclli::OXCAddDropBypassSpectrumLLI; verbose::Bool = false)
    lli_idx = findall(llis) do lli
        if lli isa OXCAddDropBypassSpectrumLLI
            getlocalnode(lli) == getlocalnode_output(oxclli) || return false
            getlocalnode_input(lli) == getlocalnode(oxclli) || return false
            getspectrumslotsrange(lli) == getspectrumslotsrange(oxclli) || return false
            return true
        elseif lli isa TransmissionModuleLLI
            isdropportallocation(oxclli) || return false
            getlocalnode(lli) == getlocalnode(oxclli) || return false
            getadddropport(lli) == getadddropport(oxclli) || return false
            transmissionmode = gettransmissionmode(ibnf, lli)
            length(getspectrumslotsrange(oxclli)) == getspectrumslotsneeded(transmissionmode) || return false
            return true
        end
        return false
    end
    return lli_idx
end

function logicalordercontainsedge(lo::Vector{<:LowLevelIntent}, edge::Edge)
    for oxclli in filter(x -> x isa OXCAddDropBypassSpectrumLLI, lo)
        found = oxcllicontainsedge(oxclli, ege)
        found && return true
    end
    return false
end

"""
$(TYPEDSIGNATURES)
    Return a Vector{Int} with the path given from the logical low level intent order
"""
function logicalordergetpath(lo::Vector{<:LowLevelIntent})
    function validnextinsert(nd, p)
        return !iszero(nd) &&
            (
            isempty(p) ||
                (
                (length(p) == 1 && nd != p[end]) ||
                    (length(p) >= 2 && nd != p[end] && nd != p[end - 1])
            )
        )
    end

    path = LocalNode[]
    for oxclli in filter(x -> x isa OXCAddDropBypassSpectrumLLI, lo)
        input = getlocalnode_input(oxclli)
        validnextinsert(input, path) && push!(path, input)
        node = getlocalnode(oxclli)
        validnextinsert(node, path)  && push!(path, node)
        output = getlocalnode_output(oxclli)
        validnextinsert(output, path)  && push!(path, output)
    end

    return path
end

"""
$(TYPEDSIGNATURES)

    Check that the LowLevelIntents are consisting a single LightPath implementation
This means that the order of the LLIs should be
(RouterPortLLI) -> (TransmissionModuleLLI) -> OXCAddDropLLI -> (TranmsissionModuleLLI) -> (RouterPortLLI)
"""
function logicalorderissinglelightpath(lo::Vector{<:LowLevelIntent})
    phase = 1
    if first(lo) isa TransmissionModuleLLI || last(lo) isa TransmissionModuleLLI
        return false
    end
    for loi in lo
        if phase == 1 # next must be RouterPortLLI or TransmissionModule or OXCAddDrop
            if loi isa RouterPortLLI
                phase = 2
            elseif loi isa TransmissionModuleLLI
                return false
            elseif loi isa OXCAddDropBypassSpectrumLLI
                phase = 4
            else
                return false
            end
        elseif phase == 2
            if loi isa TransmissionModuleLLI
                phase = 3
            else
                return false
            end
        elseif phase == 3
            if loi isa OXCAddDropBypassSpectrumLLI
                phase = 4
            else
                return false
            end
        elseif phase == 4
            if loi isa TransmissionModuleLLI
                phase = 5
            elseif loi isa OXCAddDropBypassSpectrumLLI
                phase = 4
            else
                return false
            end
        elseif phase == 5
            if loi isa RouterPortLLI
                phase = 6
            else
                return false
            end
        elseif phase == 6
            return false
        end
    end
    return true
end

"""
$(TYPEDSIGNATURES)

    Return a Vector{Vector{Int}} being the lightpaths from the logical low level intent order
"""
function logicalordergetlightpaths(lo::Vector{<:LowLevelIntent})
    # find consequetive OXCLLis and pass them to `logicalordergetpaths`
    oxcblocks = findconsecutiveblocks(x -> x isa OXCAddDropBypassSpectrumLLI, lo)
    return [logicalordergetpath(lo[oxcblock[1]:oxcblock[2]]) for oxcblock in oxcblocks]
end

"""
    Return a Vector{Int} being the nodes that process electrically the signal
"""
function logicalordergetelectricalpresence(lo::Vector{<:LowLevelIntent})
    # find consequetive OXCLLis and pass them to `logicalordergetpaths`
    routerllis = filter(x -> x isa RouterPortLLI, lo)
    return unique(getlocalnode.(routerllis))
end
