deploy!(ibnc::IBN, ibns::IBN, intentid::Int, args...; nargs...) = 
    deploy!(ibnc, ibns, getintent(ibns,intentid), getuserintent(getintent(ibns,intentid)), args...; nargs...)

"Assume intent is root of DAG"
deploy!(ibn::IBN, intentid::Int, args...; nargs...) = 
    deploy!(ibn, getintent(ibn,intentid), getuserintent(getintent(ibn,intentid)), args...; nargs...)

"Assume intent comes from Network Operator"
deploy!(ibn::IBN, dag::IntentDAG, args...; nargs...) = 
    deploy!(ibn, ibn, dag, args...; nargs...)

"No `algmethod` provided"
deploy!(ibnc::IBN, ibns::IBN, dag::IntentDAG, idagn::IntentDAGNode, itra::IntentTransition, strategy::IBNModus; nargs...) = 
    deploy!(ibnc, ibns, dag, idagn, itra, strategy, () -> nothing; nargs...)

"""
"$(TYPEDSIGNATURES)

The IBN customer `ibnc` accesses the intent state machine of IBN server `ibns` and 
commands the `IntentTransition` `itra` for the intent DAG node `idagn` of DAG `dag` 
following the state-machine strategy `IBNModus` and the transition methodology `algmethod`.
"""
function deploy!(ibnc::IBN, ibns::IBN, dag::IntentDAG, idagn::IntentDAGNode, itra::IntentTransition, strategy::IBNModus, algmethod;
        time, algargs...)
    if getid(ibnc) == getid(ibns)
        step!(ibns, dag, idagn, idagn.state, itra, strategy, algmethod; time, algargs...)
    else
#        @warn("no permissions implemented")
        step!(ibns, dag, idagn, idagn.state, itra, strategy, algmethod; time, algargs...)
    end
end

"""
"$(TYPEDSIGNATURES)

Step the state machine of `ibn` for the intent DAG node `idagn` of DAG `dag` 
with state `ista` following the transition `itra`, for state machine strategy 
`SimpleIBNModus` following the methodology `algmethod`. If more parameters
are needed for `algmethod`, pass them in the varargs `algargs`.
"""
function step!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, ista::IntentState, itra::IntentTransition, 
        ::SimpleIBNModus, algmethod; algargs...)
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
    # TODO: uncompiled must be compiling state
    elseif ista in [compiled, uncompiled] && itra == douncompile
        step!(ibn, dag, idagn, Val(ista), Val(itra), algmethod; algargs...)
    else 
        @warn("illegal operation: Cannot "*string(itra)*" on "*string(ista))
        return false
    end
end

"$(TYPEDSIGNATURES) A somehow more complicated state machine"
step!(ibn::IBN, inid::Int, ista::IntentState, itra::IntentTransition, strategy::AdvancedIBNModus) = error("notimplemented")

"$(TYPEDSIGNATURES) Compiles an intent"
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
$(TYPEDSIGNATURES) 

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

"$(TYPEDSIGNATURES) Uninstalls a single intent"
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

# TODO: code duplication
"$(TYPEDSIGNATURES)"
function step!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, ista::Val{uncompiled}, itra::Val{douncompile}, intent_uncomp; algargs...)
    state_prev = getstate(idagn)
    state = uncompile!(ibn, dag, idagn, intent_uncomp; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

"$(TYPEDSIGNATURES)"
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

"$(TYPEDSIGNATURES)"
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

"$(TYPEDSIGNATURES) "
function compile!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    algmethod(ibn, dag, idagn; algargs...)
    return getstate(idagn)
end

"""
$(TYPEDSIGNATURES)

Delete all dag nodes except for the root.
If it has Remote Intent they need to be deleted also.
"""
function uncompile!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; time) where {T<:Function}
    while true
        # MGN is a little bit unstable. It reconfigures the structure everytime it gets deleted.
        nv(dag) > 1 || break
        # get randomly an intent that is not the root
        idn = dag[MGN.label_for(dag, 2)]
        if idn.intent isa RemoteIntent
            remibn = getibn(ibn, idn.intent.ibnid)
            ibnpissuer = IBNIssuer(getid(ibn), getid(dag), getid(idn))
            remint = idn.intent.intentidx
            # first uncompile them
            deploy!(ibn, remibn, remint, douncompile, SimpleIBNModus(); time)
            # then delete them
            remintent!(ibnpissuer, remibn, remint)
        end
        rem_vertex!(dag, 2)
    end
    setstate!(idagn, dag, ibn, Val(uncompiled); time)
    return getstate(idagn)
end

"$(TYPEDSIGNATURES)"
function install!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    leafidns = getleafs(dag, idagn)
    # aggregate low level intents (might be collisions ?)
    for lidn in leafidns
        if lidn.intent isa RemoteIntent
            remibn = getibn(ibn, lidn.intent.ibnid)
            deploy!(ibn, remibn, lidn.intent.intentidx, 
                  doinstall, MINDFul.SimpleIBNModus(), algmethod; algargs...)
        else
            algmethod(ibn, dag, lidn; algargs...)
        end
    end
    return getstate(idagn)
end

#same code as install! more or less: double code
"$(TYPEDSIGNATURES)"
function uninstall!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    leafidns = getleafs(dag, idagn)
    # aggregate low level intents (might be collisions ?)
    for lidn in leafidns
        if lidn.intent isa RemoteIntent
            remibn = getibn(ibn, lidn.intent.ibnid)
            deploy!(ibn, remibn, lidn.intent.intentidx, 
                  douninstall, MINDFul.SimpleIBNModus(), algmethod; algargs...)
        else
            algmethod(ibn, dag, lidn; algargs...)
        end
    end
    return getstate(idagn)
end

# double code
"$(TYPEDSIGNATURES)"
function recompile!(ibn::IBN, dag::IntentDAG, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    # uninstall all
    # compile all
end

"""
$(TYPEDSIGNATURES)

Realize the intent implementation by delegating tasks in the different responsible SDNs.
First check, then reserve.
"""
function directinstall!(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode{R}; time) where R<:LowLevelIntent
    if isavailable(ibn, dag, idn)
        if getstate(idn) != installed
            if reserve!(ibn, dag, idn) 
                setstate!(idn, dag, ibn, Val(installed); time)
                return getstate(idn)
            end
        end
    end
    setstate!(idn, dag, ibn, Val(installfailed); time)
    return getstate(idn)
end

"""
$(TYPEDSIGNATURES)

Uninstalls a low-level intent intent
"""
function directuninstall!(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode{R}; time) where R<:LowLevelIntent
    if free!(ibn, dag, idn)
        setstate!(idn, dag, ibn, Val(compiled); time)
        return getstate(idn)
    end
end
