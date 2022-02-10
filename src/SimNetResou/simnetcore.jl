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
