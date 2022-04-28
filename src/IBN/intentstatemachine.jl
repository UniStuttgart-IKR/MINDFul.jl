deploy!(ibnc::IBN, ibns::IBN, intentidx::Int, itra::IntentTransition, strategy::IBNModus, algmethod 
        ; algargs...) = deploy!(ibnc, ibns, ibns.intents[intentidx], getroot(ibns.intents[intentidx]), itra, strategy, algmethod; algargs...)

deploy!(ibn::IBN, intentidx::Int, itra::IntentTransition, strategy::IBNModus, algmethod 
        ; algargs...) = deploy!(ibn, ibn.intents[intentidx], getroot(ibn.intents[intentidx]), itra, strategy, algmethod; algargs...)

"Usually handle in the root of the DAG"
deploy!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, itra::IntentTransition, strategy::IBNModus, algmethod
        ; algargs...) = deploy!(ibn, ibn, dag, idagn, itra, strategy, algmethod; algargs...)

"ibn-customer accesses the intent state machine of ibn-provider"
function deploy!(ibnc::IBN, ibns::IBN, dag::IntentDAG, idagn::IntentDAGNode, itra::IntentTransition, strategy::IBNModus, algmethod; algargs...)
    if getid(ibnc) == getid(ibns)
        step!(ibns, dag, idagn, idagn.state, itra, strategy, algmethod; algargs...)
    else
        @warn("no permissions implemented")
        step!(ibns, dag, idagn, idagn.state, itra, strategy, algmethod; algargs...)
    end
end

# TODO: replace inid with intent (for type inference)
function step!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, ista::IntentState, itra::IntentTransition, 
        strategy::SimpleIBNModus, algmethod; algargs...)
    if ista == compiled && itra == doinstall
        step!(ibn, dag, idagn, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == installed && itra == doinstall
        @info("Intent already installed")
    elseif ista == installed && itra == douninstall
        step!(ibn, dag, idagn, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == uninstalled && itra == douninstall
        @info("Intent already uninstalled")
    elseif ista == uncompiled && itra == docompile
        step!(ibn, dag, idagn, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == compiled && itra == docompile
        @info("Intent already compiled")
    else 
        @warn("illegal operation: Cannot "*string(itra)*" on "*string(ista))
        return false
    end
end

"A somehow more complicated state machine"
step!(ibn::IBN, inid::Int, ista::IntentState, itra::IntentTransition, strategy::AdvancedIBNModus) = error("notimplemented")

"Compiles an intent"
function step!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, ista::Val{uncompiled}, itra::Val{docompile}, intent_comp; algargs...)
    state_prev = getstate(idagn)
    state = compile!(ibn, dag, idagn, intent_comp; algargs...)
    state != state_prev && @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    return state
end

"""
Installs a single intent.
It applies the intent implementation on the network
"""
function step!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, ista::Val{compiled}, itra::Val{doinstall}, intent_real; algargs...)
#    if !issatisfied(ibn, dag, idagn; onlylogic=true)
#        @info "Intent realization is not logically constistent and will not procceed in installation"
#        return getstate(idagn)
#    end
    state_prev = getstate(idagn)
    state = realize!(ibn, dag, idagn, intent_real; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

function compile!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    algmethod(ibn, dag, idagn; algargs...)
    return getstate(idagn)
end

function realize!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    leafidns = getleafs(dag, idagn)
    # aggregate low level intents (might be collisions ?)
    for lidn in leafidns

        if lidn.intent isa RemoteIntent
            remibn = getibn(ibn, lidn.intent.ibnid)
            deploy!(ibn, remibn, lidn.intent.intentidx, 
                  doinstall, IBNFramework.SimpleIBNModus(), algmethod; algargs...)
        else
            algmethod(ibn, dag, lidn)
        end
    end
    return getstate(idagn)
end


"Uninstalls a single intent"
function step!(ibn::IBN, inid::Int, ista::Val{installed}, itra::Val{douninstall})
    intent = ibn.intents[inid]
    withdrew = withdraw(ibn, intent)
    if withdrew
        @info "Uninstalled intent $(ibn.intents[inid])"
        setstate!(intent, uninstalled)
        return true
    else
        return false
    end
end


"""
Realize the intent implementation by delegating tasks in the different responsible SDNs
First check, then reserve
"""
function directrealization!(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode{R}) where R<:LowLevelIntent
    if isavailable(ibn, dag, idn)
        if getstate(idn) != installed
            if reserve(ibn, dag, idn) 
                setstate!(idn, dag, ibn, Val(installed))
                return getstate(idn)
            end
        end
    end
    setstate!(idn, dag, ibn, Val(installfailed))
    return getstate(idn)
end
