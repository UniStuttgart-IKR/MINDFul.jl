function resetIBNF!()
    empty!(COUNTER.states)
    COUNTER.states[0] = 0
    resetIBNFtime!()
end

"Converts a node path to a sequence of edges"
edgeify(p::Vector{Int}) = map(Edge , zip(p, p[2:end]));
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

rate2slots(rt::Real) = round(Int, rt)

delay(dist) = 3.0u"μs/km" * dist

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
            add_vertex!(ibn1.ngr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.dst)), domains=length(ibn1.ngr.grv), targetnode=node2)
            idx = length(ibn1.ngr.grv)
        else
            add_vertex!(ibn1.ngr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.dst)), domains=idx, targetnode=node2)
        end
        con1idx = NestedGraphs.domain(ibn1.ngr, node1)
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
            add_vertex!(ibn2.ngr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.src)), domains=length(ibn2.ngr.grv), targetnode=node1)
            idx = length(ibn2.ngr.grv)
        else
            add_vertex!(ibn2.ngr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.src)), domains=idx, targetnode=node1)
        end
        con1idx = idx
        domainnode1 = node1
        con2idx = NestedGraphs.domain(ibn2.ngr, node2)
        domainnode2 = ibn2.ngr.vmap[node2][2]
        interibnedge = NestedEdge(con1idx, domainnode1, con2idx, domainnode2)
        connect!(ibn2.controllers[con2idx], interibnedge, props(globalnet, ed))
        add_edge!(ibn2.ngr, vertex(ibn2.ngr, con1idx, node1), node2, props(globalnet, ed))
    end
    return myibns
end

function myprint(ci, io::IO = stdout)
    rts = [Term.RenderableText("[bold white]" * string(fname) * ": [/bold white]" * Term.escape_brackets(string(getfield(ci, fname)))) for fname in fieldnames(typeof(ci))]
    tb = Term.TextBox(string(reduce(/, rts)), title = string(typeof(ci)), title_style="bold yellow")
    println(io, tb)
end

"Get nodes from a MetaGraphNext graph"
get_vertices(x) = Base.getindex.(values(x.vertex_properties), 2)
