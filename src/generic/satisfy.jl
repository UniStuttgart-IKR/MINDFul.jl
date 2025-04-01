function issatisfied(ibnf::IBNFramework, intentid::UUID, orderedllis::Vector{<:LowLevelIntent}; noextrallis = true, verbose::Bool = false)
    return issatisfied(ibnf, getidagnode(getidag(ibnf), intentid), orderedllis; noextrallis, verbose)
end
function issatisfied(ibnf::IBNFramework, intentid::UUID;  onlyinstalled = true, noextrallis = true, verbose::Bool = false)
    return issatisfied(ibnf, getidagnode(getidag(ibnf), intentid); onlyinstalled, noextrallis, verbose)
end
function getlogicallliorder(ibnf::IBNFramework, intentuuid::UUID; onlyinstalled = true, verbose::Bool = false)
    return getlogicallliorder(ibnf, getidagnode(getidag(ibnf), intentuuid); onlyinstalled, verbose)
end

"""
$(TYPEDSIGNATURES)

Steps by step check if `ibnf` satisfies the intent
For now works only with local view.
The options are:
- onlyinstalled: only consideres installed intents
- noextrallis: all LLI must be used
- orderedllis: pass list to access ordered llis
"""
function issatisfied(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}; onlyinstalled = true, noextrallis = true, verbose::Bool = false)
    orderedllis = getlogicallliorder(ibnf, idagnode; onlyinstalled, verbose)
    if getibnfid(ibnf) == getibnfid(getsourcenode(getintent(idagnode))) == getibnfid(getdestinationnode(getintent(idagnode)))
        # intradomain
        return issatisfied(ibnf, idagnode, orderedllis; noextrallis, verbose)
    else
        # crossdomain
    end
    getsourcenode(getintent(idagnode))
end

function issatisfied(ibnf::IBNFramework, idagnode::IntentDAGNode{<:RemoteIntent}; onlyinstalled = true, noextrallis = true, verbose::Bool = false)
    idagnodechildren = getidagnodechildren(getidag(ibnf), idagnode)
    length(idagnodechildren) == 1 || return false
    return issatisfied(ibnf, idagnodechildren[1]; onlyinstalled, noextrallis, verbose)
end

function issatisfied(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}, orderedllis::Vector{<:LowLevelIntent}; noextrallis = true, verbose::Bool = false)
    idag = getidag(ibnf)
    ibnag = getibnag(ibnf)
    conintent = getintent(idagnode)
    sourcelocalnode = getlocalnode(ibnag, getsourcenode(conintent))
    destlocalnode = getlocalnode(ibnag, getdestinationnode(conintent))
    constraints = getconstraints(conintent)

    istotalsatisfied = true

    isempty(orderedllis) && return false

    # check first
    let firstlli = orderedllis[1]
        opticalinitiateconstraint = getfirst(x -> x isa OpticalInitiateConstraint, constraints)
        if !isnothing(opticalinitiateconstraint)
            if !(firstlli isa OXCAddDropBypassSpectrumLLI && getlocalnode(firstlli) == sourcelocalnode &&
                    getlocalnode_input(firstlli) == something(getlocalnode(getibnag(ibnf), getglobalnode_input(opticalinitiateconstraint))))
                istotalsatisfied = false
            end
        else
            if !(firstlli isa RouterPortLLI) || getlocalnode(firstlli) != sourcelocalnode
                istotalsatisfied = false
            end
        end
    end

    # check last
    let lastlli = orderedllis[end]
        opticalterminateconstraint = getfirst(x -> x isa OpticalTerminateConstraint, constraints)
        if !isnothing(opticalterminateconstraint)
            if !(lastlli isa OXCAddDropBypassSpectrumLLI) || getlocalnode_output(lastlli) != destlocalnode
                istotalsatisfied = false
            end
        else
            if !(lastlli isa RouterPortLLI) || getlocalnode(lastlli) != destlocalnode
                istotalsatisfied = false
            end
        end
    end

    if noextrallis
        istotalsatisfied &= (length(getidagnodellis(idag, getidagnodeid(idagnode))) == length(orderedllis))
    end

    return istotalsatisfied
end

function getlogicallliorder(ibnf::IBNFramework, idagnode::IntentDAGNode{<:ConnectivityIntent}; onlyinstalled = true, verbose::Bool = false)
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

    conintent = getintent(idagnode)
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
            lli isa RouterPortLLI && getlocalnode(lli) == sourcelocalnode
        end
    end

    isnothing(lliidx1) && return orderedllis

    push!(orderedllis, popat!(llis, lliidx1))
    # continue to the second and so on...

    validcontinuity = true
    while !isempty(llis) && validcontinuity
        let lastlli = orderedllis[end]
            if lastlli isa RouterPortLLI
                nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                if isnothing(nextlliidx)
                    validcontinuity = false
                else
                    push!(orderedllis, popat!(llis, nextlliidx))
                end
            elseif lastlli isa TransmissionModuleLLI
                nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                if isnothing(nextlliidx)
                    validcontinuity = false
                else
                    push!(orderedllis, popat!(llis, nextlliidx))
                end
            elseif lastlli isa OXCAddDropBypassSpectrumLLI
                nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                if isnothing(nextlliidx)
                    validcontinuity = false
                else
                    push!(orderedllis, popat!(llis, nextlliidx))
                end
            end
        end
    end

    return orderedllis
end

"""
$(TYPEDSIGNATURES)

Return the next logical low level intent index from `llis` given that now signal is positioned in `RouterPortLLI`
such that the `conintent` is satisfied.
Return `nothing` if no logical next is found.
"""
function getafterlliidx(ibnf::IBNFramework, conintent::ConnectivityIntent, llis, rplli::RouterPortLLI; verbose::Bool = false)
    lli_idx = findfirst(llis) do lli
        lli isa TransmissionModuleLLI || return false
        getlocalnode(lli) == getlocalnode(rplli) || return false
        transmissionmode = gettransmissionmode(ibnf, lli)
        getrate(transmissionmode) >= getrate(conintent) || return false
        return true
    end
    return lli_idx
end

"""
$(TYPEDSIGNATURES)

Return the next logical low level intent index from `llis` given that now signal is positioned in `TransmissionModuleLLI`
such that the `conintent` is satisfied.
Return `nothing` if no logical next is found.
"""
function getafterlliidx(ibnf::IBNFramework, conintent::ConnectivityIntent, llis, tmlli::TransmissionModuleLLI; verbose::Bool = false)
    lli_idx = findfirst(llis) do lli
        if lli isa RouterPortLLI
            getlocalnode(lli) == getlocalnode(tmlli) || return false
            return true
        elseif lli isa OXCAddDropBypassSpectrumLLI
            getlocalnode(lli) == getlocalnode(tmlli) || return false
            isaddportallocation(lli) || return false
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

Return the next logical low level intent index from `llis` given that now signal is positioned in `OXCAddDropBypassSpectrumLLI`
such that the `conintent` is satisfied.
Return `nothing` if no logical next is found.
"""
function getafterlliidx(ibnf::IBNFramework, conintent::ConnectivityIntent, llis, oxclli::OXCAddDropBypassSpectrumLLI; verbose::Bool = false)
    lli_idx = findfirst(llis) do lli
        if lli isa OXCAddDropBypassSpectrumLLI
            getlocalnode(lli) == getlocalnode_output(oxclli) || return false
            getspectrumslotsrange(oxclli) == getspectrumslotsrange(oxclli) || return false
            return true
        elseif lli isa TransmissionModuleLLI
            isdropportallocation(oxclli) || return false
            getlocalnode(lli) == getlocalnode(oxclli) || return false
            transmissionmode = gettransmissionmode(ibnf, lli)
            length(getspectrumslotsrange(oxclli)) == getspectrumslotsneeded(transmissionmode) || return false
            return true
        end
        return false
    end
    return lli_idx
end

