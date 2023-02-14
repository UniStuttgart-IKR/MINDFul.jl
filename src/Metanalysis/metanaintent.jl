"$(TYPEDSIGNATURES) Find the downtime of intent `idn` by using the logs and the current clock time `ct`"
function getdowntime(idn::IntentDAGNode, ct)
    lt = idn.logstate.logtime
    downtime = zero(lt[1][1])
    t = 1
    while (true)
        t1_ind = findnext(x -> x[2] == failure, lt, t)
        if t1_ind !== nothing
            t2 = findnext(x -> x[2] == installed, lt, t1_ind)
            if t2 !== nothing
                downtime += lt[t2][1] - lt[t1_ind][1]
            else
                downtime += ct - lt[t1_ind][1]
            end
            t = t2
        else
            break
        end
    end
    return downtime
end

# break it down to 2 local-global functions for type stability
"$(TYPEDSIGNATURES) Get the compilation of the intent `intentidx` in `ibn` by assembling the low-level intents."
function getcompiledintent(ibn::IBN, intentidx::Int, globalknow=false)
    glbns, _ = logicalorderedintents(ibn, intentidx, globalknow)
    llis = getfield.(glbns, :lli)
    
    # create path
    path = Vector{Tuple{Int, Int}}()
    fr_slots = Vector{UnitRange{Int}}()
    electric_reg = Vector{Tuple{Int,Int}}()
    for (i,lli) in enumerate(llis)
        if lli isa NodeRouterPortIntent
            push!(electric_reg, lli.node)
        elseif lli isa NodeSpectrumIntent
            if length(path) == 0 
                push!(path, lli.edge.src, lli.edge.dst)
                push!(fr_slots, lli.slots)
            else
                if path[end] !== lli.edge.dst
                    push!(path, lli.edge.dst)
                    push!(fr_slots, lli.slots)
                end
            end
        elseif lli isa RemoteLogicIntent && lli.intent isa EdgeIntent
            constrs = getconstraints(lli.intent)
            if constrs isa GoThroughConstraint{Missing} && constrs.layer == signalElectrical
                push!(electric_reg, constrs.node)
            end
        end
    end
    rem_intents_uuid = [(lli, glbns[i].idn.id) for (i,lli) in enumerate(llis) if lli isa RemoteLogicIntent]
    rem_intents = Base.getindex.(rem_intents_uuid, 1)
    rem_intent_uuid = Base.getindex.(rem_intents_uuid, 2)

    # constraints
    constrs = getconstraints(getuserintent(getintent(ibn, intentidx)).intent)

    compiledintent = CompiledConnectivityIntent(path, fr_slots, electric_reg, 
                                                length(rem_intents) > 0 ? rem_intents : missing,
                                                length(rem_intent_uuid) >0 ? rem_intent_uuid : missing )
    return compiledintent
end
