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
@recvtime function pushstatetoidagnode!(intentlogstate::IntentLogState, intentstate::IntentState.T)
    return push!(intentlogstate, (@logtime, intentstate))
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function pushstatetoidagnode!(idagnode::IntentDAGNode, intentstate::IntentState.T)
    return pushstatetoidagnode!(getlogstate(idagnode), intentstate; @passtime)
end

"""
$(TYPEDSIGNATURES)

Get the vertex index of the intent DAG node with id `dagnodeid`.
Errors if UUID doesn't exist.
It's slow: maybe keep a dict/table ?
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
@recvtime function addidagnode!(ibnf::IBNFramework, intent::AbstractIntent; parentid::Union{Nothing, UUID} = nothing, intentissuer = MachineGenerated())
    intentdag = getidag(ibnf)
    intentcounter = increaseidagcounter!(intentdag)
    if intent isa LowLevelIntent
        idagnode = IntentDAGNode(intent, UUID(intentcounter), intentissuer, IntentLogState(IntentState.Compiled, @logtime))
    else
        idagnode = IntentDAGNode(intent, UUID(intentcounter), intentissuer, IntentLogState(IntentState.Uncompiled, @logtime))
    end

    add_vertex!(intentdag)
    newidagnodeidx = nv(intentdag)
    push!(getidagnodes(intentdag), idagnode)

    if !isnothing(parentid)
        parentidx = getidagnodeidx(intentdag, parentid)
        add_edge!(intentdag, parentidx, newidagnodeidx)
        updateidagstates!(ibnf, parentid)
    end

    return idagnode
end

"""
$(TYPEDSIGNATURES)

Return the `UUID`
"""
function addidagnode!(ibnf::IBNFramework, idagnode::IntentDAGNode; parentid::Union{Nothing, UUID} = nothing, intentissuer = MachineGenerated())
    intentdag = getidag(ibnf)
    intentcounter = increaseidagcounter!(intentdag)

    add_vertex!(intentdag)
    newidagnodeidx = nv(intentdag)
    push!(getidagnodes(intentdag), idagnode)

    if !isnothing(parentid)
        parentidx = getidagnodeidx(intentdag, parentid)
        add_edge!(intentdag, parentidx, newidagnodeidx)
        updateidagstates!(ibnf, parentid)
    end

    return getidagnodeid(idagnode)
end

"""
$(TYPEDSIGNATURES)
"""
function addidagedge!(ibnf::IBNFramework, fromnode::UUID, tonode::UUID)
    idag = getidag(ibnf)
    fromidx = getidagnodeidx(idag, fromnode)
    toidx = getidagnodeidx(idag, tonode)
    add_edge!(idag, fromidx, toidx)
    updateidagstates!(ibnf, fromnode)
    return true
end

function removeidagnode!(intentdag::IntentDAG, idagnodeid::UUID)
    vertexidx = getidagnodeidx(intentdag, idagnodeid)
    rem_vertex!(intentdag, vertexidx)
    # Graphs.jl removing index swapps |V| with `vertexidx` and deletes last one.
    idagnodes = getidagnodes(intentdag)
    if length(idagnodes) == vertexidx
        pop!(idagnodes)
    else
        idagnodes[vertexidx] = pop!(idagnodes)
    end
    return ReturnCodes.SUCCESS
end

@recvtime function updateidagstates!(ibnf::IBNFramework, idagnodeid::UUID, newstate::Union{Nothing, IntentState.T} = nothing)
    idag = getidag(ibnf)
    idagnode = getidagnode(idag, idagnodeid)
    return updateidagnodestates!(ibnf, idagnode, newstate; @passtime)
end

"""
$(TYPEDSIGNATURES)
Return value is true if state is changed.
"""
@recvtime function updateidagnodestates!(ibnf::IBNFramework, idagnode::IntentDAGNode, newstate::Union{Nothing, IntentState.T} = nothing)
    idag = getidag(ibnf)
    idagnodeid = getidagnodeid(idagnode)
    idagnodechildren = getidagnodechildren(idag, idagnodeid)
    childrenstates = getidagnodestate.(idagnodechildren)
    currentstate = getidagnodestate(idagnode)
    changedstate = false
    if length(childrenstates) == 0
        if !isnothing(newstate) && newstate != currentstate
            changedstate = true
            pushstatetoidagnode!(idagnode, newstate; @passtime)
            # println("$(getidagnodeid(idagnode)) correct state update")
        elseif isnothing(newstate) && currentstate != IntentState.Uncompiled
            changedstate = true
            pushstatetoidagnode!(idagnode, IntentState.Uncompiled; @passtime)
        end        
    elseif all(==(IntentState.Compiled), childrenstates)
        if currentstate != IntentState.Compiled
            changedstate = true
            removefrominstalledlightpaths!(ibnf, idagnode) # if intentid found, remove
            pushstatetoidagnode!(idagnode, IntentState.Compiled; @passtime)
        end
    elseif all(==(IntentState.Uncompiled), childrenstates)
        if currentstate != IntentState.Uncompiled
            changedstate = true
            pushstatetoidagnode!(idagnode, IntentState.Uncompiled; @passtime)
        end
    elseif all(==(IntentState.Installed), childrenstates)
        # TODO if in Pending state can change ony
        if currentstate != IntentState.Installed
            changedstate = true
            if getintent(idagnode) isa LightpathIntent
                addtoinstalledlightpaths!(ibnf, idagnode) # first check if intent implementation is a lightpath
            end
            pushstatetoidagnode!(idagnode, IntentState.Installed; @passtime)
        end
    elseif any(==(IntentState.Failed), childrenstates)
        if currentstate != IntentState.Failed
            changedstate = true
            pushstatetoidagnode!(idagnode, IntentState.Failed; @passtime)
        end
    elseif any(==(IntentState.Pending), childrenstates)
        if currentstate != IntentState.Pending
            changedstate = true
            pushstatetoidagnode!(idagnode, IntentState.Pending; @passtime)
        end
    else
        if currentstate != IntentState.Pending
            changedstate = true
            pushstatetoidagnode!(idagnode, IntentState.Pending; @passtime)
        end
    end
    if changedstate
        foreach(getidagnodeparents(idag, idagnodeid)) do idagnodeparent
            updateidagnodestates!(ibnf, idagnodeparent; @passtime)
        end
        if getintent(idagnode) isa RemoteIntent && !getisinitiator(getintent(idagnode))
            # notify initiator domain
            ibnfhandler = getibnfhandler(ibnf, getibnfid(getintent(idagnode)))
            requestremoteintentstateupdate!(ibnf, ibnfhandler, getidagnodeid(getintent(idagnode)), getidagnodestate(idagnode); @passtime)
        end
    end
    return changedstate
end

"""
$(TYPEDSIGNATURES) 

Get all descendants of DAG `dag` starting from node `idagnodeid`
Set `exclusive=true`  to get nodes that have `idagnodeid` as the only ancestor
"""
function getidagnodedescendants(idag::IntentDAG, idagnodeid::UUID; exclusive=false, includeroot=false)
    idns = Vector{IntentDAGNode}()
    includeroot && push!(idns, getidagnode(idag, idagnodeid))
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

Get all descendants of DAG `dag` starting from node `idagnodeid`. Return as node indices of the graph.
Set `exclusive=true`  to get nodes that have `idagnodeid` as the only ancestor
"""
function getidagnodeidxsdescendants(idag::IntentDAG, idagnodeid::UUID; exclusive=false, includeroot=false)
    idxs = Vector{Int}()
    vertexidx = getidagnodeidx(idag, idagnodeid)
    includeroot && push!(idxs, vertexidx)
    for chididx in Graphs.outneighbors(idag, vertexidx)
        _descendants_recu_idxs!(idxs, idag, chididx; exclusive)
    end
    return idxs
end

function _descendants_recu_idxs!(vidxs::Vector{Int}, idag::IntentDAG, idagnodeidx::Int; exclusive)
    exclusive && length(Graphs.inneighbors(idag, idagnodeidx)) > 1 && return
    push!(vidxs, idagnodeidx)
    for chididx in Graphs.outneighbors(idag, idagnodeidx)
        _descendants_recu_idxs!(vidxs, idag, chididx; exclusive)
    end
end

"""
$(TYPEDSIGNATURES) 

Get all connected nodes of DAG `dag` starting from node `idagnodeid`. Return as node indices of the graph.
"""
function getidagnodeidxsconnected(idag::IntentDAG, idagnodeid::UUID;)
    idxs = Vector{Int}()
    vertexidx = getidagnodeidx(idag, idagnodeid)
    for chididx in Graphs.outneighbors(idag, vertexidx)
        _descendants_recu_connected_idxs!(idxs, idag, chididx)
    end
    for chididx in Graphs.inneighbors(idag, vertexidx)
        _descendants_recu_connected_idxs!(idxs, idag, chididx)
    end
    return idxs
end

function _descendants_recu_connected_idxs!(vidxs::Vector{Int}, idag::IntentDAG, idagnodeidx::Int)
    idagnodeidx ∈ vidxs && return
    push!(vidxs, idagnodeidx)
    for chididx in Graphs.outneighbors(idag, idagnodeidx)
        _descendants_recu_connected_idxs!(vidxs, idag, chididx)
    end
    for chididx in Graphs.inneighbors(idag, idagnodeidx)
        _descendants_recu_connected_idxs!(vidxs, idag, chididx)
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
function hasidagnodeparents(idag::IntentDAG, idagnode::IntentDAGNode)
    idagnodeid = getidagnodeid(idagnode)
    return hasidagnodeparents(idag, idagnodeid)
end

"""
$(TYPEDSIGNATURES)
"""
function hasidagnodeparents(idag::IntentDAG, idagnodeid::UUID)
    vertexidx = getidagnodeidx(idag, idagnodeid)
    parentidxs = Graphs.inneighbors(idag, vertexidx)
    return !isempty(parentidxs)
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

"""
$(TYPEDSIGNATURES) 

Get the roots of DAG `dag` starting from node `idn`.
"""
function getidagnoderoots(idag::IntentDAG, idagnodeid::UUID)
    idns = IntentDAGNode[]
    for paridn in getidagnodeparents(idag, idagnodeid)
        _parents_recu!(idns, idag, paridn)
    end
    isempty(idns) && push!(idns, getidagnode(idag, idagnodeid))
    return idns
end

function _parents_recu!(vidns::Vector{IntentDAGNode}, dag::IntentDAG, idn::IntentDAGNode)
    if hasidagnodeparents(dag, idn)
        for paridn in getidagnodeparents(dag, idn)
            _parents_recu!(vidns, dag, paridn)
        end
    else
        push!(vidns, idn)
    end
end

