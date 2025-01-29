"""
$(TYPEDSIGNATURES)

Steps by step check if `ibnf` satisfies the intent
Works only with local view
"""
function issatisfied(ibnf::IBNFramework, idagnode::IntentDAGNode{ConnectivityIntent}; verbose::Bool = false, assumeglobalknowledge::Bool = false)
    idag = getidag(ibnf)

    # get all LLIs
    llis = getintent.(getidagnodellis(idag))
    orderedlliidxs = Int[]
    istotalsatisfied = true

    conintent = getintent(idagnode)
    sourcelocalnode = getlocalnode(getsourcenode(conintent))
    destlocalnode = getlocalnode(getdestinationnode(conintent))

    # find the first LLI
    lliidx1 = findfirst(llis) do lli
        lli isa RouterPortLLI && getlocalnode(lli) == sourcelocalnode
    end

    if !isnothing(lliidx1)
        push!(orderedlliidxs, lliidx1)
        # continue to the second and so on...

        while length(orderedlliidxs) < length(llis) && istotalsatisfied
            let lastlli = llis[end]
                if lastlli isa RouterPortLLI
                    nextlliidx = getafterlliidx(ibnf, conintent, llis, lastlli; verbose)
                    if isnothing(nextlliidx)
                        istotalsatisfied = false
                    end
                elseif lastlli isa TransmissionModuleLLI
                    istotalsatisfied = false
                elseif lastlli isa OXCAddDropBypassSpectrumLLI
                    istotalsatisfied = false
                end
            end
        end
    else
        istotalsatisfied = false
    end
    @show orderedlliidxs
    return istotalsatisfied
end

function orderllis!(orderedllis, llis, )

end

"""
$(TYPEDSIGNATURES)

Return the next logical low level intent index from `llis` given that now signal is positioned in `RouterPortLLI`
such that the `conintent` is satisfied.
Return `nothing` if no logical next is found.
"""
function getafterlliidx(ibnf::IBNFramework, conintent::ConnectivityIntent, llis, rplli::RouterPortLLI; verbose::Bool = false)
    # searches for TransmissionModuleLLI
    lli_idx = findfirst(llis) do lli
        @returniffalse(verbose, lli isa TransmissionModuleLLI)
        # RouterPortLLI && lli.localnode = sourcenode

        getlocalnode(lli) == getlocalnode(rplli) || return false
        transmissionmode = gettransmissionmode(ibnf, lli)
        getrate(transmissionmode) > getrate(conintent) || return false
        return true
    end

    return lli_idx
end
