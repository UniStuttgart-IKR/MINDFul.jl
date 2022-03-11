#=
# Simulating the Physical Layer
=#

export randomsimgraph! 

"""
Router nodes

    $(TYPEDFIELDS)
"""
mutable struct Router
    "Available ports needed to attach a fiber link"
    nports::Int
    "Already reserved ports"
    rezports::Int
end
Router(np::Int) = Router(np, 0)
hasport(rt::Router) = rt.nports - rt.rezports > 0 
useport!(rt::Router) = hasport(rt) ? rt.rezports += 1 : error("No more available ports in Router ", rt)
freeport!(rt::Router) = rt.rezports - 1 >= 0 ? rt.rezports -= 1 : rt.rezports = 0

"""
Fiber link connecting routers

    $(TYPEDFIELDS)
"""
mutable struct Link
    "Length of link"
    length::typeof(1.0u"km")
    "Available capacity in the link"
    capacity::Float64
    "Already reserver capacity"
    rezcapacity::Float64
end
Base.show(io::IO, l::Link) = print(io, "$(l.length), $(l.rezcapacity)/$(l.capacity)")
Base.show(io::IO, ::MIME"text/plain", l::Link) = Base.show(io, l)
Link(len::Real, cap::Real) = Link(len*1.0u"km", convert(Float64, cap), 0.0)
hascapacity(l::Link, cap::Real) = l.capacity - l.rezcapacity > cap
usecapacity!(l::Link, cap::Real) = hascapacity(l, cap) ? l.rezcapacity += cap : error("No more capacity on the Link ", l)
freecapacity!(l::Link, cap::Real) = l.rezcapacity - cap > 0 ? l.rezcapacity -= cap : l.rezcapacity = 0
delay(l::Link) = 5u"ns/km" * l.length

randomgraph(gr::DiGraph) = randomgraph(MetaDiGraph(gr))
function randomsimgraph!(mgr::MetaDiGraph)
    for v in vertices(mgr)
        set_prop!(mgr, v, :router, Router(rand(10:20)) )
    end
    for e in edges(MetaGraph(mgr))
        ralength = rand(50:200)
        set_prop!(mgr, e, :link, Link(ralength , 100) )
        set_prop!(mgr, reverse(e), :link, Link(ralength , 100) )
    end
    return mgr
end

"""
Builds a simulated graph 
Give in a metagraph having:
`:routerports` as integer in every node
`:xcoord` as integer in every node
`:ycoord` as integer in every node
`:linkcapacity` as float64 in every link
"""
function simgraph(mgr::MetaDiGraph; distance_method=euclidean_dist)
    simgr = MetaDiGraph(mgr)
    for v in vertices(mgr)
        set_prop!(simgr, v, :router, Router(get_prop(mgr, v, :routerports)))
        set_prop!(simgr, v, :xcoord, get_prop(mgr, v, :xcoord))
        set_prop!(simgr, v, :ycoord, get_prop(mgr, v, :ycoord))
    end
    for e in edges(MetaGraph(mgr))
        #calculate distance
        possrc = [get_prop(mgr, e.src, :xcoord), get_prop(mgr, e.src, :ycoord)]
        posdst = [get_prop(mgr, e.dst, :xcoord), get_prop(mgr, e.dst, :ycoord)]
        distance = distance_method(possrc, posdst)

        set_prop!(simgr, e, :link, Link(distance , get_prop(mgr, e, :linkcapacity)) )
        set_prop!(simgr, reverse(e), :link, Link(distance , get_prop(mgr, e, :linkcapacity)) )
    end
    return simgr
end
euclidean_dist(possrc, posdst) = sqrt(sum((possrc .- posdst) .^ 2))

function simgraph(cg::CompositeGraph{MetaDiGraph, T}; distance_method=euclidean_dist) where {T<:AbstractGraph}
    cgnew = CompositeGraph{MetaDiGraph, T}(nothing)
    for gr in cg.grv
        add_vertex!(cgnew, simgraph(gr; distance_method=distance_method))
    end
    for interedgs in cg.ceds
        add_edge!(cgnew, interedgs)
        possrc = [get_prop(cgnew, vertex(cgnew, interedgs.src...), :xcoord), get_prop(cgnew, vertex(cgnew, interedgs.src...), :ycoord)]
        posdst = [get_prop(cgnew, vertex(cgnew, interedgs.dst...), :xcoord), get_prop(cgnew, vertex(cgnew, interedgs.dst...), :ycoord)]
        distance = distance_method(possrc, posdst)
        set_prop!(cgnew, edge(cgnew, interedgs), :link, Link(distance , get_prop(cg, edge(cg, interedgs), :linkcapacity)) )
    end
    return cgnew
end
