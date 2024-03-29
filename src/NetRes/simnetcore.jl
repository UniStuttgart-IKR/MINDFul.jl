#=
# Simulating the Physical Layer
=#

"""
Router nodes

    $(TYPEDFIELDS)
"""
struct RouterDummy
    "Available ports needed to attach a fiber link"
    nports::Int
end
getports(rt::RouterDummy) = rt.nports

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct LineCardDummy
    "number of ports"
    ports::Int
    "Gbps"
    rate::Float64
    "cost"
    cost::Float64
end

""" $(TYPEDEF)
$(TYPEDFIELDS)
"""
struct LineCardChassisDummy
    lcs::Vector{LineCardDummy}
    cost::Float64
    lcscap::Int
end

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct RouterModularDummy
    lccs::Vector{LineCardChassisDummy}
    "maps sequence of ports a specific port of a specific linecard of a specific line card chassis"
    portmap::Vector{Tuple{Int, Int, Int}}
    linecardpool::Vector{LineCardDummy}
    linecardchassispool::Vector{LineCardChassisDummy}
    lcccap::Int
end

islinecardchassisfull(rmd::RouterModularDummy) = all(lcc -> length(lcc.lcs)==lcc.lcscap,rmd.lccs)
isrouterfull(rmd::RouterModularDummy) = length(rmd.lccs) == rmd.lcccap
isrouterlinecardfull(rmd::RouterModularDummy) = all([length(lcc.lcs) == lcc.lcscap for lcc in rmd.lccs]) && isrouterfull(rmd)
getlinecardnum(rmd::RouterModularDummy) = sum([length(lcc.lcs) for lcc in rmd.lccs] ;init=0)

"$(TYPEDSIGNATURES) RouterModularDummy increamentally adds up infinite ports"
hasport(rv::RouterView{RouterModularDummy}) = any(rv.portavailability) || !islinecardchassisfull(rv.router) || !isrouterfull(rv.router)

RouterModularDummy(lcpool, lccpool, lcccap=3) = RouterModularDummy(Vector{LineCardChassisDummy}(), Vector{Tuple{Int, Int, Int}}(), lcpool, lccpool, lcccap)

function gettotalcost(rmd::RouterModularDummy)
    lcccost = sum([lcc.cost for lcc in rmd.lccs]; init=0)
    lccost = sum([lc.cost for lcc in rmd.lccs for lc in lcc.lcs]; init=0)
    return lcccost + lccost
end

function getportcost(rmd::RouterModularDummy, p::Integer)
    lcc = rmd.lccs[rmd.portmap[p][1]]
    lc = lcc.lcs[rmd.portmap[p][2]]
    linecardcost = lc.cost / lc.ports
    linecardchassiscost = lcc.cost / lcc.lcscap
    return linecardcost + linecardchassiscost
end


"$(TYPEDSIGNATURES) Add default line card chassis  on router `rmd`"
function addlinecardchassis!(rmd::RouterModularDummy, lcc=nothing)
    if length(rmd.lccs) < rmd.lcccap
        if isnothing(lcc)
            push!(rmd.lccs, deepcopy(first(rmd.linecardchassispool)))
        else
            push!(rmd.lccs, lcc)
        end
    else
        nothing
    end
end

"$(TYPEDSIGNATURES) Add linecard `lc` at line card chassis `lcci` on router `rmd`"
function addlinecard!(rmd::RouterModularDummy, lcci::Int, lc::LineCardDummy)
    lcc = rmd.lccs[lcci]
    if length(lcc.lcs) < lcc.lcscap
        push!(lcc.lcs, deepcopy(lc))
        push!(rmd.portmap, [(lcci, length(lcc.lcs), i) for i in 1:lc.ports]...)
        return lc.ports
    else
        return nothing
    end
end

"$(TYPEDSIGNATURES) Add linecard `lc` on router `rmd` at first line card chassis available. If non available add new line card chassis."
function addlinecard!(rmd::RouterModularDummy, lc::LineCardDummy)
    for (lcci,lcc) in enumerate(rmd.lccs)
        if length(lcc.lcs) < lcc.lcscap
            push!(lcc.lcs, deepcopy(lc))
            push!(rmd.portmap, [(lcci, length(lcc.lcs), i) for i in 1:lc.ports]...)
            return lc.ports
        end
    end
    if length(rmd.lccs) < rmd.lcccap 
        addlinecardchassis!(rmd)
        addlinecard!(rmd, length(rmd.lccs), lc)
    end
end
getportrate(rmd::RouterModularDummy, p::Int) = rmd.lccs[rmd.portmap[p][1]].lcs[rmd.portmap[p][2]].rate

"$(TYPEDSIGNATURES) Calculates cheapest alternative"
function getportusagecost(rv::RouterView{RouterModularDummy}, r::Number)
    cost = zero(r)
    hasport(rv, r) && return cost
    if islinecardchassisfull(rv.router)
        cost += minimum(lcc -> lcc.cost,rv.router.linecardchassispool)
    end
    cost += minimum(lc -> lc.cost ,filter(lc -> lc.rate > r,rv.router.linecardpool))
    return cost
end

"$(TYPEDSIGNATURES) Finds port with cheapest alternative"
function useport!(rv::RouterView{RouterModularDummy}, r::Number, ibnintid::Tuple{Int,UUID}) 
    ff = findfirst(k -> rv.portavailability[k] && getportrate(rv,k) >= r, keys(rv.portavailability))
    if ff !== nothing
        rv.portavailability[ff] = false
        rv.reservations[ff] = ibnintid
        return true
    else
        if isrouterlinecardfull(rv.router)
            return false
        else
            compliantlcs = filter(lc -> lc.rate >= r, rv.router.linecardpool)
            chosenlinecardidx = findmin(lc -> lc.cost , compliantlcs)[2]
            addlinecard!(rv, compliantlcs[chosenlinecardidx])
            useport!(rv, r, ibnintid)
        end
    end
end

"""
$(TYPEDSIGNATURES) 

Return what the minimum cost would be to add a new linecard out of `lcs` that at least support `rt` rate.
If there is no space for linecards calculate cost including adding a new line card chassic `lcc`.
Return also the chosen linecard for this cost.
If also no linecard chassis fit, return `nothing`.
"""
function newlinecardcost(rmd::RouterModularDummy, rt::Float64, lcs::Vector{LineCardDummy}, lcc::LineCardChassisDummy)
    chosenlcidx = findfirst(x -> x.rate >= rt ,sort!(lcs, by = x -> x.rate))
    chosenlc = lcs[chosenlcidx]
    for lcc in rmd.lccs
        length(lcc.lcs) < lcc.lcscap && return (chosenlc.cost, chosenlc)
    end
    length(rmd.lccs) < rmd.lcccap && return (chosenlc.cost + lcc.cost, chosenlc)
    return nothing
end

"""
Dummy transmission module

    $(TYPEDFIELDS)
"""
mutable struct TransmissionModuleDummy
    transmodes::Vector{TransmissionProps}
    "The selected mode of the transmission module. `0` means nothing is still selected. Non elastic modules can have only `1`."
    selected::Int
    "Cost of the transmission module (in unit costs)"
    cost::Float64
end
issimilar(tmd1::TransmissionModuleDummy, tmd2::TransmissionModuleDummy) = Base.isequal(tmd1.transmodes, tmd2.transmodes) && Base.isequal(tmd1.cost, tmd2.cost)
iscompatible(tmd1::TransmissionModuleDummy, tmd2::TransmissionModuleDummy) = getmode(tmd1) in tmd2.transmodes
getrate(tr::TransmissionModuleDummy) = tr.transmodes[tr.selected].rate
getoptreach(tr::TransmissionModuleDummy) = tr.transmodes[tr.selected].optreach
getfreqslots(tr::TransmissionModuleDummy) = tr.transmodes[tr.selected].freqslots
getmode(tr::TransmissionModuleDummy) = tr.transmodes[tr.selected]
getcost(tr::TransmissionModuleDummy) = tr.cost
gettransmissionmodes(tr::TransmissionModuleDummy) = tr.transmodes
getselection(tr::TransmissionModuleDummy) = tr.selected
setselection!(tr::TransmissionModuleDummy, s::Int) = setfield!(tr, :selected, s)
 
"""
Fiber link connecting routers

    $(TYPEDFIELDS)
"""
struct FiberDummy
    "Length of link"
    distance::typeof(1.0u"km")
    # TODO fibertype
end
FiberDummy(len::Real) = FiberDummy(len*1.0u"km")
getdistance(f::FiberDummy) = f.distance

"""
Fiber link connecting routers

    $(TYPEDFIELDS)
"""
mutable struct LinkDummy
    "Length of link"
    length::typeof(1.0u"km")
    "Available capacity in the link"
    capacity::Float64
    "Already reserver capacity"
    rezcapacity::Float64
end
Base.show(io::IO, l::LinkDummy) = print(io, "$(l.length), $(l.rezcapacity)/$(l.capacity)")
Base.show(io::IO, ::MIME"text/plain", l::LinkDummy) = Base.show(io, l)
LinkDummy(len::Real, cap::Real) = LinkDummy(len*1.0u"km", convert(Float64, cap), 0.0)
hascapacity(l::LinkDummy, cap::Real) = l.capacity - l.rezcapacity > cap
usecapacity!(l::LinkDummy, cap::Real) = hascapacity(l, cap) ? l.rezcapacity += cap : error("No more capacity on the Link ", l)
freecapacity!(l::LinkDummy, cap::Real) = l.rezcapacity - cap > 0 ? l.rezcapacity -= cap : l.rezcapacity = 0

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
function simgraph(mgr::MG.MetaDiGraph; router_lcpool, router_lccpool, router_lcccap, transponderset, distance_method=euclidean_dist)
    simgr = MG.MetaDiGraph(mgr)
    for v in vertices(mgr)
        set_prop!(simgr, v, :mlnode, 
#                  MLNode(RouterView(RouterDummy(get_prop(mgr, v, :routerports))), OTNView(), OXCView(), transponderset(), 0))
                  MLNode(RouterView(RouterModularDummy(router_lcpool, router_lccpool, router_lcccap)), OTNView(), OXCView(), transponderset ))
        set_prop!(simgr, v, :xcoord, get_prop(mgr, v, :xcoord))
        set_prop!(simgr, v, :ycoord, get_prop(mgr, v, :ycoord))
        has_prop(mgr, v, :name) && set_prop!(simgr, v, :name, get_prop(mgr, v, :name))
    end
    for e in edges(MG.MetaGraph(mgr))
        #calculate distance
        possrc = [get_prop(mgr, e.src, :xcoord), get_prop(mgr, e.src, :ycoord)]
        posdst = [get_prop(mgr, e.dst, :xcoord), get_prop(mgr, e.dst, :ycoord)]
        distance = distance_method(possrc, posdst)

        set_prop!(simgr, e, :link, FiberView(FiberDummy(distance); frequency_slots=get_prop(mgr, e, :fiberslots)) )
        set_prop!(simgr, reverse(e), :link, FiberView(FiberDummy(distance); frequency_slots=get_prop(mgr, e, :fiberslots)) )
    end
    return simgr
end
euclidean_dist(possrc, posdst) = sqrt(sum((possrc .- posdst) .^ 2))
geodesic_dist(possrc, posdst) = haversine(possrc, posdst, EARTH_RADIUS)

"""
$(TYPEDSIGNATURES) 

Builds a nested graph from `ng` able to simulate.
"""
function simgraph(ng::G; router_lcpool, router_lccpool, router_lcccap, transponderset, distance_method=euclidean_dist) where G<:NestedGraph
    cgnew = G(;extrasubgraph=false)
    for gr in ng.grv
        add_vertex!(cgnew, simgraph(gr; router_lcpool, router_lccpool, router_lcccap, transponderset ,distance_method))
    end
    for interedgs in ng.neds
        add_edge!(cgnew, interedgs)
        possrc = [get_prop(cgnew, vertex(cgnew, interedgs.src...), :xcoord), get_prop(cgnew, vertex(cgnew, interedgs.src...), :ycoord)]
        posdst = [get_prop(cgnew, vertex(cgnew, interedgs.dst...), :xcoord), get_prop(cgnew, vertex(cgnew, interedgs.dst...), :ycoord)]
        distance = distance_method(possrc, posdst)
        set_prop!(cgnew, edge(cgnew, interedgs), :link, 
                  FiberView(FiberDummy(distance), frequency_slots=get_prop(ng, edge(ng, interedgs), :fiberslots)) )
    end
    return cgnew
end

linklengthweights(ibn::IBN) = linklengthweights(getgraph(ibn))
function linklengthweights(mgr::MG.AbstractMetaGraph)
    ws = zeros(Float64 ,nv(mgr),nv(mgr))
    for e in edges(mgr)
        ws[e.src, e.dst] = uconvert(u"km", getdistance(get_prop(mgr, e, :link))) |> ustrip
    end
    ws
end
