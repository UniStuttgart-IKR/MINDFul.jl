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
function getidagnextuuidcounter(intentdag::IntentDAG)
    return UUID(getidagcounter(getidaginfo(intentdag)) + 1)
end

"""
$(TYPEDSIGNATURES)
"""
function increaseidagcounter!(intentdag::IntentDAG)
    idaginfo = getidaginfo(intentdag)
    return idaginfo.intentcounter += 1
end

"""
$(TYPEDSIGNATURES)
"""
function pushstatetoidagnode!(intentlogstate::IntentLogState, time::DateTime, intentstate::IntentState.T)
    return push!(intentlogstate, (time, intentstate))
end

"""
$(TYPEDSIGNATURES)
Uses now() time as default
"""
function pushstatetoidagnode!(intentlogstate::IntentLogState, intentstate::IntentState.T)
    return push!(intentlogstate, (now(), intentstate))
end

"""
$(TYPEDSIGNATURES)
"""
function pushstatetoidagnode!(idagnode::IntentDAGNode, time::DateTime, intentstate::IntentState.T)
    return pushstatetoidagnode!(getlogstate(idagnode), time, intentstate)
end

"""
$(TYPEDSIGNATURES)

Get the vertex index of the intent DAG node with id `dagnodeid`.
Errors if UUID doesn't exist.
"""
function getidagnodeidx(intentdag::IntentDAG, dagnodeid::UUID)
    return something(findfirst(==(dagnodeid), getidagnodeid.(getidagnodes(intentdag))))
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

Return the `IntentDAGNode`
"""
function addidagnode!(intentdag::IntentDAG, intent::AbstractIntent; parentid::Union{Nothing, UUID} = nothing, intentissuer = MachineGenerated())
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

    return idagnode
end

"""
$(TYPEDSIGNATURES)

Return the `UUID`
"""
function addidagnode!(intentdag::IntentDAG, idagnode::IntentDAGNode; parentid::Union{Nothing, UUID} = nothing, intentissuer = MachineGenerated())
    intentcounter = increaseidagcounter!(intentdag)

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
    deleteat!(getidagnodes(intentdag), vertexidx)
    return true
end

function updateidagstates!(idag::IntentDAG, idagnodeid::UUID)
    idagnode = getidagnode(idag, idagnodeid)
    return updateidagnodestates!(idag, idagnode)
end

"""
$(TYPEDSIGNATURES)
Return value is true if state is changed.
"""
function updateidagnodestates!(idag::IntentDAG, idagnode::IntentDAGNode)
    idagnodeid = getidagnodeid(idagnode)
    idagnodechildren = getidagnodechildren(idag, idagnodeid)
    childrenstates = getidagnodestate.(idagnodechildren)
    currentstate = getidagnodestate(idagnode)
    changedstate = false
    if length(childrenstates) == 0
        if currentstate != IntentState.Uncompiled
            changedstate = true
            pushstatetoidagnode!(idagnode, now(), IntentState.Uncompiled)
        end        
    elseif all(==(IntentState.Compiled), childrenstates)
        if currentstate != IntentState.Compiled
            changedstate = true
            pushstatetoidagnode!(idagnode, now(), IntentState.Compiled)
        end
    elseif any(==(IntentState.Compiled), childrenstates)
        if currentstate != IntentState.Compiling
            changedstate = true
            pushstatetoidagnode!(idagnode, now(), IntentState.Compiling)
        end
        return
    elseif all(==(IntentState.Installed), childrenstates)
        if currentstate != IntentState.Installed
            changedstate = true
            pushstatetoidagnode!(idagnode, now(), IntentState.Installed)
        end
    elseif any(==(IntentState.Installed), childrenstates)
        if currentstate != IntentState.Installing
            changedstate = true
            pushstatetoidagnode!(idagnode, now(), IntentState.Installing)
        end
    end
    if changedstate
        foreach(getidagnodeparents(idag, idagnodeid)) do idagnodeparent
            updateidagnodestates!(idag, idagnodeparent)
        end
    end
    return changedstate
end

"""
$(TYPEDSIGNATURES) 

Get all descendants of DAG `dag` starting from node `idagnodeid`
Set `exclusive=true`  to get nodes that have `idagnodeid` as the only ancestor
"""
function getidagnodedescendants(idag::IntentDAG, idagnodeid::UUID; exclusive=false)
    idns = Vector{IntentDAGNode}()
    for chidn in getidagnodechildren(idag, idagnodeid)
        _descendants_recu!(idns, idag, getidagnodeid(chidn); exclusive)
    end
    return idns
end

function _descendants_recu!(vidns::Vector{IntentDAGNode}, idag::IntentDAG, idagnodeid::UUID; exclusive)
    exclusive && length(getidagnodeparents(idag, idagnodeid)) > 1 && return
    push!(vidns, getidagnode(idag, idagnodeid))
    for chidn in getidagnodechildren(idag, idagnodeid)
        _descendants_recu!(vidns, idag, getidagnodeid(chidn); exclusive)
    end
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodechildren(idag::IntentDAG, idagnode::IntentDAGNode)
    idagnodeid = getidagnodeid(idagnode)
    return getidagnodechildren(idag, idagnodeid)
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
function hasidagnodechildren(idag::IntentDAG, idagnode::IntentDAGNode)
    idagnodeid = getidagnodeid(idagnode)
    return hasidagnodechildren(idag, idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function hasidagnodechildren(idag::IntentDAG, idagnodeid::UUID)
    vertexidx = getidagnodeidx(idag, idagnodeid)
    childrenidxs = Graphs.outneighbors(idag, vertexidx)
    return !isempty(childrenidxs)
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
function getidagnodeparents(idag::IntentDAG, idagnode::IntentDAGNode)
    idagnodeid = getidagnodeid(idagnode)
    return getidagnodeparents(idag, idagnodeid)
end

"""
$(TYPEDSIGNATURES)
Get all the Low Level Intents that exist on the DAG
"""
function getidagnodellis(idag::IntentDAG)
    idagnodes = getidagnodes(idag)
    return filter(x -> getintent(x) isa LowLevelIntent, idagnodes)
end

"""
$(TYPEDSIGNATURES)
Get all the Low Level Intents that are leafs of `idagnodeid`
Set `exclusive=true` to get nodes that have `idn` as the only ancestor
"""
function getidagnodellis(idag::IntentDAG, idagnodeid::UUID; exclusive=false)
    idagnodes = getidagnodeleafs(idag, idagnodeid; exclusive)
    return filter(x -> getintent(x) isa LowLevelIntent, idagnodes)
end

"""
$(TYPEDSIGNATURES) 

Get the leafs of DAG `dag` starting from node `idn`.
Set `exclusive=true` to get nodes that have `idn` as the only ancestor
"""
function getidagnodeleafs(idag::IntentDAG, idagnodeid::UUID; exclusive=false)
    idns = IntentDAGNode[]
    for chidn in getidagnodechildren(idag, idagnodeid)
        _leafs_recu!(idns, idag, chidn; exclusive)
    end
    return idns
end

function _leafs_recu!(vidns::Vector{IntentDAGNode}, dag::IntentDAG, idn::IntentDAGNode; exclusive)
    exclusive && length(getidagnodeparents(dag, idn)) > 1 && return
    if hasidagnodechildren(dag, idn)
        for chidn in getidagnodechildren(dag, idn)
            _leafs_recu!(vidns, dag, chidn; exclusive)
        end
    else
        push!(vidns, idn)
    end
end

