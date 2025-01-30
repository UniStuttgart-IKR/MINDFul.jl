"""
$(TYPEDSIGNATURES)

Steps by step check if `ibnf` satisfies the intent
Works only with local view
"""
function issatisfied(ibnf::IBNFramework, idagnode::IntentDAGNode{ConnectivityIntent}; verbose::Bool = false, assumeglobalknowledge::Bool = false)
    idag = getidag(ibnf)

    # get all LLIs
    llis = getintent.(getidagnodellis(idag))
    orderedllis = empty(llis)
    istotalsatisfied = true

    conintent = getintent(idagnode)
    sourcelocalnode = getlocalnode(getsourcenode(conintent))
    destlocalnode = getlocalnode(getdestinationnode(conintent))

    # find the first LLI
    lliidx1 = findfirst(llis) do lli
        lli isa RouterPortLLI && getlocalnode(lli) == sourcelocalnode
    end

    if !isnothing(lliidx1)
        push!(orderedllis, popat!(llis, lliidx1))
        # continue to the second and so on...

        while !isempty(llis) && istotalsatisfied
            let lastlli = orderedllis[end]
                if lastlli isa RouterPortLLI
                    nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                    if isnothing(nextlliidx)
                        istotalsatisfied = false
                    else
                        push!(orderedllis, popat!(llis, nextlliidx))
                    end
                elseif lastlli isa TransmissionModuleLLI
                    nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                    if isnothing(nextlliidx)
                        istotalsatisfied = false
                    else
                        push!(orderedllis, popat!(llis, nextlliidx))
                    end
                elseif lastlli isa OXCAddDropBypassSpectrumLLI
                    nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                    if isnothing(nextlliidx)
                        istotalsatisfied = false
                    else
                        push!(orderedllis, popat!(llis, nextlliidx))
                    end
                end
            end
        end
    else
        istotalsatisfied = false
    end

    let lastlli = orderedllis[end]
        if !(lastlli isa RouterPortLLI) || getlocalnode(lastlli) != destlocalnode
            istotalsatisfied = false
        end
    end
    return istotalsatisfied
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
        getrate(transmissionmode) > getrate(conintent) || return false
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
