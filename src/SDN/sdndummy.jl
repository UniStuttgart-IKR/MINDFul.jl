# Defines the simulated SDN controller to bind with simulated resources

"""
A dummy SDN controller to use for research and experiment purposes.
This SDN controller is directly connected with the simulated physical layer network resources `SimNetResou.jl`

    $(TYPEDFIELDS)
"""
struct SDNdummy{T} <: SDN
    #TODO add SDN NBI
    #TODO how to assure that it is unique per IBN group?
    "network of SDN"
    gr::MetaDiGraph{T}
    "inter domain equipment(e.g. links)"
    interprops::Dict{CompositeEdge, Dict{Symbol, Any}}
end
SDNdummy(gr::MetaDiGraph) = SDNdummy(gr, Dict{CompositeEdge, Dict{Symbol, Any}}())
getid(sdnd::SDNdummy) = nothing

"""Return the graph SDN is responsible for"""
getgraph(sdnd::SDNdummy) = sdnd.gr
function mergeSDNs!(sdns::Vector{SDNdummy{R}}, cedges::Vector{CompositeEdge{T}}) where {T,R}
    cg = CompositeGraph(getfield.(sdns, :gr), cedges; both_ways=true)
    #TODO ask router and link values in PHY
    for ce in cedges
        ed = edge(cg, ce)
        #TODO choose properties
        set_prop!(cg, ed, :link, Link(25 , 100) )
        set_prop!(cg, reverse(ed), :link, Link(25 , 100) )
        # push interdomain values in sdns involved
        # shallow copy for bilateral modification
        for sdn in [sdns[ce.src[1]], sdns[ce.dst[1]]]
            sdn.interprops[ce] = props(cg, ed)
            sdn.interprops[reverse(ce)] = props(cg, reverse(ed))
        end
    end
    return cg
end

function connect!(sdns::Vector{SDNdummy{R}}, cedges::Vector{CompositeEdge{T}}, ds::Vector{Dict{Symbol, K}}) where {T,R,K}
    for (ce,d) in zip(cedges, ds)
        for sdn in [sdns[ce.src[1]], sdns[ce.dst[1]]]
            sdn.interprops[ce] = d
        end
    end
    return true
end
function connect!(sdn1::SDNdummy{R}, cedge::CompositeEdge{T}, d::Dict{Symbol, K}) where {T,R,K}
    sdn1.interprops[cedge] = d
    return true
end

isavailable_port(sdn::SDNdummy, v::Int) = hasport(get_prop(getgraph(sdn), v, :router))
reserve_port!(sdn::SDNdummy, v::Int, intidx) = useport!(get_prop(getgraph(sdn), v, :router), intidx)
function issatisfied_port(sdn::SDNdummy, v::Int, intidx)
    rtview = get_prop(getgraph(sdn), v, :router)
    return intidx in rtview.reservations
end

"reserve capacity on an intraSDN edge"
function reserve(sdn::SDNdummy, e::Edge, capacity::Real)
    mgr = getgraph(sdn)
    rts = [get_prop(mgr, v, :router) for v in [e.src, e.dst]]
    l = get_prop(mgr, e.src, e.dst, :link)
    if hasport(rts[1]) && hasport(rts[2]) && hascapacity(l, capacity)
        useport!(rts[1])
        useport!(rts[2])
        usecapacity!(l, capacity)
        return true
    end
    return false
end

"free capacity on an intraSDN edge"
function free!(sdn::SDNdummy, e::Edge, capacity::Real)
    mgr = getgraph(sdn)
    rts = [get_prop(mgr, v, :router) for v in [e.src, e.dst]]
    l = get_prop(mgr, e.src, e.dst, :link)
    freeport!(rts[1]) 
    freeport!(rts[2]) 
    freecapacity!(l, capacity)
    return true
end

function isavailable_slots(sdn::SDNdummy, ce::CompositeEdge, sr::UnitRange{Int})
    gr = getgraph(sdn)
    if ce.src[1] == ce.dst[1]
        e = Edge(ce.src[2], ce.dst[2])
        link = get_prop(gr, e, :link)
    else
        link = sdn.interprops[ce][:link]
    end
    return hasslots(link, sr)
end

function reserve_slots!(sdn::SDNdummy, ce::CompositeEdge, sr::UnitRange{Int}, intidx)
    gr = getgraph(sdn)
    if ce.src[1] == ce.dst[1]
        e = Edge(ce.src[2], ce.dst[2])
        link = get_prop(gr, e, :link)
    else
        link = sdn.interprops[ce][:link]
    end
    return useslots!(link, sr, intidx)
end

function issatisfied_slots!(sdn::SDNdummy, ce::CompositeEdge, sr::UnitRange{Int}, intidx)
    gr = getgraph(sdn)
    if ce.src[1] == ce.dst[1]
        e = Edge(ce.src[2], ce.dst[2])
        link = get_prop(gr, e, :link)
    else
        link = sdn.interprops[ce][:link]
    end
    resvs = link.reservations
    all(x -> x == intidx, resvs[sr])
end
"check capacity on an intraSDN edge"
function isavailable(sdn::SDNdummy, e::Edge, capacity::Real)
    mgr = getgraph(sdn)
    rts = [get_prop(mgr, v, :router) for v in [e.src, e.dst]]
    l = get_prop(mgr, e.src, e.dst, :link)
    return hasport(rts[1]) && hasport(rts[2]) && hascapacity(l, capacity)
end

function isavailable(sdn::SDNdummy, p::Vector{<:Integer}, capacity::Real)
    all(isavailable(sdn, e, capacity) for e in edgeify(p))
end

"reserve capacity on an interSDN edge"
function reserve(sdn1::SDNdummy, sdn2::SDNdummy, ce::CompositeEdge, capacity::Real, ceintrasdn=nothing)
    ceintrasdn === nothing && (ceintrasdn = ce)
    mgr1 = getgraph(sdn1)
    mgr2 = getgraph(sdn2)

    rts = [get_prop(mgr, v, :router) for (mgr,v) in zip([mgr1, mgr2],[ceintrasdn.src[2], ceintrasdn.dst[2]])]
    l = sdn1.interprops[ce][:link]
    if hasport(rts[1]) && hasport(rts[2]) && hascapacity(l, capacity)
        useport!(rts[1])
        useport!(rts[2])
        usecapacity!(l, capacity)
        return true
    end
    return false
end

"free capacity on an interSDN edge"
function free!(sdn1::SDNdummy, sdn2::SDNdummy, ce::CompositeEdge, capacity::Real)
    mgr1 = getgraph(sdn1)
    mgr2 = getgraph(sdn2)
    rts = [get_prop(mgr, v, :router) for (mgr,v) in zip([mgr1, mgr2],[ce.src[2], ce.dst[2]])]
    l = sdn1.interprops[ce][:link]
    freeport!(rts[1])
    freeport!(rts[2])
    freecapacity!(l, capacity)
    return true
end

"check capacity on an interSDN edge"
function isavailable(sdn1::SDNdummy, sdn2::SDNdummy, ce::CompositeEdge, capacity::Real, ceintrasdn=nothing)
    ceintrasdn === nothing && (ceintrasdn = ce)
    # TODO: build an interface for IBNs
    mgr1 = getgraph(sdn1)
    mgr2 = getgraph(sdn2)
    rts = [get_prop(mgr, v, :router) for (mgr,v) in zip([mgr1, mgr2],[ceintrasdn.src[2], ceintrasdn.dst[2]])]
    # always get link from the first SDN argument
    l = sdn1.interprops[ce][:link]
    return hasport(rts[1]) && hasport(rts[2]) && hascapacity(l, capacity)
end

##---------Multilayer-------------#

function reserve_routerport(sdnd::SDNdummy, ibnintid::Tuple{Int, Int}, node::Int)
    mgr = getgraph(sdnd)
    rt = get_prop(mgr, node, :router)
    return useport!(rt, ibnintid)
end

function reserve_fiber(sdn::SDNdummy, ibnintid::Tuple{Int,Int}, e::Edge, props::OpticalTransProperties)
    mgr = getgraph(sdn)
    rts = [get_prop(mgr, v, :router) for v in [e.src, e.dst]]
    l = get_prop(mgr, e.src, e.dst, :link)
    if hasport(rts[1]) && hasport(rts[2]) && hascapacity(l, capacity)
        useport!(rts[1])
        useport!(rts[2])
        usecapacity!(l, capacity)
        return true
    end
    return false
end

function reserve_fiber(sdn1::SDNdummy, sdn2::SDNdummy, ce::CompositeEdge, ceintrasdn, props::OpticalTransProperties)
    ceintra = ceintrasdn === nothing ? ce : ceintrasdn
    mgr1 = getgraph(sdn1)
    mgr2 = getgraph(sdn2)

    rts = [get_prop(mgr, v, :router) for (mgr,v) in zip([mgr1, mgr2],[ceintra.src[2], ceintra.dst[2]])]
    l = sdn1.interprops[ce][:link]
    if hasport(rts[1]) && hasport(rts[2]) && hascapacity(l, capacity)
        useport!(rts[1])
        useport!(rts[2])
        usecapacity!(l, capacity)
        return true
    end
    return false
end

function reserve(reservemethod::F, ibnintid::Tuple{Int,Int}, args...; sdn1=nothing, sdn2=nothing, ce=nothing, ceintra=nothing) where F <: Function
    if sdn2 === nothing
        reservemethod(sdn1, ibnintid, ce, args...)
    else
        reservemethod(sdn1, sdn2, ce, ceintra, args...)
    end
end
