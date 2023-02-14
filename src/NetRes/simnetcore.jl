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

defaultlinecard1() = LineCardDummy(10, 100, 26.72)
defaultlinecard2() = LineCardDummy(2, 400, 29.36)
defaultlinecard3() = LineCardDummy(1, 1000, 31.99)
availablelinecards() = [defaultlinecard1(), defaultlinecard2(), defaultlinecard3()]

""" $(TYPEDEF)
$(TYPEDFIELDS)
"""
struct LineCardChassisDummy
    lcs::Vector{LineCardDummy}
    cost::Float64
    lcscap::Int
end
defaultlinecardchassis() = LineCardChassisDummy(Vector{LineCardDummy}(), 4.7, 16)
availablelinecardchassis() = [defaultlinecardchassis()]

"""
$(TYPEDEF)
$(TYPEDFIELDS)
"""
struct RouterModularDummy
    lccs::Vector{LineCardChassisDummy}
    "maps sequence of ports a specific port of a specific linecard of a specific line card chassis"
    portmap::Vector{Tuple{Int, Int, Int}}
    lcccap::Int
end

islinecardchassisfull(rmd::RouterModularDummy) = all(lcc -> length(lcc.lcs)==lcc.lcscap,rmd.lccs)
isrouterfull(rmd::RouterModularDummy) = length(rmd.lccs) == rmd.lcccap

"$(TYPEDSIGNATURES) RouterModularDummy increamentally adds up infinite ports"
hasport(rv::RouterView{RouterModularDummy}) = any(rv.portavailability) || !islinecardchassisfull(rv.router) || !isrouterfull(rv.router)

RouterModularDummy() = RouterModularDummy(Vector{LineCardChassisDummy}(), Vector{Tuple{Int, Int, Int}}(), 3)

"$(TYPEDSIGNATURES) Add default line card chassis  on router `rmd`"
function addlinecardchassis!(rmd::RouterModularDummy)
    if length(rmd.lccs) < rmd.lcccap
        push!(rmd.lccs, defaultlinecardchassis())
    else
        nothing
    end
end

"$(TYPEDSIGNATURES) Add linecard `lc` at line card chassis `lcci` on router `rmd`"
function addlinecard!(rmd::RouterModularDummy, lcci::Int, lc::LineCardDummy)
    lcc = rmd.lccs[lcci]
    if length(lcc.lcs) < lcc.lcscap
        push!(lcc.lcs, lc)
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
            push!(lcc.lcs, lc)
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
function getportusagecost(rv::RouterView{RouterModularDummy}, r::Number; availablelinecards=availablelinecards(), availablelinecardchassis=availablelinecardchassis())
    cost = zero(r)
    hasport(rv, r) && return cost
    if islinecardchassisfull(rv.router)
        cost += minimum(lcc -> lcc.cost,availablelinecardchassis)
    end
    cost += minimum(lc -> lc.cost ,filter(lc -> lc.rate > r,availablelinecards))
    return cost
end

"$(TYPEDSIGNATURES) Finds port with cheapest alternative"
function useport!(rv::RouterView{RouterModularDummy}, r::Number, ibnintid::Tuple{Int,Int,UUID}; availablelinecards=availablelinecards(), availablelinecardchassis=availablelinecardchassis())
    ff = findfirst(k -> rv.portavailability[k] && getportrate(rv,k) > r, keys(rv.portavailability))
    if ff !== nothing
        rv.portavailability[ff] = false
        rv.reservations[ff] = ibnintid
        return true
    else
        if isrouterfull(rv.router)
            return false
        else
            compliantlcs = filter(lc -> lc.rate > r,availablelinecards)
            chosenlinecardidx = findmin(lc -> lc.cost , compliantlcs)[2]
            addlinecard!(rv, compliantlcs[chosenlinecardidx])
            useport!(rv, r, ibnintid; availablelinecards, availablelinecardchassis)
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
getrate(tr::TransmissionModuleDummy) = tr.transmodes[tr.selected].rate
getoptreach(tr::TransmissionModuleDummy) = tr.transmodes[tr.selected].optreach
getfreqslots(tr::TransmissionModuleDummy) = tr.transmodes[tr.selected].freqslots
getcost(tr::TransmissionModuleDummy) = tr.cost
gettransmissionmodes(tr::TransmissionModuleDummy) = tr.transmodes
getselection(tr::TransmissionModuleDummy) = tr.selected
setselection!(tr::TransmissionModuleDummy, s::Int) = setfield!(tr, :selected, s)
 
# tdlt
transponderset() = [TransmissionModuleView("DummyFlexibleTransponder",
            TransmissionModuleDummy([TransmissionProps(5080.0u"km", 300, 8),
            TransmissionProps(4400.0u"km", 400, 8),
            TransmissionProps(2800.0u"km", 500, 8),
            TransmissionProps(1200.0u"km", 600, 8),
            TransmissionProps(700.0u"km", 700, 10),
            TransmissionProps(400.0u"km", 800, 10)],0,20)),
                                            TransmissionModuleView("DummyFlexiblePluggables",
            TransmissionModuleDummy([TransmissionProps(5840.0u"km", 100, 4),
            TransmissionProps(2880.0u"km", 200, 6),
            TransmissionProps(1600.0u"km", 300, 6),
            TransmissionProps(480.0u"km", 400, 6)],0,8))
           ]
 
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

randomgraph(gr::DiGraph) = randomgraph(MetaDiGraph(gr))
"$(TYPEDSIGNATURES) Get a random graph able to simulate"
function randomsimgraph!(mgr::MetaDiGraph)
    for v in vertices(mgr)
        set_prop!(mgr, v, :router, RouterDummy(rand(10:20)) )
    end
    for e in edges(MetaGraph(mgr))
        ralength = rand(50:200)
        set_prop!(mgr, e, :link, LinkDummy(ralength , 100) )
        set_prop!(mgr, reverse(e), :link, LinkDummy(ralength , 100) )
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
        set_prop!(simgr, v, :mlnode, 
#                  MLNode(RouterView(RouterDummy(get_prop(mgr, v, :routerports))), OTNView(), OXCView(), transponderset(), 0))
                  MLNode(RouterView(RouterModularDummy()), OTNView(), OXCView(), transponderset()))
        set_prop!(simgr, v, :xcoord, get_prop(mgr, v, :xcoord))
        set_prop!(simgr, v, :ycoord, get_prop(mgr, v, :ycoord))
        has_prop(mgr, v, :name) && set_prop!(simgr, v, :name, get_prop(mgr, v, :name))
    end
    for e in edges(MetaGraph(mgr))
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
        set_prop!(cgnew, edge(cgnew, interedgs), :link, 
                  FiberView(FiberDummy(distance), frequency_slots=get_prop(ng, edge(ng, interedgs), :fiberslots)) )
    end
    return cgnew
end

function linklengthweights(mgr::AbstractMetaGraph)
    ws = zeros(Float64 ,nv(mgr),nv(mgr))
    for e in edges(mgr)
        ws[e.src, e.dst] = uconvert(u"km", getdistance(get_prop(mgr, e, :link))) |> ustrip
    end
    ws
end
