deploy!(ibn::IBN, inid::Int, itra::IntentTransition, strategy::IBNModus) = deploy!(ibn, ibn, inid, itra, strategy)

"ibn-customer accesses the intent state machine of ibn-provider"
function deploy!(ibnp::IBN, ibnc::IBN, inid::Int, itra::IntentTransition, strategy::IBNModus)
    if getid(ibnp) == getid(ibnc)
        step!(ibnc, inid, getstate(ibnc.intents[inid]), itra, strategy)
    else
        @warn("no permissions implemented")
        step!(ibnc, inid, getstate(ibnc.intents[inid]), itra, strategy)
    end
end

function step!(ibn::IBN, inid::Int, ista::IntentState, itra::IntentTransition, strategy::SimpleIBNModus)
    if ista == compiled && itra == doinstall
        step!(ibn, inid, Val(ista), Val(itra))
    elseif ista == installed && itra == doinstall
        @info("Intent already installed")
    elseif ista == installed && itra == douninstall
        step!(ibn, inid, Val(ista), Val(itra))
    elseif ista == uninstalled && itra == douninstall
        @info("Intent already uninstalled")
    elseif ista == uncompiled && itra == docompile
        step!(ibn, inid, Val(ista), Val(itra))
    elseif ista == compiled && itra == docompile
        @info("Intent already compiled")
    else 
        error("illegal operation: Cannot "*string(itra)*" on "*string(ista))
    end
end


"""
Installs a single intent.
First, it compiles the intent if it doesn't have already an implementation
Second, it applies the intent implementation on the network
"""
function step!(ibn::IBN, inid::Int, ista::Val{compiled}, itra::Val{doinstall}; intent_real=directrealization)
    intent = ibn.intents[inid]
    realized = false
    if getcompilation(intent) isa InheritIntentCompilation
        realized = inheritrealization(ibn, inid, intent_real=intent_real)
    else
        realized = intent_real(ibn, getcompilation(intent))
    end

    if realized 
        @info "Installed intent $(ibn.intents[inid])"
        setstate!(intent, installed)
        return true
    else
        return false
    end
end

"Compiles an intent"
function step!(ibn::IBN, inid::Int, ista::Val{uncompiled}, itra::Val{docompile}; intent_comp=shortestpathcompilation!)
    intent = ibn.intents[inid]
    
    # compile intent
    if ismissing(getcompilation(intent))
        intent_comp(ibn, ibn.intents[inid])
    end
    ismissing(getcompilation(intent)) && return false
    setstate!(intent, compiled)
    return true
end

"""
Installs a bunch of intents all together.
Takes into consideration resources collisions.
"""
function step!(ibn::IBN, inid::Vector{Int}, ista::Val{uninstalled}, itra::Val{doinstall})
    return false
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
Handles the realization of `InheritIntentCompilation` intents
Basically deploys all the child intents 
"""
function inheritrealization(ibn::IBN, idx::Int; intent_real=directrealization)
    intent = ibn.intents[idx]
    for intrc in children(intent)
        ccomp = getcompilation(intrc)
        if ccomp isa RemoteIntentCompilation
            deploy!(ibn, ccomp.remoteibn, ccomp.intentidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus())
        else
            if intent_real(ibn, ccomp)
                setstate!(intrc, installed)
            end
        end
    end
    return true
end

"""
Realize the intent implementation by delegating tasks in the different responsible SDNs
First check, then reserve
"""
function directrealization(ibn::IBN, intimp::ConnectivityIntentCompilation)
    #TODO check if intent already installed ?
    succeeded = true
    reclist = Vector{}()
    for e in edgeify(intimp.path)
        if controllerofnode(ibn, e.src) == controllerofnode(ibn, e.dst)
            #intradomain
            succeeded = succeeded && @recargs!(reclist, isavailable(controllerofnode(ibn, e.src), domainedge(ibn.cgr, e), intimp.capacity))
        else
            #interdomain
            succeeded = succeeded && @recargs!(reclist, isavailable(controllerofnode(ibn, e.src), controllerofnode(ibn, e.dst), compositeedge(ibn.cgr, e), intimp.capacity))
        end
        succeeded || break
    end
    if succeeded
        for rec in reclist
            reserve(rec...)
        end
    end
    return succeeded
end


function withdraw(ibn::IBN, intimp::ConnectivityIntentCompilation)
    for e in edgeify(intimp.path)
        if controllerofnode(ibn, e.src) == controllerofnode(ibn, e.dst)
            #intradomain
            free!(controllerofnode(ibn, e.src), domainedge(ibn.cgr, e), intimp.capacity)
        else
            #interdomain
            free!(controllerofnode(ibn, e.src), controllerofnode(ibn, e.dst), compositeedge(ibn.cgr, e), intimp.capacity)
        end
    end
    return true
end
