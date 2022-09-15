#=
# This is supposed to be a simplified version of an Intent Language System
=#
newintent(intent::ConnectivityIntent) = ConnectivityIntent(getsrc(intent), getdst(intent), getconstraints(intent), 
                                                           getconditions(intent))
getintentidx(idag::IntentDAG) = idag.graph_data.idx
getintentdagnodes(dag::IntentDAG) = Base.getindex.(values(dag.vertex_properties), 2)
getnode(i::Intent) = i.node

convert2global(ibn::IBN, lli::NodeSpectrumIntent{Int, E}) where 
    E<:Edge = NodeSpectrumIntent(globalnode(ibn, lli.node), globaledge(ibn, lli.edge), lli.slots, lli.bandwidth)

convert2global(ibn::IBN, lli::NodeRouterIntent{Int}) = 
    NodeRouterIntent(globalnode(ibn, lli.node), lli.ports)

"Return global intent index"
function intentidx(ibn::IBN, dag::IntentDAG, idn::R=missing) where R <: Union{IntentDAGNode, Missing}
    ibnid = getid(ibn)
    dagidx = getid(dag)
    if idn === missing
        idnuid = getid(getroot(idn))
    else
        idnuid = getid(idn)
    end
    return (ibnid, dagidx, idnuid)
end

function getfirstdagnode_fromintent(dag::IntentDAG, intent::Intent)
    for idn in getintentdagnodes(dag)
        if getintent(idn) == intent
            return idn
        end
    end
end

#tdl
function getsymmetricintent(nsi::R) where R<:NodeSpectrumIntent
    if nsi.node == src(nsi.edge)
        nod = dst(nsi.edge)
    else
        nod = src(nsi.edge)
    end
    return NodeSpectrumIntent(nod, nsi.edge, nsi.slots, nsi.bandwidth)
end

function adjustNpropagate_constraints!(ibn::IBN, dag::IntentDAG)
    idn = getroot(dag)
    constraints = getconstraints(getintent(idn))
    propagete_constraints = Vector{IntentConstraint}()
    for (i,constr) in enumerate(constraints)
        if constr isa DelayConstraint
            pintdn = getfirst(x -> getintent(x) isa PathIntent, descendants(dag, idn))
            if pintdn !== nothing
                pintent = getintent(pintdn)
                #readjust intent
                mydelay = delay(distance(ibn, pintent.path))
                push!(propagete_constraints, DelayConstraint(constr.delay - mydelay))
            else
                push!(propagete_constraints, constr)
            end
        elseif constr isa GoThroughConstraint
            if localnode(ibn, constr.node) == nothing
                push!(propagete_constraints, constr)
            end
        else
            push!(propagete_constraints, constr)
        end

    end
    return propagete_constraints
end

function getcompliantintent(ibn::IBN, parint::I, ::Type{PathIntent}, path::Vector{Int}) where {I<:Intent}
    # deal with DelayConstraint
    dc = getfirst(x -> x isa DelayConstraint, parint.constraints)
    if dc !== nothing
        if delay(distance(ibn, path)) > dc.delay
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

function getcompliantintent(ibn::IBN, parint::I, ::Type{SpectrumIntent}, path::Vector{Int}, drate::Float64, sr::UnitRange{Int}) where {I<:Intent}
    cc = getfirst(x -> x isa CapacityConstraint, parint.constraints)
    if cc !== nothing
        if cc.drate > drate
             return nothing
         end
    end
    return SpectrumIntent(path, drate, sr, filter(x -> !(x isa CapacityConstraint), parint.constraints))
end

"""
Convert `intent` from `ibn1` to constraint for the neighbor IBN
returns a Pair{neighbor ibn id, intent constraint}
"""
function intent2constraint(intent::R, ibn::IBN) where R<:NodeRouterIntent
    if getnode(intent) in transnodes(ibn, subnetwork_view=false)
        cnode = ibn.ngr.vmap[getnode(intent)]
        contr = ibn.controllers[cnode[1]]
        if contr isa IBN
            ibnid = getid(contr)
        else
            error("Transode has not an IBN controller")
        end
        return Pair(ibnid, GoThroughConstraint((ibnid, cnode[2]), signalElectrical))
    end
end

"assumes only one node is in another ibn"
function intent2constraint(intent::R, ibn::IBN) where R<:NodeSpectrumIntent
    if getnode(intent) in transnodes(ibn, subnetwork_view=false)
        cnode = ibn.ngr.vmap[getnode(intent)]
        contr = ibn.controllers[cnode[1]]
        if contr isa IBN
            ibnid = getid(contr)
        else
            error("Transode has not an IBN controller")
        end
        if src(intent.edge) in transnodes(ibn, subnetwork_view=false)
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


"Path needs to be completely inside the IBN"
function isavailable(ibn::IBN, dag::IntentDAG, pathint::T) where {T<:PathIntent}
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
            doesoperate = doesoperate_link(sdn22, ce) || return false
        end
    end
    return true
end

function isavailable(ibn::IBN, dag::IntentDAG, speint::T) where {T<:SpectrumIntent}
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

function sdnspace(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode) 
    intent = getintent(idn)
    sdn = controllerofnode(ibn, intent.node)
    sdnode = ibn.ngr.vmap[intent.node][2]
    return (intent, sdn, sdnode)
end
function intersdnspace(ibn::IBN, dag::IntentDAG, idn::IntentDAGNode) 
    intent = getintent(idn)
    ce = NestedGraphs.nestededge(ibn.ngr, intent.edge)
    sdn1 = controllerofnode(ibn, intent.edge.src)
    sdn2 = controllerofnode(ibn, intent.edge.dst)
    return (intent, ce, sdn1, sdn2)
end

function isavailable(ibn::IBN, dag::IntentDAG, nri::IntentDAGNode{R}) where R <:NodeRouterIntent
    intent, sdn, sdnode = sdnspace(ibn, dag, nri)
    return isavailable_port(sdn, sdnode)
end

function reserve(ibn::IBN, dag::IntentDAG, nri::IntentDAGNode{R}) where R <:NodeRouterIntent
    intent, sdn, sdnode = sdnspace(ibn, dag, nri)
    return reserve_port!(sdn, sdnode, (getid(ibn), getintentidx(dag), getid(nri)))
end
function free!(ibn::IBN, dag::IntentDAG, nri::IntentDAGNode{R}) where R <:NodeRouterIntent
    intent, sdn, sdnode = sdnspace(ibn, dag, nri)
    return free_port!(sdn, sdnode, (getid(ibn), getintentidx(dag), getid(nri)))
end

function issatisfied(ibn::IBN, dag::IntentDAG, nri::IntentDAGNode{R}) where R <:NodeRouterIntent
    intent, sdn, sdnode = sdnspace(ibn, dag, nri)
    return issatisfied_port(sdn, sdnode, (getid(ibn), getintentidx(dag), getid(nri)))
end

function isavailable(ibn::IBN, dag::IntentDAG, nsi::IntentDAGNode{R}) where R <:NodeSpectrumIntent
    intent, ce, sdn1, sdn2 = intersdnspace(ibn, dag, nsi)
    reserve_src = ibn.ngr.vmap[intent.node] == ce.src ? true : false
    sdn = sdn1 isa SDN ? sdn1 : sdn2
    if sdn isa SDN
        return isavailable_slots(sdn, ce, intent.slots, reserve_src)
    end
    return false
end

function reserve(ibn::IBN, dag::IntentDAG, nsi::IntentDAGNode{R}) where R <:NodeSpectrumIntent
    intent, ce, sdn1, sdn2 = intersdnspace(ibn, dag, nsi)
    reserve_src = ibn.ngr.vmap[intent.node] == ce.src ? true : false
    sdn = sdn1 isa SDN ? sdn1 : sdn2
    if sdn isa SDN
        return reserve_slots!(sdn, ce, intent.slots, (getid(ibn), getintentidx(dag), getid(nsi)), reserve_src)
    end
    return false
end
function free!(ibn::IBN, dag::IntentDAG, nsi::IntentDAGNode{R}) where R <:NodeSpectrumIntent
    intent, ce, sdn1, sdn2 = intersdnspace(ibn, dag, nsi)
    reserve_src = ibn.ngr.vmap[intent.node] == ce.src ? true : false
    sdn = sdn1 isa SDN ? sdn1 : sdn2
    if sdn isa SDN
        return free_slots!(sdn, ce, intent.slots, (getid(ibn), getintentidx(dag), getid(nsi)), reserve_src)
    end
    return false
end

function issatisfied(ibn::IBN, dag::IntentDAG, nsi::IntentDAGNode{R}) where R <:NodeSpectrumIntent
    intent, ce, sdn1, sdn2 = intersdnspace(ibn, dag, nsi)
    reserve_src = ibn.ngr.vmap[intent.node] == ce.src ? true : false
    sdn = sdn1 isa SDN ? sdn1 : sdn2
    if sdn isa SDN
        issatisfied_slots!(sdn, ce, intent.slots, (getid(ibn), getintentidx(dag), getid(nsi)), reserve_src) && return true
    end
    return false
end

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
