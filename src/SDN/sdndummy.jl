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

"""Return the graph SDN is responsible for"""
graph(sdnd::SDNdummy) = sdnd.gr

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

"reserve capacity on an intraSDN edge"
function reserve(sdn::SDNdummy, e::Edge, capacity::Real)
    mgr = graph(sdn)
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
    mgr = graph(sdn)
    rts = [get_prop(mgr, v, :router) for v in [e.src, e.dst]]
    l = get_prop(mgr, e.src, e.dst, :link)
    freeport!(rts[1]) 
    freeport!(rts[2]) 
    freecapacity!(l, capacity)
    return true
end

"check capacity on an intraSDN edge"
function isavailable(sdn::SDNdummy, e::Edge, capacity::Real)
    mgr = graph(sdn)
    rts = [get_prop(mgr, v, :router) for v in [e.src, e.dst]]
    l = get_prop(mgr, e.src, e.dst, :link)
    return hasport(rts[1]) && hasport(rts[2]) && hascapacity(l, capacity)
end


"reserve capacity on an interSDN edge"
function reserve(sdn1::SDNdummy, sdn2::SDNdummy, ce::CompositeEdge, capacity::Real)
    mgr1 = graph(sdn1)
    mgr2 = graph(sdn2)

    rts = [get_prop(mgr, v, :router) for (mgr,v) in zip([mgr1, mgr2],[ce.src[2], ce.dst[2]])]
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
    mgr1 = graph(sdn1)
    mgr2 = graph(sdn2)
    rts = [get_prop(mgr, v, :router) for (mgr,v) in zip([mgr1, mgr2],[ce.src[2], ce.dst[2]])]
    l = sdn1.interprops[ce][:link]
    freeport!(rts[1])
    freeport!(rts[2])
    freecapacity!(l, capacity)
    return true
end

"check capacity on an interSDN edge"
function isavailable(sdn1::SDNdummy, sdn2::SDNdummy, ce::CompositeEdge, capacity::Real)
    mgr1 = graph(sdn1)
    mgr2 = graph(sdn2)
    rts = [get_prop(mgr, v, :router) for (mgr,v) in zip([mgr1, mgr2],[ce.src[2], ce.dst[2]])]
    l = sdn1.interprops[ce][:link]
    return hasport(rts[1]) && hasport(rts[2]) && hascapacity(l, capacity)
end
#
# Do the same for paths
#

"""Reserve `cap` resources amonge path `path`"""
function reserve(sdn::SDNdummy, path::Vector{Int}, capacity::Real)
    mgr = graph(sdn)
    if isreservepossible(mgr, path, capacity)
        for v in path
            rt = get_prop(mgr, v, :router)
            useport!(rt)
        end
        for sd in zip(path, path[2:end])
            l = get_prop(mgr, sd[1], sd[2], :link)
            usecapacity!(l, capacity)
        end
        return true
    else
        return false
    end
end

"""Checks if resources `cap` can be reserved in the network `mgr`"""
function isreservepossible(mgr::MetaDiGraph, path::Vector{Int}, capacity::Real)
    ispossible = true
    for v in path
        rt = get_prop(mgr, v, :router)
        !hasport(rt) && (ispossible = false)
        !ispossible && break
    end
    if ispossible
        for sd in zip(path, path[2:end])
            l = get_prop(mgr, sd[1], sd[2], :link)
            !hascapacity(l, capacity) && (ispossible = false)
            !ispossible && break
        end
    end
    return ispossible
end

function free(sdnd::SDNdummy, path::Vector{Int}, capacity::Real)
    mgr = graph(sdnd)
    for v in path
        rt = get_prop(mgr, v, :router)
        freeport!(rt)
    end
    for sd in zip(path, path[2:end])
        l = get_prop(mgr, sd[1], sd[2], :link)
        freecapacity!(l, capacity)
    end
    return true
end
