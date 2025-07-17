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
@recvtime function addidagnode!(ibnf::IBNFramework, intent::AbstractIntent; parentids::Vector{UUID} = UUID[], childids::Vector{UUID} = UUID[], intentissuer = MachineGenerated())
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

    for parentid in parentids
        parentidx = getidagnodeidx(intentdag, parentid)
        add_edge!(intentdag, parentidx, newidagnodeidx)
        updateidagstates!(ibnf, parentid; @passtime)
    end

    for childid in childids
        childidx = getidagnodeidx(intentdag, childid)
        add_edge!(intentdag, newidagnodeidx, childidx)
        updateidagstates!(ibnf, getidagnodeid(idagnode); @passtime)
    end

    return idagnode
end

"""
$(TYPEDSIGNATURES)

Return the `UUID`
"""
function addidagnode!(ibnf::IBNFramework, idagnode::IntentDAGNode; parentids::Vector{UUID} = UUID[], childids::Vector{UUID} = UUID[], intentissuer = MachineGenerated())
    intentdag = getidag(ibnf)
    intentcounter = increaseidagcounter!(intentdag)

    add_vertex!(intentdag)
    newidagnodeidx = nv(intentdag)
    push!(getidagnodes(intentdag), idagnode)

    for parentid in parentids
        parentidx = getidagnodeidx(intentdag, parentid)
        add_edge!(intentdag, parentidx, newidagnodeidx)
        updateidagstates!(ibnf, parentid)
    end

    for childid in childids
        childidx = getidagnodeidx(intentdag, childid)
        add_edge!(intentdag, newidagnodeidx, childidx)
        updateidagstates!(ibnf, getidagnodeid(idagnode))
    end

    return getidagnodeid(idagnode)
end

"""
$(TYPEDSIGNATURES)
"""
@recvtime function addidagedge!(ibnf::IBNFramework, fromnode::UUID, tonode::UUID)
    idag = getidag(ibnf)
    fromidx = getidagnodeidx(idag, fromnode)
    toidx = getidagnodeidx(idag, tonode)
    add_edge!(idag, fromidx, toidx)
    updateidagstates!(ibnf, fromnode; @passtime)
    return true
end

"""
$(TYPEDSIGNATURES)
"""
function removeidagedge!(idag::IntentDAG, fromnode::UUID, tonode::UUID)
    fromidx = getidagnodeidx(idag, fromnode)
    toidx = getidagnodeidx(idag, tonode)
    rem_edge!(idag, fromidx, toidx)
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

@recvtime function updateidagstates!(ibnf::IBNFramework, idagnodeid::UUID, makestate::Union{Nothing, IntentState.T} = nothing)
    idag = getidag(ibnf)
    idagnode = getidagnode(idag, idagnodeid)
    return updateidagnodestates!(ibnf, idagnode, makestate; @passtime)
end

"""
$(TYPEDSIGNATURES)
Return value is true if state is changed.
"""
@recvtime function updateidagnodestates!(ibnf::IBNFramework, idagnode::IntentDAGNode, makestate::Union{Nothing, IntentState.T} = nothing)
    idag = getidag(ibnf)
    idagnodeid = getidagnodeid(idagnode)
    idagnodechildren = getidagnodechildren(idag, idagnodeid)
    childrenstates = getidagnodestate.(idagnodechildren)
    currentstate = getidagnodestate(idagnode)
    changedstate = false
    newstate::Union{Nothing, IntentState.T} = nothing

    # if !isnothing(offsettime)
    #     if Dates.year(offsettime) == 2025 && Dates.month(offsettime) == 7 && Dates.day(offsettime) == 16
    #         error("shouldnt have come here")
    #     end
    # end

    if makestate == IntentState.Installing # only state that propagates down the DAG
        if currentstate == IntentState.Compiled
            changedstate = true
            newstate = makestate
            pushstatetoidagnode!(idagnode, newstate; @passtime)
        end
    elseif makestate == IntentState.Compiled && currentstate in [IntentState.Installed, IntentState.Failed]
        changedstate = true
        newstate = makestate
        pushstatetoidagnode!(idagnode, newstate; @passtime)
    elseif length(childrenstates) == 0
        if !isnothing(makestate) && makestate != currentstate
            changedstate = true
            newstate = makestate
            pushstatetoidagnode!(idagnode, makestate; @passtime)
        elseif isnothing(makestate) && currentstate != IntentState.Uncompiled
            changedstate = true
            newstate = IntentState.Uncompiled
            pushstatetoidagnode!(idagnode, IntentState.Uncompiled; @passtime)
        end        
    elseif all(==(IntentState.Compiled), childrenstates)
        if currentstate != IntentState.Compiled
            changedstate = true
            newstate = IntentState.Compiled
            pushstatetoidagnode!(idagnode, IntentState.Compiled; @passtime)
        end
    elseif any(==(IntentState.Uncompiled), childrenstates)
        if currentstate != IntentState.Uncompiled
            changedstate = true
            newstate = IntentState.Uncompiled
            pushstatetoidagnode!(idagnode, IntentState.Uncompiled; @passtime)
        end
    elseif all(==(IntentState.Installed), childrenstates)
        if currentstate == IntentState.Uncompiled
            changedstate = true
            newstate = IntentState.Compiled
            pushstatetoidagnode!(idagnode, IntentState.Compiled; @passtime)
        elseif currentstate != IntentState.Installed && currentstate != IntentState.Compiled
            changedstate = true
            newstate = IntentState.Installed
            pushstatetoidagnode!(idagnode, IntentState.Installed; @passtime)
        end
    elseif all(x -> x in [IntentState.Installed, IntentState.Compiled], childrenstates)
        newstate = IntentState.Compiled
        pushstatetoidagnode!(idagnode, IntentState.Compiled; @passtime)
    elseif any(==(IntentState.Failed), childrenstates)
        if currentstate != IntentState.Failed && currentstate != IntentState.Compiled 
            changedstate = true
            if currentstate == IntentState.Uncompiled
                newstate = IntentState.Compiled
            else
                newstate = IntentState.Failed
            end
            pushstatetoidagnode!(idagnode, newstate; @passtime)
        end
    elseif any(==(IntentState.Pending), childrenstates)
        if currentstate != IntentState.Pending && currentstate != IntentState.Compiled && currentstate != IntentState.Uncompiled
            changedstate = true
            newstate = IntentState.Pending
            pushstatetoidagnode!(idagnode, IntentState.Pending; @passtime)
        end
    else
        if currentstate != IntentState.Pending  && currentstate != IntentState.Compiled && currentstate != IntentState.Uncompiled
            changedstate = true
            newstate = IntentState.Pending
            pushstatetoidagnode!(idagnode, IntentState.Pending; @passtime)
        end
    end
    if changedstate
        if newstate == IntentState.Installing # go down the DAG
            foreach(getidagnodechildren(idag, idagnodeid)) do idagnodechild
                updateidagnodestates!(ibnf, idagnodechild, IntentState.Installing; @passtime)
            end
        else # go up the DAG
            foreach(getidagnodeparents(idag, idagnodeid)) do idagnodeparent
                updateidagnodestates!(ibnf, idagnodeparent; @passtime)
            end
        end
        if newstate == IntentState.Installed && getintent(idagnode) isa LightpathIntent
            if !isonlyoptical(getsourcenodeallocations(getintent(idagnode))) && !isonlyoptical(getdestinationnodeallocations(getintent(idagnode)))
                addtoinstalledlightpaths!(ibnf, idagnode) # first check if intent implementation is a lightpath
            end
        elseif newstate == IntentState.Installed && getintent(idagnode) isa CrossLightpathIntent
            addtoinstalledlightpaths!(ibnf, idagnode) # first check if intent implementation is a lightpath
        end
        if newstate == IntentState.Compiled && (getintent(idagnode) isa LightpathIntent || getintent(idagnode) isa CrossLightpathIntent)
            removefrominstalledlightpaths!(ibnf, idagnode) # if intentid found, remove
        end
        if getintent(idagnode) isa RemoteIntent && !getisinitiator(getintent(idagnode)) # notify initiator domain
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
Set `parentsfirst=true` to get the upper level children first and false to get the leafs first.
"""
function getidagnodedescendants(idag::IntentDAG, idagnodeid::UUID; exclusive=false, includeroot=false, parentsfirst=true)
    idns = Vector{IntentDAGNode}()
    parentsfirst && includeroot && push!(idns, getidagnode(idag, idagnodeid))
    for chidn in getidagnodechildren(idag, idagnodeid)
        _descendants_recu!(idns, idag, getidagnodeid(chidn); exclusive, parentsfirst)
    end
    !parentsfirst && includeroot && push!(idns, getidagnode(idag, idagnodeid))
    return idns
end

function _descendants_recu!(vidns::Vector{IntentDAGNode}, idag::IntentDAG, idagnodeid::UUID; exclusive, parentsfirst=true)
    exclusive && length(getidagnodeparents(idag, idagnodeid)) > 1 && return
    idn = getidagnode(idag, idagnodeid)
    any(x -> x === idn, vidns) || parentsfirst && push!(vidns, idn)
    for chidn in getidagnodechildren(idag, idagnodeid)
        _descendants_recu!(vidns, idag, getidagnodeid(chidn); exclusive, parentsfirst)
    end
    any(x -> x === idn, vidns) || !parentsfirst && push!(vidns, idn)
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
    any(x -> x === idagnodeidx, vidxs) || push!(vidxs, idagnodeidx)
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
        any(x -> x === idn, vidns) || push!(vidns, idn)
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
        any(x -> x === idn, vidns) || push!(vidns, idn)
    end
end

function issubdaggrooming(idag::IntentDAG, idagnodeid::UUID)
    for idagnode in getidagnodedescendants(idag, idagnodeid)
        idagnodeidx = getidagnodeidx(idag, getidagnodeid(idagnode))
        if length(Graphs.inneighbors(idag, idagnodeidx)) > 1
            if length(getidagnoderoots(idag, getidagnodeid(idagnode))) > 1
                return true
            end
        end
    end
    return false
end

