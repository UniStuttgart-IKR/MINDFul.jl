getintentidx(idag::IntentDAG) = idag.graph_data.id
"$(TYPEDSIGNATURES) Get all intents from the intent DAG `dag`"
getnode(i::NodeRouterPortIntent) = i.node
getnode(i::NodeSpectrumIntent) = i.node

"$(TYPEDSIGNATURES) Converts to a global view."
convert2global(ibn::IBN, lli::NodeSpectrumIntent{Int, E}) where 
    E<:Edge = NodeSpectrumIntent(globalnode(ibn, lli.node), globaledge(ibn, lli.edge), lli.slots, lli.bandwidth, lli.sptype)

"$(TYPEDSIGNATURES) Converts to a global view."
convert2global(ibn::IBN, lli::NodeROADMIntent) = NodeROADMIntent(globalnode(ibn, lli.node), 
                                                                 ismissing(lli.inedge) ? missing : globaledge(ibn, lli.inedge), 
                                                                 ismissing(lli.outedge) ? missing : globaledge(ibn, lli.outedge),
                                                                           lli.slots)

"$(TYPEDSIGNATURES) Converts to a global view."
convert2global(ibn::IBN, lli::NodeRouterPortIntent{Int}) = 
    NodeRouterPortIntent(globalnode(ibn, lli.node), lli.rate)

"$(TYPEDSIGNATURES) Converts to a global view."
convert2global(ibn::IBN, lli::NodeTransmoduleIntent{Int}) = 
    NodeTransmoduleIntent(globalnode(ibn, lli.node), lli.tm)

"$(TYPEDSIGNATURES) Get a tuple of globally identifying the intent of DAG node `idn` of DAG of `ibn`."
function globalintent(ibn::IBN, idn::R=missing) where R <: Union{IntentDAGNode, Missing}
    return (getid(ibn), getid(idn))
end

"$(TYPEDSIGNATURES) Return `true` if `intent` is an intra-domain intent"
function isintraintent(ibn::IBN, intent::I) where I<:ConnectivityIntent
    getid(ibn) == getsrc(intent)[1] == getdst(intent)[1] && return true
    getdst(intent) ∈ globalnode.([ibn], bordernodes(ibn; subnetwork_view=false)) &&
        any(c -> c isa BorderTerminateConstraint, getconstraints(intent)) && return true
    return false
end

"$(TYPEDSIGNATURES) Return `true` if `intent` is not valid (e.g. source and dest are the same)"
function isselfintent(intent::I) where I<:ConnectivityIntent
    return getsrc(intent) == getdst(intent) && !any(c -> c isa BorderInitiateConstraint, getconstraints(intent))
end

"$(TYPEDSIGNATURES) Get first DAG node that matches `intent` in DAG `dag`"
function getfirstdagnode_fromintent(dag::IntentDAG, intent::Intent)
    for idn in getintentdagnodes(dag)
        if getintent(idn) == intent
            return idn
        end
    end
end

"""$(TYPEDSIGNATURES)

Check all constraints of the intent defined by `idn`.
If some of them are (partially) satisfied (modify) delete them and return the (modified +) rest.
"""
function adjustNpropagate_constraints!(ibn::IBN, idn::IntentDAGNode)
    constraints = getconstraints(getintent(idn))
    propagete_constraints = Vector{IntentConstraint}()
    for (i,constr) in enumerate(constraints)
        if constr isa DelayConstraint
            globalviewpath = getcompiledintent(ibn, getid(idn))
            if !isempty(globalviewpath)!
                localpath = localnode.(ibn, globalviewpath; subnetwork_view=false)
                #readjust intent
                mydelay = delay(getdistance(ibn, localpath))
                push!(propagete_constraints, DelayConstraint(constr.delay - mydelay))
            else
                push!(propagete_constraints, constr)
            end
        elseif constr isa GoThroughConstraint
            if localnode(ibn, constr.node) === nothing || constr.node in bordernodes(ibn)
                push!(propagete_constraints, constr)
            end
        elseif constr isa BorderInitiateConstraint|| constr isa BorderTerminateConstraint
            continue
        else
            push!(propagete_constraints, constr)
        end

    end
    return propagete_constraints
end

"""$(TYPEDSIGNATURES)

Return a `PathIntent` implementing `path` in `ibn` if it is compliant with the constraints of the intent `parint`
In case it's not compliant, return `nothing`.
"""
function getcompliantintent(ibn::IBN, parint::I, ::Type{PathIntent}, path::Vector{Int}) where {I<:Intent}
    # deal with DelayConstraint
    dc = getfirst(x -> x isa DelayConstraint, parint.constraints)
    if dc !== nothing
        if delay(getdistance(ibn, path)) > dc.delay
             return nothing
         end
    end
    # deal with GoThroughConstraint
    for gtc in filter(x -> x isa GoThroughConstraint{Missing} && x.layer == signalUknown, parint.constraints)
        if localnode(ibn, gtc.node, subnetwork_view=false) ∉ path
             return nothing
        end
    end

    return PathIntent(path, filter(x -> !(x isa DelayConstraint || x isa GoThroughConstraint{Missing}), parint.constraints))
end

"""$(TYPEDSIGNATURES)

Return a `PathIntent` implementing `path` in `ibn` if it is compliant with the constraints of the intent `parint`
In case it's not compliant, return `nothing`.
"""
function getcompliantintent(ibn::IBN, parint::I, ::Type{LightpathIntent}, path::Vector{Int}, tmdl, lptype) where I<:Intent
    # deal with DelayConstraint
    dc = getfirst(x -> x isa DelayConstraint, parint.constraints)
    if dc !== nothing
        if delay(getdistance(ibn, path)) > dc.delay
             return nothing
         end
    end
#    # deal with GoThroughConstraint
#    for gtc in filter(x -> x isa GoThroughConstraint, getconstraints(parint))
#        if gtc.node[1] == getid(ibn)
#            if localnode(ibn, gtc.node, subnetwork_view=false) ∉ path
#                 return nothing
#            end
#        end
#    end

    if lptype == borderinitiatelightpath
        constrs = filter(x -> !any(isa.([x],  [DelayConstraint, GoThroughConstraint, BorderTerminateConstraint])), parint.constraints)
    elseif lptype == borderterminatelightpath
        constrs = filter(x -> !any(isa.([x],  [DelayConstraint, GoThroughConstraint, BorderInitiateConstraint])), parint.constraints)
    elseif lptype == border2borderlightpath
        constrs = filter(x -> !any(isa.([x],  [DelayConstraint, GoThroughConstraint])), parint.constraints)
    else
        constrs = filter(x -> !any(isa.([x],  [DelayConstraint, BorderInitiateConstraint, GoThroughConstraint, BorderTerminateConstraint])), parint.constraints)
    end
    return LightpathIntent(path, getrate(parint), tmdl, constrs)
end

"""$(TYPEDSIGNATURES)

Return a `SpectrumIntent` implementing `path`, data rate `drate` and spectrum allocation `sr` in `ibn`
if it is compliant with the constraints of the intent `parint`.
In case it's not compliant, return `nothing`.
"""
function getcompliantintent(ibn::IBN, parint::I, ::Type{SpectrumIntent}, path::Vector{Int}, drate::Float64, sr::UnitRange{Int}) where {I<:Intent}
    cc = getfirst(x -> x isa CapacityConstraint, parint.constraints)
    if cc !== nothing
        if cc.drate > drate
             return nothing
         end
    end
    return SpectrumIntent(path, drate, sr, filter(x -> !(x isa CapacityConstraint), parint.constraints))
end

"""$(TYPEDSIGNATURES)

Convert a `NodeRouterIntent` `intent` from `ibn` to constraint for the neighbor IBN.
The node concenring the `NodeRouterIntent` should be a border node for `ibn`.
Return a `Pair{NEIGHBOR_IBN_ID, GoThroughConstraint}`
"""
function intent2constraint(intent::R, ibn::IBN) where R<:NodeRouterPortIntent
    if getnode(intent) in bordernodes(ibn, subnetwork_view=false)
        cnode = ibn.ngr.vmap[getnode(intent)]
        contr = ibn.controllers[cnode[1]]
        if contr isa IBN
            ibnid = getid(contr)
        else
            error("Border node has not an IBN controller")
        end
        return Pair(ibnid, GoThroughConstraint((ibnid, cnode[2]), signalElectrical))
    end
end

"""$(TYPEDSIGNATURES)

Convert a `NodeSpectrumIntent` `intent` from `ibn` to constraint for the neighbor IBN.
The edge concerning the `NodeSpectrumIntent` should be a border edge for `ibn`.
Return a `Pair{NEIGHBOR_IBN_ID, GoThroughConstraint}`

"""
function intent2constraint(intent::R, ibn::IBN) where R<:NodeSpectrumIntent
    # assumes only one node is in another ibn 
    if getnode(intent) in bordernodes(ibn, subnetwork_view=false)
        cnode = ibn.ngr.vmap[getnode(intent)]
        contr = ibn.controllers[cnode[1]]
        if contr isa IBN
            ibnid = getid(contr)
        else
            error("Border node has not an IBN controller")
        end
        if src(intent.edge) in bordernodes(ibn, subnetwork_view=false)
            csrc = (ibnid, cnode[2])
            cdst = (getid(ibn), dst(intent.edge))
            cedg = NestedEdge(csrc, cdst)
            return Pair(ibnid, GoThroughConstraint((ibnid, cnode[2]), signalFiberOut, SpectrumRequirements(cedg, intent.slots, intent.bandwidth)))
        else
            cdst = (ibnid, cnode[2])
            csrc = (getid(ibn), src(intent.edge))
            cedg = NestedEdge(csrc, cdst)
            return Pair(ibnid, GoThroughConstraint((ibnid, cnode[2]), signalFiberIn, SpectrumRequirements(cedg, intent.slots, intent.bandwidth)))
        end
    end
end

"$(TYPEDSIGNATURES) Checks if resources to deploy a `PathIntent` `pathint` of in `ibn` are enough."
function isavailable(ibn::IBN, pathint::T) where {T<:PathIntent}
    path = pathint.path
    sdn1 = controllerofnode(ibn, path[1])
    sdn2 = controllerofnode(ibn, path[end])
    if sdn1 isa SDN && sdn2 isa SDN
        src = ibn.ngr.vmap[path[1]][2]
        dst = ibn.ngr.vmap[path[end]][2]
        isavailable_port(sdn1, src) && isavailable_port(sdn2, dst) || return false
    elseif sdn1 isa SDN
        # only consider intradomain knowledge. assume it's possible for the other domain
        src = ibn.ngr.vmap[path[1]][2]
        isavailable_port(sdn1, src) || return false
    elseif sdn2 isa SDN
        # only consider intradomain knowledge. assume it's possible for the other domain
        dst = ibn.ngr.vmap[path[end]][2]
        isavailable_port(sdn2, dst) || return false
    end
    for edg in edgeify(path)
        sdn11 = controllerofnode(ibn, edg.src)
        sdn22 = controllerofnode(ibn, edg.dst)
        ce = NestedGraphs.nestededge(ibn.ngr, edg)
        if sdn11 isa SDN
            doesoperate_link(sdn11, ce) || return false
        elseif sdn22 isa SDN
            doesoperate_link(sdn22, ce) || return false
        end
    end
    return true
end

# TODO Code duplication with PathIntent
"$(TYPEDSIGNATURES)"
function isavailable(ibn::IBN, lpint::T; iuuid=UUID(0x0)) where {T<:LightpathIntent}
    path = lpint.path
    sdn1 = controllerofnode(ibn, path[1])
    sdn2 = controllerofnode(ibn, path[end])
    if sdn1 isa SDN && sdn2 isa SDN
        src = ibn.ngr.vmap[path[1]][2]
        dst = ibn.ngr.vmap[path[end]][2]
        isavailable_port(sdn1, src) && isavailable_port(sdn2, dst) || return false
        isavailable_transmissionmodule(sdn1, src, lpint.transmodl) && isavailable_transmissionmodule(sdn2, dst, lpint.transmodl) || return false
    elseif sdn1 isa SDN
        # only consider intradomain knowledge. assume it's possible for the other domain
        src = ibn.ngr.vmap[path[1]][2]
        isavailable_port(sdn1, src) || return false
        isavailable_transmissionmodule(sdn1, src, lpint.transmodl) || return false
    elseif sdn2 isa SDN
        # only consider intradomain knowledge. assume it's possible for the other domain
        dst = ibn.ngr.vmap[path[end]][2]
        isavailable_port(sdn2, dst) || return false 
        isavailable_transmissionmodule(sdn2, dst, lpint.transmodl) || return false
    end
    for edg in edgeify(path)
        sdn11 = controllerofnode(ibn, edg.src)
        sdn22 = controllerofnode(ibn, edg.dst)
        ce = NestedGraphs.nestededge(ibn.ngr, edg)
        if sdn11 isa SDN
            doesoperate_link(sdn11, ce) || return false
        elseif sdn22 isa SDN
            doesoperate_link(sdn22, ce) || return false
        end
    end
    return true
end

"$(TYPEDSIGNATURES) Checks if resources to deploy a `SpectrumIntent` `speint` of in `ibn` are enough."
function isavailable(ibn::IBN, speint::T) where {T<:SpectrumIntent}
    success = false
    for e in edgeify(speint.lightpath)
        ce = NestedGraphs.nestededge(ibn.ngr, e)
        sdn1 = controllerofnode(ibn, e.src)
        sdn2 = controllerofnode(ibn, e.dst)
        if sdn1 isa SDN && sdn2 isa SDN
            return isavailable_slots(sdn1, ce, speint.spectrumalloc)
        elseif sdn1 isa SDN
            # only consider intradomain knowledge. assume it's possible for the other domain
            return isavailable_slots(sdn1, ce, speint.spectrumalloc)
        elseif sdn2 isa SDN
            # only consider intradomain knowledge. assume it's possible for the other domain
            return isavailable_slots(sdn2, ce, speint.spectrumalloc)
        end
    end
    return success
end

"$(TYPEDSIGNATURES) Checks if resources to deploy a `NodeRouterIntent` `nri` in `ibn` are enough."
function isavailable(ibn::IBN, nri::IntentDAGNode{R}) where R <:NodeRouterPortIntent
    intent, sdn, sdnode = sdnspace(ibn, nri)
    sdn isa IBN && error("No control of this resource")
    return isavailable_port(sdn, sdnode)
end

"$(TYPEDSIGNATURES) Checks if resources to deploy a `NodeSpectrumIntent` `nsi` of in `ibn` are enough."
function isavailable(ibn::IBN, nsi::IntentDAGNode{R}) where R <:NodeSpectrumIntent
    intent, ce, sdn1, sdn2 = intersdnspace(ibn, nsi)
    reserve_src = ibn.ngr.vmap[intent.node] == ce.src ? true : false
    sdn = sdn1 isa SDN ? sdn1 : sdn2
    if sdn isa SDN
        return isavailable_slots(sdn, ce, intent.slots, reserve_src)
    end
    return false
end


"$(TYPEDSIGNATURES)"
function isavailable(ibn::IBN, nri::IntentDAGNode{R}) where R<:NodeTransmoduleIntent
    intent, sdn, sdnode = sdnspace(ibn, nri)
    return isavailable_transmissionmodule(sdn, sdnode, intent.tm)
end

function isavailable(ibn::IBN, nrmi::IntentDAGNode{R}) where R <:NodeROADMIntent
    intent, sdn, sdnode = sdnspace(ibn, nrmi)
    return isavailable_roadmswitch(sdn, sdnode, intent.inedge, intent.outedge, intent.slots)
end

"$(TYPEDSIGNATURES)"
function free!(ibn::IBN, nri::IntentDAGNode{R}) where R <: NodeTransmoduleIntent
    intent, sdn, sdnode = sdnspace(ibn, nri)
    return free_transmissionmodule!(sdn, sdnode, intent.tm, (getid(ibn), getid(nri)))
end

function free!(ibn::IBN, nrmi::IntentDAGNode{R}) where R <:NodeROADMIntent
    intent, sdn, sdnode = sdnspace(ibn, nrmi)
    return free_roadmswitch!(sdn, sdnode, (getid(ibn), getid(nrmi)))
end

"""
$(TYPEDSIGNATURES) 

Get the SDN interface of `ibn` for the low-level intent `idn`.
Returns a tuple of `(Intent, SDN, SDN_NODE)`.
"""
function sdnspace(ibn::IBN, idn::IntentDAGNode) 
    intent = getintent(idn)
    sdn = controllerofnode(ibn, intent.node)
    sdnode = ibn.ngr.vmap[intent.node][2]
    return (intent, sdn, sdnode)
end
"""
$(TYPEDSIGNATURES) 

Get the SDN interface of `ibn` for the low-level intent `idn`.
`idn` concerns 2 SDNs, so both controllers are given.
Returns a tuple of `(Intent, NestedEdge, SDN1, SDN2)`.
"""
function intersdnspace(ibn::IBN, idn::IntentDAGNode) 
    intent = getintent(idn)
    ce = NestedGraphs.nestededge(ibn.ngr, intent.edge)
    sdn1 = controllerofnode(ibn, intent.edge.src)
    sdn2 = controllerofnode(ibn, intent.edge.dst)
    return (intent, ce, sdn1, sdn2)
end

"$(TYPEDSIGNATURES)"
function reserve!(ibn::IBN, nri::IntentDAGNode{R}) where R <: NodeTransmoduleIntent
    intent, sdn, sdnode = sdnspace(ibn, nri)
    return reserve_transmissionmodule!(sdn, sdnode, intent.tm, (getid(ibn), getid(nri)))
end

"$(TYPEDSIGNATURES) Reserve the `NodeRouterIntent` `nri` of `ibn`. Return `false` if impossible."
function reserve!(ibn::IBN, nri::IntentDAGNode{R}) where R <:NodeRouterPortIntent
    intent, sdn, sdnode = sdnspace(ibn, nri)
    return reserve_port!(sdn, sdnode, intent.rate, (getid(ibn), getid(nri)))
end

function reserve!(ibn::IBN, nrmi::IntentDAGNode{R}) where R <:NodeROADMIntent
    intent, sdn, sdnode = sdnspace(ibn, nrmi)
    return reserve_roadmswitch!(sdn, sdnode, intent.inedge, intent.outedge, intent.slots, (getid(ibn), getid(nrmi)))
end

"$(TYPEDSIGNATURES) Free the `NodeRouterIntent` `nri` of in `ibn`"
function free!(ibn::IBN, nri::IntentDAGNode{R}) where R <:NodeRouterPortIntent
    intent, sdn, sdnode = sdnspace(ibn, nri)
    return free_port!(sdn, sdnode, (getid(ibn), getid(nri)))
end


"$(TYPEDSIGNATURES) Check if the `NodeRouterIntent` `nri` of is satisfied in `ibn`."
function issatisfied(ibn::IBN, nri::IntentDAGNode{R}) where R <:NodeRouterPortIntent
    intent, sdn, sdnode = sdnspace(ibn, nri)
    return issatisfied_port(sdn, sdnode, intent.rate, (getid(ibn), getid(nri)))
end

"$(TYPEDSIGNATURES) Check if the `NodeRouterIntent` `nri` of is satisfied in `ibn`."
function issatisfied(ibn::IBN, nri::IntentDAGNode{R}) where R <:NodeTransmoduleIntent
    intent, sdn, sdnode = sdnspace(ibn, nri)
    return issatisfied_transmissionmodule(sdn, sdnode, intent.tm, (getid(ibn), getid(nri)))
end

function issatisfied(ibn::IBN, nrmi::IntentDAGNode{R}) where R <:NodeROADMIntent
    intent, sdn, sdnode = sdnspace(ibn, nrmi)
    return issatisfied_roadmswitch(sdn, sdnode, intent.inedge, intent.outedge, intent.slots, (getid(ibn), getid(nrmi)))
end

"$(TYPEDSIGNATURES) Reserve the `NodeSpectrumIntent` `nsi` of `ibn`. Return `false` if impossible."
function reserve!(ibn::IBN, nsi::IntentDAGNode{R}) where R <:NodeSpectrumIntent
    intent, ce, sdn1, sdn2 = intersdnspace(ibn, nsi)
    reserve_src = ibn.ngr.vmap[intent.node] == ce.src ? true : false
    sdn = sdn1 isa SDN ? sdn1 : sdn2
    if sdn isa SDN
        return reserve_slots!(sdn, ce, intent.slots, (getid(ibn), getid(nsi)), reserve_src)
    end
    return false
end


"$(TYPEDSIGNATURES) Free the `NodeSpectrumIntent` `nsi` of in `ibn`"
function free!(ibn::IBN, nsi::IntentDAGNode{R}) where R <:NodeSpectrumIntent
    intent, ce, sdn1, sdn2 = intersdnspace(ibn, nsi)
    reserve_src = ibn.ngr.vmap[intent.node] == ce.src ? true : false
    sdn = sdn1 isa SDN ? sdn1 : sdn2
    if sdn isa SDN
        return free_slots!(sdn, ce, intent.slots, (getid(ibn), getid(nsi)), reserve_src)
    end
    return false
end


"$(TYPEDSIGNATURES) Check if the `NodeSpectrumIntent` `nsi` is satisfied in `ibn`."
function issatisfied(ibn::IBN, nsi::IntentDAGNode{R}) where R <:NodeSpectrumIntent
    intent, ce, sdn1, sdn2 = intersdnspace(ibn, nsi)
    reserve_src = ibn.ngr.vmap[intent.node] == ce.src ? true : false
    sdn = sdn1 isa SDN ? sdn1 : sdn2
    if sdn isa SDN
        issatisfied_slots!(sdn, ce, intent.slots, (getid(ibn), getid(nsi)), reserve_src) && return true
    end
    return false
end

Base.@deprecate push_extendedchildren nothing
Base.@deprecate family nothing
Base.@deprecate dividefamily nothing

has_extendedchildren(intr::IntentDAG) = (getcompilation(intr) isa RemoteIntentCompilation) || AbstractTrees.has_children(intr)
function push_extendedchildren!(intents, ibn::IBN, intr::IntentDAG; ibnidfilter::Union{Nothing, Int}=nothing)
    if has_extendedchildren(intr)
        for (nextibn, chintentr) in extendedchildren(ibn,intr)
            if getid(nextibn) == ibnidfilter
                push!(intents, chintentr.data)
            end
            push_extendedchildren!(intents, nextibn, chintentr; ibnidfilter=ibnidfilter)
        end
    end
end
function push_extendedchildren!(ibnintd::Dict{Int, Vector{Intent}}, ibn::IBN, intr::IntentDAG)
    if has_extendedchildren(intr)
        for (nextibn, chintentr) in extendedchildren(ibn,intr)
            if !haskey(ibnintd, getid(nextibn))
                ibnintd[getid(nextibn)] = Vector{Intent}()
            end
            push!(ibnintd[getid(nextibn)], chintentr.data)
            push_extendedchildren!(ibnintd, nextibn, chintentr)
        end
    end
end
function push_extendedchildren!(intents, intr::IntentDAG)
    if has_extendedchildren(intr)
        for chintentr in extendedchildren(intr)
            push!(intents, chintentr.data)
            push_extendedchildren!(intents, chintentr)
        end
    end
end
function recursive_children!(intents, intr::IntentDAG)
    if AbstractTrees.has_children(intr)
        for chintentr in children(intr)
            push!(intents, chintentr.data)
            recursive_children!(intents, chintentr)
        end
    end
end

function family(ibn::IBN, intidx::Int; intraibn::Bool=false, ibnidfilter::Union{Nothing, Int}=nothing)
    intents = Vector{Intent}()
    if intraibn
        if ibnidfilter === nothing || ibnidfilter == getid(ibn)
            return intents
        else
            push!(intents, getintent(ibn,intidx).data)
            recursive_children!(intents, getintent(ibn,intidx))
        end
    else
        if ibnidfilter === nothing || ibnidfilter == getid(ibn)
            push!(intents, getintent(ibn,intidx).data)
        end
        push_extendedchildren!(intents, ibn, getintent(ibn,intidx); ibnidfilter=ibnidfilter)
    end
    return intents
end

function dividefamily(ibn::IBN, intidx::Int)
    ibnintd = Dict{Int, Vector{Intent}}()
    ibnintd[getid(ibn)] = Vector{Intent}([getintent(ibn,intidx).data])
    push_extendedchildren!(ibnintd, ibn, getintent(ibn,intidx))
    return ibnintd
end
