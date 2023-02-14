"$(TYPEDSIGNATURES) Get flat graph of `ibn`"
getgraph(ibn::IBN) = ibn.ngr.flatgr

"$(TYPEDSIGNATURES) Get all controllers of `ibn`. These might contain neighboring `IBN`s or intra-domain `SDN`s."
getcontrollers(ibn::IBN) = ibn.controllers

getid(ibn::IBN) = ibn.id

getindex(ibn::IBN, c::R) where {R<:Union{IBN,SDN}} = findfirst(==(c), ibn.controllers)

getindex(ibn::IBN, c::R) where {R<:Intent} = findfirst(==(c), getfield.(ibn.intents, :data))

getindex(ibn::IBN, c::R) where {R<:IntentDAG} = findfirst(==(c), ibn.intents)

"$(TYPEDSIGNATURES) Get the controller responsible for `node`"
controllerofnode(ibn::IBN, node::Int) = ibn.controllers[NestedGraphs.subgraph(ibn.ngr, node)]

"$(TYPEDSIGNATURES) Get all nodes that the controller with index `ci` is responsible for."
nodesofcontroller(ibn::IBN, ci::Int) = [i for (i,nd) in enumerate(ibn.ngr.vmap) if nd[1] == ci]

"$(TYPEDSIGNATURES) Get all neighboring IBNs"
getibns(ibn::IBN) = Iterators.filter(x -> isa(x, IBN),ibn.controllers)

"$(TYPEDSIGNATURES) Get all intra domain SDNs"
getsdns(ibn::IBN) = Iterators.filter(x -> isa(x, SDN),ibn.controllers)

"$(TYPEDSIGNATURES) Get IBN with id `id`. This could either self-refence to `ibn` or provide a neighboring IBN of `ibn`"
getibn(ibn::IBN, id) = id == ibn.id ? ibn : getfirst(x -> getfield(x,:id) == id, getibns(ibn))

"$(TYPEDSIGNATURES) Get nodes of IBN that are contained locally without border nodes."
function getmynodes(ibn::IBN; subnetwork_view::Bool=false)
    if subnetwork_view 
        [(v[1], v[2]) for v in ibn.ngr.vmap if ibn.controllers[v[1]] isa SDN]
    else
        [v for v in vertices(ibn.ngr) if ibn.controllers[ibn.ngr.vmap[v][1]] isa SDN]
    end
end

"""
$(TYPEDSIGNATURES) 

Get index of intent with id `intid` in IBN `ibn`. The index corresponds to the location in the `ibn.intents` field.
The index and the id of an intent might be different due to potential removal of some intents.
The id will always identify an intent through its lifetime, thus it should be preferred for operations.
"""
getintentindex(ibn::IBN, intid::Int) = findfirst(x -> getid(x) == intid, ibn.intents)

"$(TYPEDSIGNATURES) Get intent of `ibn` with id `intid`"
getintent(ibn::IBN, intid::Int) = let i = getintentindex(ibn, intid); i !== nothing ? ibn.intents[i] : nothing end

"$(TYPEDSIGNATURES) Get the issuer of the intent with id `intid` in `ibn`"
getintentissuer(ibn::IBN, intid::Int) = let i = getintentindex(ibn, intid); i !== nothing ? ibn.intentissuers[i] : nothing end

"""$(TYPEDSIGNATURES) 

Return the border nodes, i.e. the nodes belonging to a different domain, of the IBN.
If `subnetwork_view = true` the nodes are returned as a `Vector{Tuple{Int,Int}}` identifying `(CONTROLLER_INDEX, NODE_ID)`.
If `subnetwork_view = false` the nodes are returned as `Vector{Int}` with each element being the index of the node in `ibn`.
"""
function bordernodes(ibn::IBN; subnetwork_view::Bool=true)
    if subnetwork_view 
        [(getid(ibn.controllers[v[1]]), v[2]) for v in ibn.ngr.vmap if ibn.controllers[v[1]] isa IBN]
    else
        [v for v in vertices(ibn.ngr) if ibn.controllers[ibn.ngr.vmap[v][1]] isa IBN]
    end
end

"""$(TYPEDSIGNATURES) 

Convert the indexing of the node (IBN_ID, NODE_ID) to a local indexing with respect to `ibn`.
If `subnetwork_view = true` return in the form `Tuple{Int,Int}`, i.e., `(CONTROLLER_INDEX, NODE_ID)`.
If `subnetwork_view = false` return `Int`, i.e. the index of the node in `ibn`.
"""
function localnode(ibn::IBN, domnod::Tuple{Int,Int}; subnetwork_view=true)
    #domnod[2] is the same as the local view. just have to find the internal representation of IBN domnode[1]
    if domnod[1] == getid(ibn)
        if subnetwork_view
            return ibn.ngr.vmap[domnod[2]]
        else
            if ibn.ngr.vmap[domnod[2]] in ibn.ngr.vmap
                return domnod[2]
            end
        end
    else
        idx = findfirst(==(domnod[1]), getid.(getcontrollers(ibn)))
        if (idx, domnod[2]) in ibn.ngr.vmap
            if subnetwork_view
                return (idx, domnod[2])
            else
                return vertex(ibn.ngr, (idx, domnod[2]))
            end
        else
            return nothing
        end
    end
    return nothing
end

"$(TYPEDSIGNATURES) Return the global indexing of the node Tuple{Int,Int}, i.e., `(IBN_ID, NODE_ID)`"
function globalnode(ibn::IBN, node::Int)
    contr = controllerofnode(ibn, node)
    if contr isa IBN
        return (getid(contr), ibn.ngr.vmap[node][2])
    else
        return (getid(ibn), node)
    end
end

"""
$(TYPEDSIGNATURES) 

Convert a global `NestedEdge(ibn1id, srcid, ibn2id, dstid)` to local ibn lingo.
If `subnetwork_view = true` return a `NestedEdge` with `src` and `dst` nodes identified by `(CONTROLLER_INDEX, NODE_ID)`.
If `subnetwork_view = false` return `Edge` with `src` and `dst` nodes identified by the node index in `ibn`.
"""
function localedge(ibn::IBN, cedge::NestedEdge; subnetwork_view=true)
    csrc = localnode(ibn, cedge.src; subnetwork_view = subnetwork_view)
    cdst = localnode(ibn, cedge.dst; subnetwork_view = subnetwork_view)
    if subnetwork_view
        return NestedEdge(csrc, cdst)
    else
        return Edge(csrc, cdst)
    end
end

"""
$(TYPEDSIGNATURES) 

Convert a local edge indexing `Edge(src, dst)` with `src`, `dst` being an `Int` 
to a global edge indexing `NestedEdge` with `src`, `dst`, being a `Tuple{Int,Int}`, i.e., `IBN_ID,NODE_ID`
"""
globaledge(ibn::IBN, ed::Edge) = NestedEdge(globalnode(ibn, src(ed)), globalnode(ibn, dst(ed)))

"$(TYPEDSIGNATURES) Add `intent` to `ibn` as Network Operator. Returns the intent id."
function addintent!(ibn::IBN, intent::Intent)
    idi = COUNTER(ibn)
    push!(ibn.intents, IntentDAG(idi, intent))
    push!(ibn.intentissuers, NetworkProvider())
    return idi 
end

remallintents!(ibn::IBN) = foreach(id -> remintent!(ibn, id) , getid.(ibn.intents))

"$(TYPEDSIGNATURES) Remove intent with id `idi` from `ibn`. Returns `true` if successful."
function remintent!(ibn::IBN, idi::Int)
    idx = getintent(ibn,idi) 
    idx === nothing && return false
    if getuserintent(idx).state in [installed, failure]
        error("Cannot remove an installed or failure intent. Please uninstall first.")
        return false
    else
        idx = getintentindex(ibn, idi)
        if idx <= length(ibn.intents)
            deleteat!(ibn.intents, idx)
            deleteat!(ibn.intentissuers, idx)
            return true
        else
            return false
        end
    end
end

"$(TYPEDSIGNATURES) The IBN client `ibnc` asks to add intent `intent` to provider `ibnp`"
function addintent!(ibnc::IBNIssuer, ibnp::IBN, intent::Intent)
#    @warn("permissions not implemented")
    idx = COUNTER(ibnp)
    push!(ibnp.intents, IntentDAG(idx, intent))
    push!(ibnp.intentissuers, ibnc)
    return idx
end

"$(TYPEDSIGNATURES) The IBN client `ibnc` asks to remove intent with id `intentid` to provider `ibnp`"
function remintent!(ibnc::IBNIssuer, ibns::IBN, intentid::Int)
    if getuserintent(getintent(ibns, intentid)).state in [installed, failure]
        error("Cannot remove an installed or failure intent. Please uninstall first.")
        return false
    else
        intindex = getintentindex(ibns, intentid)
        if intindex <= length(ibns.intents)
            deleteat!(ibns.intents, intindex)
            deleteat!(ibns.intentissuers, intindex)
            return true
        else
            return false
        end
    end
end

"""$(TYPEDSIGNATURES)

The ibn in the roll of customer `ibnc` asks for the graph of the the ibn in the roll of provider `ibnp`
Such an operation is not commonly permitted in decentralized scenarios and special permissions should be established.

TODO: permissions not implemented.
"""
function subgraphibn(ibnp::IBN, ibnc::IBN)
    #check permissions
    return (MetaDiGraph(), Vector{Int}())
end


"$(TYPEDSIGNATURES) Get all intent indices from `ibn` to which the issuer is the IBN with id `ibnid` and delegated intent `dagid`."
function getintentidxsfromissuer(ibn::IBN, ibnid::Int, dagid::Int)
    idxs = Vector{Int}()
    for (i,iis) in enumerate(ibn.intentissuers) 
        if iis isa IBNIssuer
            iis.ibnid==ibnid && iis.dagid == dagid && push!(idxs, i)
        else
            ibn.id == ibnid && i == dagid && push!(idxs, i)
        end
    end
    idxs
end

"$(TYPEDSIGNATURES) Get all intent indices from `ibn` to which the issuer is the IBN with id `ibnid`."
function getintentidxsfromissuer(ibn::IBN, ibnid::Int)
    idxs = Vector{Int}()
    for (i,iis) in enumerate(ibn.intentissuers) 
        if iis isa IBNIssuer
            iis.ibnid==ibnid && push!(idxs, i)
        else
            ibn.id == ibnid && push!(idxs, i)
        end
    end
    idxs
end

Base.@deprecate connectIBNs! nothing
"""
$(TYPEDSIGNATURES) 

Connect the ibn domains `ibn` using the global indexed Edges `cedges`.
"""
function connectIBNs!(ibn::Vector{IBN}, cedges::Vector{NestedEdge})
    for ce in cedges
        if ce.src[1] != ce.dst[1]
            push!(ibn[ce.src[1]].interprops.nodge, ce)
            push!(ibn[ce.dst[1]].interprops.nodge, ce)
        end
    end
end

"$(TYPEDSIGNATURES)  Connect `ibn1` and `ibn2` with the edges `cedges` with properties `dprops`."
function connectIBNs!(ibn1::IBN, ibn2::IBN, cedges::Vector{NestedEdge{T}}, dprops::Union{Vector{Dict{Symbol,R}}, Nothing}=nothing) where {T, R}
    if ibn1.id in getfield.(getibns(ibn2), :id) || ibn2.id in getfield.(getibns(ibn1), :id)
        @warn("IBN already listed")
        return false
    end

    # Interconnecting nodes
    v1list = Set{Int}()
    v2list = Set{Int}()
    for ce in cedges
        for sd in [ce.src, ce.dst]
            if sd[1] == ibn1.id
                push!(v1list, sd[2])
            elseif sd[1] == ibn2.id
                push!(v2list, sd[2])
            end
        end
    end

    #add controllers 
    
    # build graph as provided from the other ibn
    gr2, vmap2 = subgraphibn(ibn2, ibn1)
    v2add = [vp for vp in v2list if !has_vertex(gr2, vp)]
    add_vertices!(gr2, ibn2.ngr, v2add)

    gr1, vmap1 = subgraphibn(ibn1, ibn2)
    v1add = [vp for vp in v1list if !has_vertex(gr1, vp)]
    add_vertices!(gr1, ibn1.ngr, v1add)
    
    NestedGraphs.add_vertex!(ibn1.ngr, gr2, cedges, dprops; vmap=vcat(vmap2, v2add), both_ways=true)
    #reverse cedges
    NestedGraphs.add_vertex!(ibn2.ngr, gr1, cedges, dprops; vmap=vcat(vmap1, v1add), both_ways=true, rev_cedges=true)
end

function connect(ibn1::IBN, ibn2::IBN, e::Edge)
    push!(ibn1.interprops)
end


"Incorporate new SDN to the IBN structure"
addSDN(ibn::IBN) = error("not implemented")
"add interSDN edges"
addinterSDNedges(ibn::IBN, ces::Vector{NestedEdge}) = error("not implemented")
