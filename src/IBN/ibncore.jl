#TODO not good minus 1
getgraph(ibn::IBN) = ibn.cgr.flatgr
getcontrollers(ibn::IBN) = ibn.controllers
getid(ibn::IBN) = ibn.id
getindex(ibn::IBN, c::R) where {R<:Union{IBN,SDN}} = findfirst(==(c), ibn.controllers)
getindex(ibn::IBN, c::R) where {R<:Intent} = findfirst(==(c), getfield.(ibn.intents, :data))
getindex(ibn::IBN, c::R) where {R<:IntentDAG} = findfirst(==(c), ibn.intents)
controllerofnode(ibn::IBN, node::Int) = ibn.controllers[domain(ibn.cgr, node)]
nodesofcontroller(ibn::IBN, ci::Int) = [i for (i,nd) in enumerate(ibn.cgr.vmap) if nd[1] == ci]
getibns(ibn::IBN) = Iterators.filter(x -> isa(x, IBN),ibn.controllers)
getsdns(ibn::IBN) = Iterators.filter(x -> isa(x, SDN),ibn.controllers)
getibn(ibn::IBN, id) = id == ibn.id ? ibn : getfirst(x -> getfield(x,:id) == id, getibns(ibn))
getintentindex(ibn::IBN, intid::Int) = findfirst(x -> getid(x) == intid, ibn.intents)
getintent(ibn::IBN, intid::Int) = let i = getintentindex(ibn, intid); i !== nothing ? ibn.intents[i] : nothing end
getintentissuer(ibn::IBN, intid::Int) = let i = getintentindex(ibn, intid); i !== nothing ? ibn.intentissuers[i] : nothing end
"returns trans nodes of the IBN in the format of (IBN id, node id)"
function transnodes(ibn::IBN; subnetwork_view=true)
    if subnetwork_view 
        [(getid(ibn.controllers[v[1]]), v[2]) for v in ibn.cgr.vmap if ibn.controllers[v[1]] isa IBN]
    else
        [v for v in vertices(ibn.cgr) if ibn.controllers[ibn.cgr.vmap[v][1]] isa IBN]
    end
end

"convert global domnod to local view of the ibn if exists"
function localnode(ibn::IBN, domnod::Tuple{Int,Int}; subnetwork_view=true)
    #domnod[2] is the same as the local view. just have to find the internal representation of IBN domnode[1]
    if domnod[1] == getid(ibn)
        if subnetwork_view
            return ibn.cgr.vmap[domnod[2]]
        else
            if ibn.cgr.vmap[domnod[2]] in ibn.cgr.vmap
                return domnod[2]
            end
        end
    else
        idx = findfirst(==(domnod[1]), getid.(getcontrollers(ibn)))
        if (idx, domnod[2]) in ibn.cgr.vmap
            if subnetwork_view
                return (idx, domnod[2])
            else
                return vertex(ibn.cgr, (idx, domnod[2]))
            end
        else
            return nothing
        end
    end
    return nothing
end

function globalnode(ibn::IBN, node::Int)
    contr = controllerofnode(ibn, node)
    if contr isa IBN
        return (getid(contr), ibn.cgr.vmap[node][2])
    else
        return (getid(ibn), node)
    end
end

"convert a global CompositeEdge(ibn1id, srcid, ibn2id, dstid) to local ibn lingo"
function localedge(ibn::IBN, cedge::CompositeEdge; subnetwork_view=true)
    csrc = localnode(ibn, cedge.src; subnetwork_view = subnetwork_view)
    cdst = localnode(ibn, cedge.dst; subnetwork_view = subnetwork_view)
    if subnetwork_view
        return CompositeEdge(csrc, cdst)
    else
        return Edge(csrc, cdst)
    end
end

globaledge(ibn::IBN, ed::Edge) = CompositeEdge(globalnode(ibn, src(ed)), globalnode(ibn, dst(ed)))
#TODO implement a different method (Channels, Tasks, yield)


Base.show(io::IO, ibn::IBN) = print(io,"IBN($(ibn.id), $(length(ibn.intents)) intents, $(length(ibn.controllers)) controllers, $(ibn.cgr), $(ibn.interprops))")
Base.show(io::IO, ::MIME"text/plain", ibn::IBN) = print(io,"IBN($(ibn.id), $(length(ibn.intents)) intents, $(length(ibn.controllers)) controllers, $(ibn.cgr), $(ibn.interprops))")

function connect(ibn1::IBN, ibn2::IBN, e::Edge)
    push!(ibn1.interprops)
end

function connectIBNs!(ibn::Vector{IBN}, cedges::Vector{CompositeEdge})
    for ce in cedges
        if ce.src[1] != ce.dst[1]
            push!(ibn[ce.src[1]].interprops.nodge, ce)
            push!(ibn[ce.dst[1]].interprops.nodge, ce)
        end
    end
end

"add a provider IBN to the list of the customer IBN with `vlist` being the communication points"
function connectIBNs!(ibn1::IBN, ibn2::IBN, cedges::Vector{CompositeEdge{T}}, dprops::Union{Vector{Dict{Symbol,R}}, Nothing}=nothing) where {T, R}
    if ibn1.id in getfield.(ibns(ibn2), :id) || ibn2.id in getfield.(ibns(ibn1), :id)
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
    
    # build graph as prrovided from the other ibn
    gr2, vmap2 = subgraph(ibn2, ibn1)
    v2add = [vp for vp in v2list if !has_vertex(gr2, vp)]
    add_vertices!(gr2, ibn2.cgr, v2add)

    gr1, vmap1 = subgraph(ibn1, ibn2)
    v1add = [vp for vp in v1list if !has_vertex(gr1, vp)]
    add_vertices!(gr1, ibn1.cgr, v1add)
    
    CompositeGraphs.add_vertex!(ibn1.cgr, gr2, cedges, dprops; vmap=vcat(vmap2, v2add), both_ways=true)
    #reverse cedges
    CompositeGraphs.add_vertex!(ibn2.cgr, gr1, cedges, dprops; vmap=vcat(vmap1, v1add), both_ways=true, rev_cedges=true)
end

"Incorporate new SDN to the IBN structure"
addSDN(ibn::IBN) = error("not implemented")
"add interSDN edges"
addinterSDNedges(ibn::IBN, ces::Vector{CompositeEdge}) = error("not implemented")

"Add Intent as Network Operator"
function addintent!(ibn::IBN, intent::Intent)
    idx = COUNTER(ibn)
    push!(ibn.intents, IntentDAG(idx, intent))
    push!(ibn.intentissuers, NetworkProvider())
    return idx
end

function remintent!(ibn::IBN, idx::Int)
    if getroot(getintent(ibn,idx)).state in [installed, failure]
        error("Cannot remove an installed or failure intent. Please uninstall first.")
        return false
    else
        intindex = getintentindex(ibn, idx)
        deleteat!(ibn.intents, intindex)
        deleteat!(ibn.intentissuers, intindex)
        return true
    end
end

"Add InterIBN-Intent as IBN2IBN, customer2provider"
function addintent!(ibnc::IBNIssuer, ibns::IBN, intent::Intent)
    @warn("permissions not implemented")
    idx = COUNTER(ibns)
    push!(ibns.intents, IntentDAG(idx, intent))
    push!(ibns.intentissuers, ibnc)
    return idx
end

"Removes all intents made from this issuer combination"
function remintent!(ibnc::IBNIssuer, ibns::IBN, intentid::Int)
    if getroot(getintent(ibns, intentid)).state in [installed, failure]
        error("Cannot remove an installed or failure intent. Please uninstall first.")
        return false
    else
        intindex = getintentindex(ibns, intentid)
        deleteat!(ibns.intents, intindex)
        deleteat!(ibns.intentissuers, intindex)
        return true
    end
end

"ibn-customer asks for the graph of ibn-provider"
function subgraph(ibnp::IBN, ibnc::IBN)
    #check permissions
    return (MetaDiGraph(), Vector{Int}())
end

