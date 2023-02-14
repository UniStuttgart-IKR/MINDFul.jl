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
    interprops::Dict{NestedEdge, Dict{Symbol, Any}}
end
SDNdummy(gr::MetaDiGraph) = SDNdummy(gr, Dict{NestedEdge, Dict{Symbol, Any}}())
getid(sdnd::SDNdummy) = nothing

"$(TYPEDSIGNATURES) Return the graph SDN is responsible for"
getgraph(sdnd::SDNdummy) = sdnd.gr

"$(TYPEDSIGNATURES) Merge SDN controllers `sdns` intro a `NestedGraph` using edges `cedges`"
function mergeSDNs!(sdns::Vector{SDNdummy{R}}, cedges::Vector{NestedEdge{T}}) where {T,R}
    ng = NestedGraph(getfield.(sdns, :gr), cedges; both_ways=true)
    #TODO ask router and link values in PHY
    for ce in cedges
        ed = edge(ng, ce)
        #TODO choose properties
        set_prop!(ng, ed, :link, LinkDummy(25 , 100) )
        set_prop!(ng, reverse(ed), :link, LinkDummy(25 , 100) )
        # push interdomain values in sdns involved
        # shallow copy for bilateral modification
        for sdn in [sdns[ce.src[1]], sdns[ce.dst[1]]]
            sdn.interprops[ce] = props(ng, ed)
            sdn.interprops[reverse(ce)] = props(ng, reverse(ed))
        end
    end
    return ng
end

"$(TYPEDSIGNATURES)"
function connect!(sdns::Vector{SDNdummy{R}}, cedges::Vector{NestedEdge{T}}, ds::Vector{Dict{Symbol, K}}) where {T,R,K}
    for (ce,d) in zip(cedges, ds)
        for sdn in [sdns[ce.src[1]], sdns[ce.dst[1]]]
            sdn.interprops[ce] = d
        end
    end
    return true
end
"$(TYPEDSIGNATURES)"
function connect!(sdn1::SDNdummy{R}, cedge::NestedEdge{T}, d::Dict{Symbol, K}) where {T,R,K}
    sdn1.interprops[cedge] = d
    return true
end

"$(TYPEDSIGNATURES) Check if `sdn` has any port at node `v`"
isavailable_port(sdn::SDNdummy, v::Int) = hasport(getrouter(sdn, v))
"$(TYPEDSIGNATURES) Reserve a port at node `v` of the SDN controller `sdn` and log the intent id `intidx` done for"
reserve_port!(sdn::SDNdummy, v::Int, rate::Real, intidx) = useport!(getrouter(sdn, v), rate, intidx)
"$(TYPEDSIGNATURES) Free the port at node `v` of the SDN controller `sdn` used for the intent with id `intidx`"

free_port!(sdn::SDNdummy, v::Int, intidx) = freeport!(getrouter(sdn, v), intidx)
"$(TYPEDSIGNATURES) Reserve a port at node `v` of the SDN controller `sdn` and log the intent id `intidx` done for"
isavailable_transmissionmodule(sdn::SDNdummy, v::Integer, tm::TransmissionModuleView) = hastransmissionmodule(getmlnode(sdn, v), tm)
reserve_transmissionmodule!(sdn::SDNdummy, v::Integer, tm::TransmissionModuleView, intidx) = usetransmissionmodule!(getmlnode(sdn, v), tm, intidx)
free_transmissionmodule!(sdn::SDNdummy, v::Integer, tm::TransmissionModuleView, intidx) = freetransmissionmodule!(getmlnode(sdn, v), tm, intidx)

"$(TYPEDSIGNATURES) Check if a port is allocated at node `v` of `sdn `in the name of the intent `intidx` and satisfies rate `rate`"
function issatisfied_port(sdn::SDNdummy, v::Int, rate::Number, intidx)
    rtview = getrouter(sdn, v)
    ff = findfirst(==(intidx), skipmissing(rtview.reservations))
    ff !== nothing || return false
    return getportrate(rtview, ff) > rate
end

"$(TYPEDSIGNATURES)"
function issatisfied_transmissionmodule(sdn::SDNdummy, v::Int, tm::TransmissionModuleView, intidx)
    mlnode = getmlnode(sdn, v)
    ff = findfirst(==((tm, intidx)), skipmissing(mlnode.transmodreservations))
    ff === nothing ? false : true
end

"$(TYPEDSIGNATURES) Reserve capacity `capacity` on an intra-SDN edge `e` for SDN `sdn`"
function reserve!(sdn::SDNdummy, e::Edge, capacity::Real)
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

"$(TYPEDSIGNATURES) Free `capacity` on an intra-SDN edge `e` of SDN `sdn`"
function free!(sdn::SDNdummy, e::Edge, capacity::Real)
    mgr = getgraph(sdn)
    rts = [get_prop(mgr, v, :router) for v in [e.src, e.dst]]
    l = get_prop(mgr, e.src, e.dst, :link)
    freeport!(rts[1]) 
    freeport!(rts[2]) 
    freecapacity!(l, capacity)
    return true
end

"""$(TYPEDSIGNATURES) 

Check if edge `ce`, connecting to SDNs one of which is `sdn`, has available frequency slots `sr`.
If `reserve_src=true` check the `src` node of the edge `ce`, otherwise check the `dst`.
"""
function isavailable_slots(sdn::SDNdummy, ce::NestedEdge, sr::UnitRange{Int}, reserve_src::Bool)
    gr = getgraph(sdn)
    if ce.src[1] == ce.dst[1]
        e = Edge(ce.src[2], ce.dst[2])
        link = get_prop(gr, e, :link)
    else
        link = sdn.interprops[ce][:link]
    end
    if reserve_src
        return all(link.spectrum_src[sr])
    else
        return all(link.spectrum_dst[sr])
    end
end

"""$(TYPEDSIGNATURES) 

Check if edge `ce`, connecting to SDNs one of which is `sdn`, has available frequency slots `sr`.
"""
function isavailable_slots(sdn::SDNdummy, ce::NestedEdge, sr::UnitRange{Int})
    gr = getgraph(sdn)
    if ce.src[1] == ce.dst[1]
        e = Edge(ce.src[2], ce.dst[2])
        link = get_prop(gr, e, :link)
    else
        link = sdn.interprops[ce][:link]
    end
    hasslots(link, sr)
end

"$(TYPEDSIGNATURES) Check if edge `ce` of `sdn` operates correctly."
function doesoperate_link(sdn::SDNdummy, ce::NestedEdge)
    gr = getgraph(sdn)
    if ce.src[1] == ce.dst[1]
        e = Edge(ce.src[2], ce.dst[2])
        link = get_prop(gr, e, :link)
    else
        link = sdn.interprops[ce][:link]
    end
    doesoperate(link)
end

"""$(TYPEDSIGNATURES) 

Reserve frequency slots `sr` at edge `ce`, connecting to SDNs one of which is `sdn`.
If `reserve_src=true` reserve the `src` node of the edge `ce`, otherwise reserve the `dst`.
"""
function reserve_slots!(sdn::SDNdummy, ce::NestedEdge, sr::UnitRange{Int}, intidx, reserve_src=true)
    gr = getgraph(sdn)
    if ce.src[1] == ce.dst[1]
        e = Edge(ce.src[2], ce.dst[2])
        link = get_prop(gr, e, :link)
    else
        link = sdn.interprops[ce][:link]
    end
    return useslots!(link, sr, intidx, reserve_src)
end

"""$(TYPEDSIGNATURES) 

Free frequency slots `sr` at edge `ce`, connecting to SDNs one of which is `sdn`.
If `reserve_src=true` free the `src` node of the edge `ce`, otherwise free the `dst`.
"""
function free_slots!(sdn::SDNdummy, ce::NestedEdge, sr::UnitRange{Int}, intidx, reserve_src=true)
    gr = getgraph(sdn)
    if ce.src[1] == ce.dst[1]
        e = Edge(ce.src[2], ce.dst[2])
        link = get_prop(gr, e, :link)
    else
        link = sdn.interprops[ce][:link]
    end
    return freeslots!(link, sr, intidx, reserve_src)
end

"""$(TYPEDSIGNATURES) 

Check if edge `ce`, connecting to SDNs one of which is `sdn`, has reserved frequency slots `sr` and stisfies `intidx`.
If `reserve_src=true` check the `src` node of the edge `ce`, otherwise check the `dst`.
"""
function issatisfied_slots!(sdn::SDNdummy, ce::NestedEdge, sr::UnitRange{Int}, intidx, reserve_src=true)
    gr = getgraph(sdn)
    if ce.src[1] == ce.dst[1]
        e = Edge(ce.src[2], ce.dst[2])
        link = get_prop(gr, e, :link)
    else
        link = sdn.interprops[ce][:link]
    end
    if reserve_src
        resvs = link.reservations_src
    else
        resvs = link.reservations_dst
    end
    res = all(x -> x == intidx, resvs[sr])
    ismissing(res) && return false
    return res
end

"$(TYPEDSIGNATURES) Check `capacity` on an intra-SDN edge `e` of SDN `sdn`"
function isavailable(sdn::SDNdummy, e::Edge, capacity::Real)
    mgr = getgraph(sdn)
    rts = [get_prop(mgr, v, :router) for v in [e.src, e.dst]]
    l = get_prop(mgr, e.src, e.dst, :link)
    return hasport(rts[1]) && hasport(rts[2]) && hascapacity(l, capacity)
end

"$(TYPEDSIGNATURES) Check whether path `p` in SDN `sdn` with capacity requirements `capacity` is available."
function isavailable(sdn::SDNdummy, p::Vector{<:Integer}, capacity::Real)
    all(isavailable(sdn, e, capacity) for e in edgeify(p))
end

"$(TYPEDSIGNATURES) Reserve capacity `capacity` on an inter-SDN edge `ce` between `sdn1` and `sdn2`"
function reserve!(sdn1::SDNdummy, sdn2::SDNdummy, ce::NestedEdge, capacity::Real, ceintrasdn=nothing)
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

"$(TYPEDSIGNATURES) Free capacity `capacity` on an inter-SDN edge `ce` between `sdn1` and `sdn2`"
function free!(sdn1::SDNdummy, sdn2::SDNdummy, ce::NestedEdge, capacity::Real)
    mgr1 = getgraph(sdn1)
    mgr2 = getgraph(sdn2)
    rts = [get_prop(mgr, v, :router) for (mgr,v) in zip([mgr1, mgr2],[ce.src[2], ce.dst[2]])]
    l = sdn1.interprops[ce][:link]
    freeport!(rts[1])
    freeport!(rts[2])
    freecapacity!(l, capacity)
    return true
end

"$(TYPEDSIGNATURES) Check if available capacity `capacity` on an inter-SDN edge `ce` between `sdn1` and `sdn2`"
function isavailable(sdn1::SDNdummy, sdn2::SDNdummy, ce::NestedEdge, capacity::Real, ceintrasdn=nothing)
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

"$(TYPEDSIGNATURES)"
function reserve_routerport(sdnd::SDNdummy, ibnintid::Tuple{Int, Int}, node::Int)
    mgr = getgraph(sdnd)
    rt = get_prop(mgr, node, :router)
    return useport!(rt, ibnintid)
end

"$(TYPEDSIGNATURES)"
function reserve!(reservemethod::F, ibnintid::Tuple{Int,Int}, args...; sdn1=nothing, sdn2=nothing, ce=nothing, ceintra=nothing) where F <: Function
    if sdn2 === nothing
        reservemethod(sdn1, ibnintid, ce, args...)
    else
        reservemethod(sdn1, sdn2, ce, ceintra, args...)
    end
end
