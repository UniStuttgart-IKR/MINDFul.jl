deploy!(ibnc::IBN, ibns::IBN, intentid::UUID, args...; nargs...) = 
    deploy!(ibnc, ibns, getintentnode(ibns,intentid), args...; nargs...)

"Assume intent is root of DAG"
deploy!(ibn::IBN, intentid::UUID, args...; nargs...) = 
    deploy!(ibn, getintentnode(ibn,intentid), args...; nargs...)

"Assume intent comes from Network Operator"
deploy!(ibn::IBN, args...; nargs...) = 
    deploy!(ibn, ibn, args...; nargs...)

"No `algmethod` provided"
deploy!(ibnc::IBN, ibns::IBN, idagn::IntentDAGNode, itra::IntentTransition, strategy::IBNModus; nargs...) = 
    deploy!(ibnc, ibns, idagn, itra, strategy, () -> nothing; nargs...)

"""
"$(TYPEDSIGNATURES)

The IBN customer `ibnc` accesses the intent state machine of IBN server `ibns` and 
commands the `IntentTransition` `itra` for the intent DAG node `idagn`
following the state-machine strategy `IBNModus` and the transition methodology `algmethod`.
"""
function deploy!(ibnc::IBN, ibns::IBN, idagn::IntentDAGNode, itra::IntentTransition, strategy::IBNModus, algmethod;
        time, algargs...)
    if getid(ibnc) == getid(ibns)
        step!(ibns, idagn, idagn.state, itra, strategy, algmethod; time, algargs...)
    else
#        @warn("no permissions implemented")
        step!(ibns, idagn, idagn.state, itra, strategy, algmethod; time, algargs...)
    end
end

"""
"$(TYPEDSIGNATURES)

Step the state machine of `ibn` for the intent DAG node `idagn`
with state `ista` following the transition `itra`, for state machine strategy 
`SimpleIBNModus` following the methodology `algmethod`. If more parameters
are needed for `algmethod`, pass them in the varargs `algargs`.
"""
function step!(ibn::IBN, idagn::IntentDAGNode, ista::IntentState, itra::IntentTransition, 
        ::SimpleIBNModus, algmethod; algargs...)
    if ista == compiled && itra == doinstall
        step!(ibn, idagn, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == installed && itra == doinstall
        @info("Intent already installed")
    elseif (ista == installed || ista == failure) && itra == douninstall
        step!(ibn, idagn, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == uninstalled && itra == douninstall
        @info("Intent already uninstalled")
    elseif ista == uncompiled && itra == docompile
        step!(ibn, idagn, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == compiled && itra == docompile
        @info("Recompiling intent...")
    elseif ista == failure && itra == docompile
        step!(ibn, idagn, Val(ista), Val(itra), algmethod; algargs...)
    # TODO: uncompiled must be compiling state
    elseif ista in [compiled, uncompiled] && itra == douncompile
        step!(ibn, idagn, Val(ista), Val(itra), algmethod; algargs...)
    else 
        foreach(s-> println(s),stacktrace())
        @warn("illegal operation: Cannot "*string(itra)*" on "*string(ista))
        return false
    end
end

"$(TYPEDSIGNATURES) A somehow more complicated state machine"
step!(ibn::IBN, inid::Int, ista::IntentState, itra::IntentTransition, strategy::AdvancedIBNModus) = error("notimplemented")

"$(TYPEDSIGNATURES) Compiles an intent"
function step!(ibn::IBN, idagn::IntentDAGNode, ista::Val{uncompiled}, itra::Val{docompile}, intent_comp; algargs...)
    state_prev = getstate(idagn)
    state = compile!(ibn, idagn, intent_comp; algargs...)
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
function step!(ibn::IBN, idagn::IntentDAGNode, ista::Val{compiled}, itra::Val{doinstall}, intent_inst; algargs...)
    state_prev = getstate(idagn)
    state = install!(ibn, idagn, intent_inst; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

"$(TYPEDSIGNATURES) Uninstalls a single intent"
function step!(ibn::IBN, idagn::IntentDAGNode, ista::T, itra::Val{douninstall}, intent_uninst; algargs...) where 
        T <: Union{Val{installed}, Val{failure}}
    state_prev = getstate(idagn)
    state = uninstall!(ibn, idagn, intent_uninst; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

# TODO: code duplication
"$(TYPEDSIGNATURES)"
function step!(ibn::IBN, idagn::IntentDAGNode, ista::Val{uncompiled}, itra::Val{douncompile}, intent_uncomp; algargs...)
    state_prev = getstate(idagn)
    state = uncompile!(ibn, idagn, intent_uncomp; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

"$(TYPEDSIGNATURES)"
function step!(ibn::IBN, idagn::IntentDAGNode, ista::Val{compiled}, itra::Val{douncompile}, intent_uncomp; algargs...)
    state_prev = getstate(idagn)
    state = uncompile!(ibn, idagn, intent_uncomp; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

"$(TYPEDSIGNATURES)"
function step!(ibn::IBN, idagn::IntentDAGNode, ista::Val{failure}, itra::Val{docompile}, intent_recomp; algargs...)
    state_prev = getstate(idagn)
    state = recompile!(ibn, idagn, intent_recomp; algargs...)
    if state != state_prev
        @info "Transitioned $(state_prev) to $(state): $(idagn.intent)"
    else
        @info "No possible Transition from $(state_prev): $(idagn.intent)"
    end
    return state
end

"$(TYPEDSIGNATURES) "
function compile!(ibn::IBN, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    algmethod(ibn, idagn; algargs...)
    return getstate(idagn)
end

"""
$(TYPEDSIGNATURES)

Delete all dag nodes except for the root.
If it has Remote Intent they need to be deleted also.
"""
function uncompile!(ibn::IBN, idagn::IntentDAGNode, algmethod::T; time) where {T<:Function}
    dag = getintentdag(ibn)
    nodes2dlt = descendants(dag, idagn; exclusive=true)
    for idn in nodes2dlt
        getstate(idn) == installed && error("cannot directly uncompiled installed intent. Reached corrupted state.")
        if idn.intent isa RemoteIntent
            remibn = getibn(ibn,  getremibnid(getintent(idn)))
            remint = getremintentid(getintent(idn))
            # first uncompile them
            deploy!(ibn, remibn, remint, douncompile, SimpleIBNModus(); time)
            # then delete them
            ibnpissuer = IBNIssuer(getid(ibn), getid(idn))
            remintent!(ibnpissuer, remibn, remint)
        end
        rem_vertex!(dag, MGN.code_for(dag, getid(idn)))
    end
    # cut all out-edges
    foreach(outneighbors(dag, MGN.code_for(dag, getid(idagn)))) do nei
        MGN.rem_edge!(dag, MGN.code_for(dag, getid(idagn)), nei)
    end
    setstate!(idagn, ibn, Val(uncompiled); time)
    return getstate(idagn)
end

"$(TYPEDSIGNATURES)"
function install!(ibn::IBN, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    leafidns = filter(l->getstate(l) !== installed ,getleafs(getintentdag(ibn), idagn))
    # aggregate low level intents (might be collisions ?)
    for lidn in leafidns
        if lidn.intent isa RemoteIntent
            remibn = getibn(ibn, lidn.intent.ibnid)
            deploy!(ibn, remibn, lidn.intent.intentidx, 
                  doinstall, MINDFul.SimpleIBNModus(), algmethod; algargs...)
        else
            algmethod(ibn, lidn; algargs...)
        end
    end
    try2setstate!(idagn, ibn, Val(installed); time=algargs[:time]) # in case all low level intents were already installed
    return getstate(idagn)
end

#same code as install! more or less: double code
"$(TYPEDSIGNATURES)"
function uninstall!(ibn::IBN, idagn::IntentDAGNode, algmethod::T; algargs...) where {T<:Function}
    leafidns = getleafs(getintentdag(ibn), idagn; exclusive=true)
    # aggregate low level intents (might be collisions ?)
    for lidn in leafidns
        if lidn.intent isa RemoteIntent
            remibn = getibn(ibn, lidn.intent.ibnid)
            deploy!(ibn, remibn, lidn.intent.intentidx, 
                  douninstall, MINDFul.SimpleIBNModus(), algmethod; algargs...)
        else
            algmethod(ibn, lidn; algargs...)
        end
    end
    length(leafidns) == 0 && setstate!(idagn, ibn, compiled; time=algargs[:time])
    return getstate(idagn)
end

"""
$(TYPEDSIGNATURES)

Realize the intent implementation by delegating tasks in the different responsible SDNs.
First check, then reserve.
"""
function directinstall!(ibn::IBN, idn::IntentDAGNode{R}; time) where R<:LowLevelIntent
    if isavailable(ibn, idn)
        if getstate(idn) != installed
            if reserve!(ibn, idn) 
                setstate!(idn, ibn, Val(installed); time)
                return getstate(idn)
            end
        end
    end
    setstate!(idn, ibn, Val(installfailed); time)
    return getstate(idn)
end

"""
$(TYPEDSIGNATURES)

Uninstalls a low-level intent intent
"""
function directuninstall!(ibn::IBN, idn::IntentDAGNode{R}; time) where R<:LowLevelIntent
    if free!(ibn, idn)
        setstate!(idn, ibn, Val(compiled); time)
        return getstate(idn)
    end
end
