#=
# Simulating the Physical Layer
=#

"""
Router nodes

    $(TYPEDFIELDS)
"""
mutable struct Router
    "Available ports needed to attach a fiber link"
    nports::Int
end
getports(rt::Router) = rt.nports

"""
Fiber link connecting routers

    $(TYPEDFIELDS)
"""
mutable struct Fiber
    "Length of link"
    distance::typeof(1.0u"km")
    # TODO fibertype
end
Fiber(len::Real) = Fiber(len*1.0u"km")
distance(f::Fiber) = f.distance

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

randomgraph(gr::DiGraph) = randomgraph(MetaDiGraph(gr))
"$(TYPEDSIGNATURES) Get a random graph able to simulate"
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
$(TYPEDSIGNATURES) 

Builds a graph from `mgr` able to simulate.
Pass in `mgr` having:
- `:routerports` as integer in every node
- `:xcoord` as integer in every node
- `:ycoord` as integer in every node
- `:oxc` as boolean in every node
- `:fiberslots` as int in every link

Get as an output a `MetaGraph` having:
- `:xcoord` as integer in every node
- `:ycoord` as integer in every node
- `:router` as `RouterView` in every node
- `:link` as `FiberView` in every edge
"""
function simgraph(mgr::MetaDiGraph; distance_method=euclidean_dist)
    simgr = MetaDiGraph(mgr)
    for v in vertices(mgr)
        set_prop!(simgr, v, :router, RouterView(Router(get_prop(mgr, v, :routerports))))
        set_prop!(simgr, v, :xcoord, get_prop(mgr, v, :xcoord))
        set_prop!(simgr, v, :ycoord, get_prop(mgr, v, :ycoord))
        set_prop!(simgr, v, :oxc, get_prop(mgr, v, :oxc))
    end
    for e in edges(MetaGraph(mgr))
        #calculate distance
        possrc = [get_prop(mgr, e.src, :xcoord), get_prop(mgr, e.src, :ycoord)]
        posdst = [get_prop(mgr, e.dst, :xcoord), get_prop(mgr, e.dst, :ycoord)]
        distance = distance_method(possrc, posdst)

        set_prop!(simgr, e, :link, FiberView(Fiber(distance); frequency_slots=get_prop(mgr, e, :fiberslots)) )
        set_prop!(simgr, reverse(e), :link, FiberView(Fiber(distance); frequency_slots=get_prop(mgr, e, :fiberslots)) )
    end
    return simgr
end
euclidean_dist(possrc, posdst) = sqrt(sum((possrc .- posdst) .^ 2))
geodesic_dist(possrc, posdst) = haversine(possrc, posdst, EARTH_RADIUS)

"""
$(TYPEDSIGNATURES) 

Builds a nested graph from `ng` able to simulate.
"""
function simgraph(ng::G; distance_method=euclidean_dist) where G<:NestedMetaGraph
    cgnew = G(;extrasubgraph=false)
    for gr in ng.grv
        add_vertex!(cgnew, simgraph(gr; distance_method=distance_method))
    end
    for interedgs in ng.neds
        add_edge!(cgnew, interedgs)
        possrc = [get_prop(cgnew, vertex(cgnew, interedgs.src...), :xcoord), get_prop(cgnew, vertex(cgnew, interedgs.src...), :ycoord)]
        posdst = [get_prop(cgnew, vertex(cgnew, interedgs.dst...), :xcoord), get_prop(cgnew, vertex(cgnew, interedgs.dst...), :ycoord)]
        distance = distance_method(possrc, posdst)
        set_prop!(cgnew, edge(cgnew, interedgs), :link, FiberView(Fiber(distance), frequency_slots=get_prop(ng, edge(ng, interedgs), :fiberslots)) )
    end
    return cgnew
end

function linklengthweights(mgr::AbstractMetaGraph)
    ws = zeros(Float64 ,nv(mgr),nv(mgr))
    for e in edges(mgr)
        ws[e.src, e.dst] = uconvert(u"km", distance(get_prop(mgr, e, :link))) |> ustrip
    end
    ws
end
