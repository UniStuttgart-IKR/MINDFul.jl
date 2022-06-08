deploy!(ibnc::IBN, ibns::IBN, intentid::Int, itra::IntentTransition, strategy::IBNModus, algmethod 
        ; algargs...) = deploy!(ibnc, ibns, getintent(ibns,intentid), getroot(getintent(ibns,intentid)), itra, strategy, algmethod; algargs...)

deploy!(ibn::IBN, intentid::Int, itra::IntentTransition, strategy::IBNModus, algmethod 
        ; algargs...) = deploy!(ibn, getintent(ibn,intentid), getroot(getintent(ibn,intentid)), itra, strategy, algmethod; algargs...)

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
    elseif (ista == installed || ista == failure) && itra == douninstall
        step!(ibn, dag, idagn, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == uninstalled && itra == douninstall
        @info("Intent already uninstalled")
    elseif ista == uncompiled && itra == docompile
        step!(ibn, dag, idagn, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == compiled && itra == docompile
        @info("Recompiling intent...")
    elseif ista == failure && itra == docompile
        step!(ibn, dag, idagn, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == compiled && itra == douncompile
        step!(ibn, dag, idagn, Val(ista), Val(itra), algmethod; algargs...)
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
    if state != state_prev 
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No compilation possible. $(state_prev) to $(state): $(idagn.intent)"
    end
    return state
end

"""
Installs a single intent.
It applies the intent implementation on the network
"""
function step!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, ista::Val{compiled}, itra::Val{doinstall}, intent_inst; algargs...)
#    if !issatisfied(ibn, dag, idagn; onlylogic=true)
#        @info "Intent realization is not logically constistent and will not procceed in installation"
#        return getstate(idagn)
#    end
    state_prev = getstate(idagn)
    state = install!(ibn, dag, idagn, intent_inst; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

"Uninstalls a single intent"
function step!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, ista::T, itra::Val{douninstall}, intent_uninst; algargs...) where 
        T <: Union{Val{installed}, Val{failure}}
    state_prev = getstate(idagn)
    state = uninstall!(ibn, dag, idagn, intent_uninst; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

function step!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, ista::Val{compiled}, itra::Val{douncompile}, intent_uncomp; algargs...)
    state_prev = getstate(idagn)
    state = uncompile!(ibn, dag, idagn, intent_uncomp; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

function step!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, ista::Val{failure}, itra::Val{docompile}, intent_recomp; algargs...)
    state_prev = getstate(idagn)
    state = recompile!(ibn, dag, idagn, intent_recomp; algargs...)
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

"""
Delete all dag nodes except for the root
If it has Remote Intent they need to be deleted also.
"""
function uncompile!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    while true
        # MGN is a little bit unstable. It reconfigures the structure everytime it gets deleted.
        nv(dag) > 1 || break
        idn = dag[MGN.label_for(dag, 2)]
        if idn.intent isa RemoteIntent
            remibn = getibn(ibn, idn.intent.ibnid)
            ibnpissuer = IBNIssuer(getid(ibn), getid(dag), getid(idn))
            remint = idn.intent.intentidx
            # first uncompile them
            deploy!(ibn, remibn, remint, douncompile, SimpleIBNModus(), () -> nothing)
            # then delete them
            remintent!(ibnpissuer, remibn, remint)
        end
        rem_vertex!(dag, 2)
    end
    setstate!(idagn, dag, ibn, Val(uncompiled))
    return getstate(idagn)
end

function install!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
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

#same code as install! more or less: double code
function uninstall!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    leafidns = getleafs(dag, idagn)
    # aggregate low level intents (might be collisions ?)
    for lidn in leafidns
        if lidn.intent isa RemoteIntent
            remibn = getibn(ibn, lidn.intent.ibnid)
            deploy!(ibn, remibn, lidn.intent.intentidx, 
                  douninstall, IBNFramework.SimpleIBNModus(), algmethod; algargs...)
        else
            algmethod(ibn, dag, lidn)
        end
    end
    return getstate(idagn)
end

# double code
function recompile!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    # uninstall all
    # compile all
end

"""
Realize the intent implementation by delegating tasks in the different responsible SDNs
First check, then reserve
"""
function directinstall!(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode{R}) where R<:LowLevelIntent
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

"""
Uninstalls a low-level intent intent
"""
function directuninstall!(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode{R}) where R<:LowLevelIntent
    if free!(ibn, dag, idn)
        setstate!(idn, dag, ibn, Val(compiled))
        return getstate(idn)
    end
end
