# IntentDAG customizations

"""
$(TYPEDSIGNATURES)
"""
function getidaginfo(intentdag::IntentDAG)
    return AG.graph_attr(intentdag)
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodes(intentdag::IntentDAG)
    return AG.vertex_attr(intentdag)
end

"""
$(TYPEDSIGNATURES)
"""
function getidagcounter(intentdag::IntentDAG)
    return getidagcounter(getidaginfo(intentdag))
end

"""
$(TYPEDSIGNATURES)
"""
function increaseidagcounter!(intentdag::IntentDAG)
    idaginfo = getidaginfo(intentdag)
    idaginfo.intentcounter += 1
end

"""
$(TYPEDSIGNATURES)
"""
function pushstatetoidagnode!(intentlogstate::IntentLogState, time::DateTime, intentstate::IntentState.T)
    push!(intentlogstate.logstate, (time, intentstate))
end

"""
$(TYPEDSIGNATURES)
"""
function pushstatetoidagnode!(idagnode::IntentDAGNode, time::DateTime, intentstate::IntentState.T)
    pushstatetoidagnode!(getlogstate(idagnode), time, intentstate)
end

"""
$(TYPEDSIGNATURES)

Get the vertex index of the intent DAG node with id `dagnodeid`
"""
function getidagnodeidx(intentdag::IntentDAG, dagnodeid::UUID)
    return findfirst(==(dagnodeid), getidagnodeid.(getidagnodes(intentdag)))
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnode(intentdag::IntentDAG, dagnodeid::UUID)
    return getidagnodes(intentdag)[getidagnodeidx(intentdag, dagnodeid)]
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodestate(intentdag::IntentDAG, dagnodeid::UUID)
    return getidagnodestate(getidagnode(intentdag, dagnodeid))
end

"""
$(TYPEDSIGNATURES)
"""
function addidagnode!(intentdag::IntentDAG, intent::AbstractIntent; parentid::Union{Nothing, UUID}=nothing, intentissuer=MachineGenerated())
    intentcounter = increaseidagcounter!(intentdag)
    if intent isa LowLevelIntent
        idagnode = IntentDAGNode(intent, UUID(intentcounter), intentissuer, IntentLogState(IntentState.Compiled))
    else
        idagnode = IntentDAGNode(intent, UUID(intentcounter), intentissuer, IntentLogState(IntentState.Uncompiled))
    end

    add_vertex!(intentdag)
    newidagnodeidx = nv(intentdag)
    push!(getidagnodes(intentdag), idagnode)
    
    if !isnothing(parentid)
        parentidx = getidagnodeidx(intentdag, parentid)
        add_edge!(intentdag, parentidx, newidagnodeidx)
    end

    return getidagnodeid(idagnode)
end

function removeidagnode!(intentdag::IntentDAG, idagnodeid::UUID)
    vertexidx = getidagnodeidx(intentdag, idagnodeid)
    rem_vertex!(intentdag, vertexidx)
    return true
end

function updateidagstates!(idag::IntentDAG, idagnodeid::UUID)
    idagnode = getidagnode(idag, idagnodeid)
    updateidagstates!(idag, idagnode)
end

function updateidagstates!(idag::IntentDAG, idagnode::IntentDAGNode)
    idagnodeid = getidagnodeid(idagnode)
    idagnodechildren = getidagnodechildren(idag, idagnodeid)
    childrenstates = getidagnodestate.(idagnodechildren)
    currentstate = getidagnodestate(idagnode)
    changedstate = false
    if all(==(IntentState.Compiled), childrenstates)
        if currentstate != IntentState.Compiled
            changedstate = true
            pushstatetoidagnode!(idagnode, now(), IntentState.Compiled)
        end
    elseif any(==(IntentState.Compiled, childrenstates))
        if currentstate != IntentState.Compiling
            changedstate = true
            pushstatetoidagnode!(idagnode, now(), IntentState.Compiling)
        end
        return 
    elseif all(==(IntentState.Installed, childrenstates))
        if currentstate != IntentState.Installed
            changedstate = true
            pushstatetoidagnode!(idagnode, now(), IntentState.Installed)
        end
    elseif any(==(IntentState.Installed, childrenstates))
        if currentstate != IntentState.Installing
            changedstate = true
            pushstatetoidagnode!(idagnode, now(), IntentState.Installing)
        end
    end
    if changedstate
        foreach(getidagnodeparents(idag, idagnodeid)) do idagnodeparent
             updateidagstates!(idag, idagnodeparent)
        end
    end
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodechildren(idag::IntentDAG, idagnodeid::UUID)
    vertexidx = getidagnodeidx(idag, idagnodeid)   
    childrenidxs = Graphs.outneighbors(idag, vertexidx)
    return getidagnodes(idag)[childrenidxs]
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodeparents(idag::IntentDAG, idagnodeid::UUID)
    vertexidx = getidagnodeidx(idag, idagnodeid)   
    childrenidxs = Graphs.inneighbors(idag, vertexidx)
    return getidagnodes(idag)[childrenidxs]
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodellis(idag::IntentDAG)
    idagnodes = getidagnodes(idag)
    return filter(x -> getintent(x) isa LowLevelIntent, idagnodes)
end
