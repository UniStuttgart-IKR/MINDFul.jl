export edgeify, @recargs!

"Converts a node path to a sequence of edges"
edgeify(p) = map(Edge , zip(p, p[2:end]));

Base.@kwdef struct Counter
    #TODO implemente as simple integer?
    states::Dict{Int,Int} = Dict{Int,Int}(0 => 0)
end

(o::Counter)() = o.states[0] += 1
(o::Counter)(i::Int) = haskey(o.states, i) ? o.states[i] += 1 : o.states[i] = 0

"Save arguments to `recarglist` and evaluate function `funex`"
macro recargs!(recarglist::Symbol, funex::Expr)
    return quote
        push!($(esc(recarglist)), [$(esc.(funex.args[2:end])...)] )
        $(esc(funex))
    end
end

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

function compositeGraph2IBNs!(globalnet::CompositeGraph)
    CompositeGraphs.removeemptygraphs_recursive!(globalnet)
    ibncounter = Counter()

    myibns = Vector{IBN{SDNdummy{Int}}}()
    for ibncgnet in globalnet.grv
        sdns = SDNdummy.(ibncgnet.grv)
        connect!(sdns, ibncgnet.ceds, [props(ibncgnet, e) for e in edge.([ibncgnet], ibncgnet.ceds)])
        push!(myibns, IBN(ibncounter(), sdns, ibncgnet))
    end
    for ce in globalnet.ceds
        ed = CompositeGraphs.edge(globalnet, ce)
        ibn1 = myibns[ce.src[1]]
        node1 = ce.src[2]
        ibn2 = myibns[ce.dst[1]]
        node2 = ce.dst[2]

        idx = findfirst(x -> isa(x, IBN) && getfield(x,:id)==ibn2.id, ibn1.controllers)
        if isnothing(idx)
            #create new graph and controller
            add_vertex!(ibn1.cgr, MetaDiGraph())
            push!(ibn1.controllers, ibn2)
            #add node
            add_vertex!(ibn1.cgr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.dst)), domain=length(ibn1.cgr.grv), targetnode=node2)
            idx = length(ibn1.cgr.grv)
        else
            add_vertex!(ibn1.cgr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.dst)), domain=idx, targetnode=node2)
        end
        con1idx = CompositeGraphs.domain(ibn1.cgr, node1)
        domainnode1 = ibn1.cgr.vmap[node1][2]
        con2idx = idx
        domainnode2 = node2
        interibnedge = CompositeEdge(con1idx, domainnode1, con2idx, domainnode2)
        connect!(ibn1.controllers[con1idx], interibnedge, props(globalnet, ed))
        add_edge!(ibn1.cgr, node1, vertex(ibn1.cgr, con2idx, node2), props(globalnet, ed))
        #
        # do it for the other side of IBN
        #
        idx = findfirst(x -> isa(x, IBN) && getfield(x,:id)==ibn1.id, ibn2.controllers)
        if isnothing(idx)
            #create new graph and controller
            add_vertex!(ibn2.cgr, MetaDiGraph())
            push!(ibn2.controllers, ibn1)
            #add node
            add_vertex!(ibn2.cgr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.src)), domain=length(ibn2.cgr.grv), targetnode=node1)
            idx = length(ibn2.cgr.grv)
        else
            add_vertex!(ibn2.cgr, filter(x -> first(x) in [:xcoord, :ycoord] , props(globalnet, ed.src)), domain=idx, targetnode=node1)
        end
        con1idx = idx
        domainnode1 = node1
        con2idx = CompositeGraphs.domain(ibn2.cgr, node2)
        domainnode2 = ibn2.cgr.vmap[node2][2]
        interibnedge = CompositeEdge(con1idx, domainnode1, con2idx, domainnode2)
        connect!(ibn2.controllers[con2idx], interibnedge, props(globalnet, ed))
        add_edge!(ibn2.cgr, vertex(ibn2.cgr, con1idx, node1), node2, props(globalnet, ed))
    end
    return myibns
end

function myprint(ci, io::IO = stdout)
    rts = [Term.RenderableText("[bold white]" * string(fname) * ": [/bold white]" * Term.escape_brackets(string(getfield(ci, fname)))) for fname in fieldnames(typeof(ci))]
    tb = Term.TextBox(string(reduce(/, rts)), title = string(typeof(ci)), title_style="bold yellow")
    println(io, tb)
end

"""
Similar to an One Hot Vector but with continuous 1s from `from` to `to`
"""
struct RangeHotVector <: AbstractArray{Bool,1}
    from::Int
    to::Int
    size::Int
    RangeHotVector(from::Int, to::Int, size::Int) = from <= to && to <= size ? new(from,to,size) : error("Out of index arguments")
end
Base.size(rh::RangeHotVector) = (rh.size, )
Base.getindex(rh::RangeHotVector, i::Integer) = i in rh.from:rh.to
Base.show(io::IO, rh::RangeHotVector) = print(io,"RangeHotVector($(rh.from), $(rh.to), $(rh.size))")
Base.show(io::IO, ::MIME"text/plain", rh::RangeHotVector) = print(io,"RangeHotVector($(rh.from), $(rh.to), $(rh.size))")
Base.one(rh::RangeHotVector) = RangeHotVector(1, length(rh), length(rh))
rangesize(rhv::RangeHotVector) = rhv.to - rhv.from + 1

