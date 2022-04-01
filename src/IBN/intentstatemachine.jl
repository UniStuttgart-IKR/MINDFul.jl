deploy!(ibn::IBN, inid::Int, itra::IntentTransition, strategy::IBNModus, algmethod; algargs...) = deploy!(ibn, ibn, inid, itra, strategy, algmethod; algargs...)

"ibn-customer accesses the intent state machine of ibn-provider"
function deploy!(ibnp::IBN, ibnc::IBN, inid::Int, itra::IntentTransition, strategy::IBNModus, algmethod; algargs...)
    if getid(ibnp) == getid(ibnc)
        step!(ibnc, inid, getstate(ibnc.intents[inid]), itra, strategy, algmethod; algargs...)
    else
        @warn("no permissions implemented")
        step!(ibnc, inid, getstate(ibnc.intents[inid]), itra, strategy, algmethod; algargs...)
    end
end

# TODO: replace inid with intent (for type inference)
function step!(ibn::IBN, inid::Int, ista::IntentState, itra::IntentTransition, strategy::SimpleIBNModus, algmethod; algargs...)
    if ista == compiled && itra == doinstall
        step!(ibn, inid, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == installed && itra == doinstall
        @info("Intent already installed")
    elseif ista == installed && itra == douninstall
        step!(ibn, inid, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == uninstalled && itra == douninstall
        @info("Intent already uninstalled")
    elseif ista == uncompiled && itra == docompile
        step!(ibn, inid, Val(ista), Val(itra), algmethod; algargs...)
    elseif ista == compiled && itra == docompile
        @info("Intent already compiled")
    else 
        error("illegal operation: Cannot "*string(itra)*" on "*string(ista))
    end
end

"A somehow more complicated state machine"
step!(ibn::IBN, inid::Int, ista::IntentState, itra::IntentTransition, strategy::AdvancedIBNModus) = error("notimplemented")

"Compiles an intent"
function step!(ibn::IBN, inid::Int, ista::Val{uncompiled}, itra::Val{docompile}, intent_comp; algargs...)
    success = compile!(ibn, ibn.intents[inid], intent_comp; algargs...)
    if success
       @info "Compiled $(ibn.intents[inid])"
       setstate!(ibn.intents[inid], compiled)
    else
        @info "Failed to compile $(ibn.intents[inid]) on IBN with id $(getid(ibn))"
    end
    return success
end

"""
Installs a single intent.
First, it compiles the intent if it doesn't have already an implementation
Second, it applies the intent implementation on the network
"""
function step!(ibn::IBN, inid::Int, ista::Val{compiled}, itra::Val{doinstall}, intent_real; algargs...)
    success = realize!(ibn, ibn.intents[inid], intent_real; algargs...)
    if success
       @info "Installed $(ibn.intents[inid])"
       setstate!(ibn.intents[inid], installed)
    else
       @info "Failed to install $(ibn.intents[inid])"
    end
    return success
end

function compile!(ibn::IBN, intr::R, algmethod::T; algargs...) where {R<:IntentTree, T<:Function}
    success = algmethod(ibn, intr; algargs...)
    success && setstate!(intr, compiled)
    return success
end

function realize!(ibn::IBN, intr::R, algmethod::T; algargs...) where {R<:IntentTree, T<:Function}
    success = false
    comp = getcompilation(intr)
    if comp isa InheritIntentCompilation
        success = true
        for intchr in children(intr)
            success = success && realize!(ibn, intchr, algmethod)
        end
    elseif comp isa RemoteIntentCompilation
        success = deploy!(ibn, comp.remoteibn, comp.intentidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), algmethod; algargs...)
    else 
        success = algmethod(ibn, getcompilation(intr))
    end
    success && setstate!(intr, installed) 
    return success
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
function directrealization(ibn::IBN, intimp::ConnectivityIntentCompilation)
    @info "Installing intent ...$(intimp)"
    if isavailable(ibn, intimp.path, intimp.capacity)
        return reserve(ibn, intimp.path, intimp.capacity)
    end
    return false
end
#function directrealization(ibn::IBN, intimp::ConnectivityIntentCompilation)
#    @info "Installing int ...$(intimp)"
#    #TODO check if intent already installed ?
#    succeeded = true
#    reclist = Vector{}()
#    for e in edgeify(intimp.path)
#        controllerofnodesrc = controllerofnode(ibn, e.src)
#        controllerofnodedst = controllerofnode(ibn, e.dst)
#        if controllerofnodesrc == controllerofnodedst
#            #intradomain
#            succeeded = succeeded && @recargs!(reclist, isavailable(controllerofnodesrc, domainedge(ibn.cgr, e), intimp.capacity))
#        else
#            #interdomain
#            if controllerofnodesrc isa IBN || controllerofnodedst isa IBN
#                cesrc = controllerofnodesrc isa IBN ? (getid(controllerofnodesrc), ibn.cgr.vmap[e.src][2]) : (getid(ibn), e.src)
#                ibnsrc = controllerofnodesrc isa IBN ? controllerofnodesrc : ibn
#                cedst = controllerofnodedst isa IBN ? (getid(controllerofnodedst), ibn.cgr.vmap[e.dst][2]) : (getid(ibn), e.dst)
#                ibndst = controllerofnodedst isa IBN ? controllerofnodedst : ibn
#                ce = CompositeEdge(cesrc, cedst)
#
#                succeeded = succeeded && @recargs!(reclist, isavailable(ibnsrc, ibndst, ce, intimp.capacity))
#            else
#                succeeded = succeeded && @recargs!(reclist, isavailable(controllerofnode(ibn, e.src), controllerofnode(ibn, e.dst), 
#                                                                        compositeedge(ibn.cgr, e), intimp.capacity))
#            end
#        end
#        succeeded || break
#    end
#    if succeeded
#        for rec in reclist
#            reserve(rec...)
#        end
#    end
#    return succeeded
#end


#
#--------------------- WIP ---------------------#
#
"""
Installs a bunch of intents all together.
Takes into consideration resources collisions.
"""
function step!(ibn::IBN, inid::Vector{Int}, ista::Val{uninstalled}, itra::Val{doinstall})
    return false
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
