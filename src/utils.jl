"Converts a node path to a sequence of edges"
edgeify(p) = map(Edge , zip(p, p[2:end]));
edgeify(p::Vector{Tuple{Int, Int}}) = map(NestedEdge , zip(p, p[2:end]));

"$(TYPEDSIGNATURES) Get first element or `nothing`"
function getfirst(p, itr)
    for el in itr
        p(el) && return el
    end
    return nothing
end

function findNpop!(p, itr)
    for (i,el) in enumerate(itr)
        p(el) && return popat!(itr,i)
    end
    return nothing
end

function push2dict!(d::Dict{K,Vector{V}}, key, val) where {K,V}
    if haskey(d, key)
        push!(d[key], val)
    else
        d[key] = Vector{V}([val])
    end
end
function push2dict!(d::Dict{K,Vector{V}}, d2::Dict{K, Vector{V}}) where {K,V}
    for kv2 in d2
        if haskey(d, kv2.first)
            push!(d[kv2.first], kv2.second...)
        else
            d[kv2.first] = kv2.second
        end
    end
end

function longestconsecutiveblock(fun, v::AbstractVector)
    counter = 0
    maxcounter = 0
    for e in v
        if fun(e)
            counter += 1
        else
            counter >= maxcounter && (maxcounter = counter)
            counter = 0
        end
    end
    counter >= maxcounter && (maxcounter = counter)
    return maxcounter
end

rate2slots(rt::Real) = round(Int, rt)

delay(dist) = 3.0u"μs/km" * dist

"$(TYPEDSIGNATURES) Convert `globalnet` to a `NestedGraph` using `IBN` framework instances and `SDN` controllers."
function nestedGraph2IBNs!(globalnet::NestedGraph)
    NestedGraphs.removeemptygraphs_recursive!(globalnet)
    ibncounter = Counter()

    myibns = Vector{IBN{SDNdummy{Int}}}()
    for ibncgnet in globalnet.grv
        sdns = SDNdummy.(ibncgnet.grv)
        connect!(sdns, ibncgnet.neds, [props(ibncgnet, e) for e in edge.([ibncgnet], ibncgnet.neds)])
        push!(myibns, IBN(ibncounter(), sdns, ibncgnet))
    end
    for ce in globalnet.neds
        ed = NestedGraphs.edge(globalnet, ce)
        ibn1 = myibns[ce.src[1]]
        node1 = ce.src[2]
        ibn2 = myibns[ce.dst[1]]
        node2 = ce.dst[2]

        idx = findfirst(x -> isa(x, IBN) && getfield(x,:id)==ibn2.id, ibn1.controllers)
        if isnothing(idx)
            #create new graph and controller
            add_vertex!(ibn1.ngr, MetaDiGraph())
            push!(ibn1.controllers, ibn2)
            #add node
            add_vertex!(ibn1.ngr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.dst)), subgraphs=length(ibn1.ngr.grv), targetnode=node2)
            idx = length(ibn1.ngr.grv)
        else
            add_vertex!(ibn1.ngr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.dst)), subgraphs=idx, targetnode=node2)
        end
        con1idx = NestedGraphs.subgraph(ibn1.ngr, node1)
        domainnode1 = ibn1.ngr.vmap[node1][2]
        con2idx = idx
        domainnode2 = node2
        interibnedge = NestedEdge(con1idx, domainnode1, con2idx, domainnode2)
        connect!(ibn1.controllers[con1idx], interibnedge, props(globalnet, ed))
        add_edge!(ibn1.ngr, node1, vertex(ibn1.ngr, con2idx, node2), props(globalnet, ed))
        #
        # do it for the other side of IBN
        #
        idx = findfirst(x -> isa(x, IBN) && getfield(x,:id)==ibn1.id, ibn2.controllers)
        if isnothing(idx)
            #create new graph and controller
            add_vertex!(ibn2.ngr, MetaDiGraph())
            push!(ibn2.controllers, ibn1)
            #add node
            add_vertex!(ibn2.ngr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.src)), subgraphs=length(ibn2.ngr.grv), targetnode=node1)
            idx = length(ibn2.ngr.grv)
        else
            add_vertex!(ibn2.ngr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.src)), subgraphs=idx, targetnode=node1)
        end
        con1idx = idx
        domainnode1 = node1
        con2idx = NestedGraphs.subgraph(ibn2.ngr, node2)
        domainnode2 = ibn2.ngr.vmap[node2][2]
        interibnedge = NestedEdge(con1idx, domainnode1, con2idx, domainnode2)
        connect!(ibn2.controllers[con2idx], interibnedge, props(globalnet, ed))
        add_edge!(ibn2.ngr, vertex(ibn2.ngr, con1idx, node1), node2, props(globalnet, ed))
    end
    return myibns
end

"Get nodes from a MetaGraphNext graph"
get_vertices(x) = Base.getindex.(values(x.vertex_properties), 2)
