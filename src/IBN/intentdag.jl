"$(TYPEDSIGNATURES) Add `intent` as to the DAG `idag` as a root."
function addchild!(idag::IntentDAG, intent::I) where I<:Intent
    state = intent isa LowLevelIntent ? compiled : uncompiled
    childnode = IntentDAGNode(intent, state, uuidlast(idag))
    add_vertex!(idag, uuidlast(idag), childnode) || return false
    uuidpp!(idag)
    return childnode
end

"$(TYPEDSIGNATURES) Add `intent` as to the DAG as a child to the intent with uuid `parent`."
function addchild!(idag::IntentDAG, parent::UUID, child::I) where I<:Intent
    parentnode = idag[parent]
    state = child isa LowLevelIntent ? compiled : uncompiled
    childnode = IntentDAGNode(child, state, uuidlast(idag))
    add_vertex!(idag, uuidlast(idag), childnode) || return false
    add_edge!(idag, parent, uuidlast(idag), nothing) || return false
    uuidpp!(idag)
    return childnode
end

"$(TYPEDSIGNATURES) Increase the count of intent UUID."
function uuidpp!(idag::IntentDAG)
    idag.graph_data.intentcounter += 1
    return UUID(idag.graph_data.intentcounter)
end
uuidlast(idag::IntentDAG) = UUID(idag.graph_data.intentcounter)
"$(TYPEDSIGNATURES) Return the user intent"
getuserintent(idag::IntentDAG) = return idag[UUID(1)]

"$(TYPEDSIGNATURES) Return `true` if `intent` is an intra-domain intent"
function isintraintent(ibn::IBN, intent::ConnectivityIntent)
    if getid(ibn) == getsrc(intent)[1] == getdst(intent)[1]
        return true
    elseif getid(ibn) == getsrcdom(intent)
        return getdst(intent) in bordernodes(ibn)
    elseif getid(ibn) == getdstdom(intent)
        return getsrc(intent) in bordernodes(ibn)
    else
        return false
    end
end

"$(TYPEDSIGNATURES) Set the state of DAG node `idn` of DAG `dag` of `ibn` to `newstate` with logging time `time`"
function setstate!(idn, dag, ibn::IBN, newstate::IntentState; time)
    idn.state == newstate && return
    if newstate == compiled
        setstate!(idn, dag, ibn, Val(compiled); time)
    elseif newstate == installed
        setstate!(idn, dag, ibn, Val(installed); time)
    elseif newstate == failure
        setstate!(idn, dag, ibn, Val(failure); time)
    else
        idn.state = newstate
        push!(idn.logstate, (time, newstate))
    end
end


"""propagate state in the DAG
"compiled" and "installed" states start only from `LowLevelIntents` and propagte the tree up to the root
"""
function setstate!(idn::IntentDAGNode, dag::IntentDAG, ibn::IBN, newstate::Val{compiled}; time)
    idn.state == compiled && return
    idn.state = compiled
    push!(idn.logstate, (time, compiled))
    if isroot(dag, idn)
        intentissuer = getintentissuer(ibn, getid(dag))
        # if product of RemoteIntent
        if intentissuer isa IBNIssuer
            ibnid = intentissuer.ibnid
            ibncustomer = getibn(ibn, ibnid)
            setstate!(ibncustomer, ibn, getid(ibn), getid(dag), compiled; time)
        end
    else
        for par in parents(dag, idn)
            try2setstate!(par, dag, ibn, Val(compiled); time)
        end
    end
end

function setstate!(idn::IntentDAGNode, dag::IntentDAG, ibn::IBN, newstate::Val{uncompiled}; time)
    idn.state == uncompiled && return
    idn.state = uncompiled
    push!(idn.logstate, (time, uncompiled))
    if isroot(dag, idn)
        intentissuer = getintentissuer(ibn, getid(dag))
        # if product of RemoteIntent
        if intentissuer isa IBNIssuer
            ibnid = intentissuer.ibnid
            ibncustomer = getibn(ibn, ibnid)
            setstate!(ibncustomer, ibn, getid(ibn), getid(dag), uncompiled; time)
        end
    else
        @warn("Uncompiled intent with parents")
    end
end

function setstate!(idn::IntentDAGNode, dag::IntentDAG, ibn::IBN, newstate::Val{installed}; time)
    idn.state == installed && return
    idn.state = installed
    push!(idn.logstate, (time, installed))
    if isroot(dag, idn)
        intentissuer = getintentissuer(ibn, getid(dag))
        # if product of RemoteIntent
        if intentissuer isa IBNIssuer
            ibnid = intentissuer.ibnid
            ibncustomer = getibn(ibn, ibnid)
            setstate!(ibncustomer, ibn, getid(ibn), getid(dag), installed; time)
        end
    else
        for par in parents(dag, idn)
            try2setstate!(par, dag, ibn, Val(installed); time)
        end
    end
end

function setstate!(idn::IntentDAGNode, dag::IntentDAG, ibn::IBN, newstate::Val{failure}; time)
    idn.state == failure && return
    idn.state = failure
    push!(idn.logstate, (time, failure))
    if isroot(dag, idn)
        intentissuer = getintentissuer(ibn, getid(dag))
        # if product of RemoteIntent
        if intentissuer isa IBNIssuer
            ibnid = intentissuer.ibnid
            ibncustomer = getibn(ibn, ibnid)
            setstate!(ibncustomer, ibn, getid(ibn), getid(dag), failure; time)
        end
    else
        for par in parents(dag, idn)
            setstate!(par, dag, ibn, Val(failure); time)
        end
    end
end

function setstate!(idn::IntentDAGNode, dag::IntentDAG, ibn, newstate::Val{installing}; time)
    idn.state == installing && return
    idn.state = installing
    push!(idn.logstate, (time, installing))
end
function setstate!(idn::IntentDAGNode, dag::IntentDAG, ibn, newstate::Val{installfailed}; time)
    idn.state == installfailed && return
    idn.state = installfailed; 
    push!(idn.logstate, (time, installfailed))
end
# TODO do i need to update parents ?
function setstate!(idn::IntentDAGNode, dag::IntentDAG, ibn, newstate::Val{compiling}; time)
    idn.state == compiling && return
    idn.state = compiling; 
    push!(idn.logstate, (time, compiling))
end

"""
Checks all children of `idn` and if all are compiled, `idn` is getting in the compiled state also.
If not, it gets in the `compiling` state.
"""
function try2setstate!(idn::IntentDAGNode, dag::IntentDAG, ibn::IBN, newstate::Val{compiled}; time)
    descs = descendants(dag, idn)
    if all(x -> x.state in [compiled, installed, installing, installfailed], descs)
        setstate!(idn, dag, ibn, Val(compiled); time)
    elseif any(x -> x.state in [uncompiled, compiling], descs)
        setstate!(idn, dag, ibn, Val(compiling); time)
    end
end

"""
Checks all children of `idn` and if all are installed, `idn` is getting in the installed state also.
If not, it gets in the `installing` state.
"""
function try2setstate!(idn::IntentDAGNode, dag::IntentDAG, ibn::IBN, newstate::Val{installed}; time)
    descs = descendants(dag, idn)
    if all(x -> x.state == installed, descs)
        setstate!(idn, dag, ibn, Val(installed); time)
    else
        setstate!(idn, dag, ibn, Val(installing); time)
    end
end

"get all nodes with the same parent"
siblings(idn::IntentDAGNode, dag::IntentDAG, paruuid=nothing) = error("not implemented")

function parents(dag::IntentDAG, idn::IntentDAGNode)
    return [dag[MGN.label_for(dag, v)] for v in inneighbors(dag, MGN.code_for(dag, idn.id))]
end

function children(dag::IntentDAG, idn::IntentDAGNode)
    return [dag[MGN.label_for(dag, v)] for v in outneighbors(dag, MGN.code_for(dag, idn.id))]
end

isroot(dag::IntentDAG, idn::IntentDAGNode) = length(inneighbors(dag, MGN.code_for(dag, idn.id))) == 0
haschildren(dag::IntentDAG, idn::IntentDAGNode) = length(outneighbors(dag, MGN.code_for(dag, idn.id))) > 0

getleafs(dag::IntentDAG) = getleafs(dag, getuserintent(dag))
"$(TYPEDSIGNATURES) Get the leafs of DAG `dag` starting from node `idn`"
function getleafs(dag::IntentDAG, idn::IntentDAGNode)
    idns = Vector{IntentDAGNode}()
    for chidn in children(dag, idn)
        _leafs_recu!(idns, dag, chidn)
    end
    return idns
end

descendants(dag::IntentDAG) = descendants(dag, getuserintent(dag))
"$(TYPEDSIGNATURES) Get all descendants of DAG `dag` starting from node `idn`"
function descendants(dag::IntentDAG, idn::IntentDAGNode)
    idns = Vector{IntentDAGNode}()
    for chidn in children(dag, idn)
        _descendants_recu!(idns, dag, chidn)
    end
    return idns
end

function _leafs_recu!(vidns::Vector{IntentDAGNode}, dag::IntentDAG, idn::IntentDAGNode)
    if haschildren(dag, idn)
        for chidn in children(dag, idn)
            _leafs_recu!(vidns, dag, chidn)
        end
    else
        push!(vidns, idn)
    end
end

function _descendants_recu!(vidns::Vector{IntentDAGNode}, dag::IntentDAG, idn::IntentDAGNode)
    push!(vidns, idn)
    for chidn in children(dag, idn)
        _descendants_recu!(vidns, dag, chidn)
    end
end



getremoteintentsid(ibn::IBN, intentidx::Int) = getremoteintentsid(ibn, ibn.intents[intentidx])
"$(TYPEDSIGNATURES) Get all `RemoteIntent`s of `dag` of `ibn`"
function getremoteintentsid(ibn::IBN, dag::IntentDAG)
    ibnid_intentid = Vector{Tuple{Int, Int}}()
    _getremoteintentsid_recu!(ibn, dag, ibnid_intentid)
    ibnid_intentid
end

function _getremoteintentsid_recu!(ibn::IBN, dag::IntentDAG, ibnid_intentid)
    for leaf in getleafs(dag)
        intent = leaf.intent
        if intent isa RemoteIntent
            push!(ibnid_intentid, (intent.ibnid, intent.intentidx))
            remibn = getibn(ibn, intent.ibnid)
            remdag = getintent(remibn, intent.intentidx)
            _getremoteintentsid_recu!(remibn, remdag, ibnid_intentid)
        end
    end
end
