function default_dummyflexibletransponder()
    return TransmissionModuleView(
        TransmissionModuleDummy(),
        "DummyFlexibleTransponder",
        [
            TransmissionMode(u"5080.0km", u"300.0Gbps", 8),
            TransmissionMode(u"4400.0km", u"400.0Gbps", 8),
            TransmissionMode(u"2800.0km", u"500.0Gbps", 8),
            TransmissionMode(u"1200.0km", u"600.0Gbps", 8),
            TransmissionMode(u"700.0km", u"700.0Gbps", 10),
            TransmissionMode(u"400.0km", u"800.0Gbps", 10),
        ],
        20.0
    )
end

function default_dummyflexiblepluggable()
    return TransmissionModuleView(
        TransmissionModuleDummy(),
        "DummyFlexiblePluggable",
        [
            TransmissionMode(u"5840.0km", u"100.0Gbps", 4),
            TransmissionMode(u"2880.0km", u"200.0Gbps", 6),
            TransmissionMode(u"1600.0km", u"300.0Gbps", 6),
            TransmissionMode(u"480.0km", u"400.0Gbps", 6),
        ],
        8.0
    )
end

function shortopticalreach_transmissionmodules(transpondernumber::Int=25, pluggablenumber::Int=25)
    return [ 
    fill( TransmissionModuleView(
            TransmissionModuleDummy(),
            "DummyShortReachPluggable",
            [
                TransmissionMode(u"480.0km", u"400.0Gbps", 6),
            ],
            8.0
        ), pluggablenumber)...
    , fill( TransmissionModuleView( 
            TransmissionModuleDummy(),
        "DummyShortReachTransponder",
        [
            TransmissionMode(u"400.0km", u"800.0Gbps", 10),
        ],
        20.0
        ), transpondernumber)...
    ]
end

function default_transmissionmodules(transpondernumber::Int=25, pluggablenumber::Int=25)
    return [
        fill(default_dummyflexibletransponder(), transpondernumber)...,
        fill(default_dummyflexiblepluggable(), pluggablenumber)...,
    ]
end

function default_routerports()
    return [
        fill(RouterPort(u"100.0Gbps"), 60)...,
        fill(RouterPort(u"400.0Gbps"), 20)...,
        fill(RouterPort(u"700.0Gbps"), 40)...,
        fill(RouterPort(u"1000.0Gbps"), 10)...,
    ]
end

function default_routerview()
    return RouterView(
        RouterDummy(),
        default_routerports(),
        Dict{UUID, RouterPortLLI}(),
        Set{RouterPortLLI}()
    )
end

"""
$(TYPEDSIGNATURES)
"""
function default_OXCview(nodeproperties::NodeProperties, spectrumslots::Int, offsettime=now())
    innei = getinneighbors(nodeproperties)
    outnei = getoutneighbors(nodeproperties)
    localnode = getlocalnode(nodeproperties)
    edgs = Edge{LocalNode}[]
    foreach(innei) do inn
        push!(edgs, Edge(localnode, inn))
        push!(edgs, Edge(inn, localnode))
    end
    foreach(outnei) do outn
        push!(edgs, Edge(localnode, outn))
        push!(edgs, Edge(outn, localnode))
    end
    linkspectrumavailabilities = Dict(ed => fill(true, spectrumslots)  for ed in edgs)
    linkstates = Dict(ed => construct_BoolLogState(offsettime) for ed in edgs)
    return OXCView(OXCDummy(), 50, Dict{UUID, OXCAddDropBypassSpectrumLLI}(), Set{OXCAddDropBypassSpectrumLLI}(), linkspectrumavailabilities, linkstates)
end

function default_nodeview(nodeproperties::NodeProperties, transpondernumber::Int=25, pluggablenumber::Int=25; spectrumslots::Int, isexternal::Bool, offsettime = now(), useshortreachtransmissionmodules=false)
    rv = default_routerview()
    ov = default_OXCview(nodeproperties, spectrumslots, offsettime)
    if useshortreachtransmissionmodules
        tms = shortopticalreach_transmissionmodules(transpondernumber, pluggablenumber)
    else
        tms = default_transmissionmodules(transpondernumber, pluggablenumber)
    end
    if isexternal
        return NodeView{typeof(rv), typeof(ov), eltype(tms)}(nodeproperties, nothing, nothing, nothing, nothing, nothing)
    else
        return NodeView(nodeproperties, rv, ov, tms)
    end
end

function default_IBNAttributeGraph(ag::AG.OAttributeGraph{Int, SimpleDiGraph{Int}, Dict{Symbol}, Dict{Symbol}, Dict{Symbol, Any}}, transpondernumber::Int=25, pluggablenumber::Int=25; offsettime=now(), useshortreachtransmissionmodules=false)
    spectrumslots = AG.graph_attr(ag)[:spectrumslots]
    ibnfid = AG.graph_attr(ag)[:ibnfid]
    extrafielddicts = [Dict(:inneighbors => innei, :outneighbors => outnei) for (innei, outnei) in zip(inneighbors.([ag], vertices(ag)), outneighbors.([ag], vertices(ag))) ]
    nodeviews = [
        let
                isexternal = va[:globalnode_ibnfid] != ibnfid
                default_nodeview(constructfromdict(NodeProperties, va, extrafielddict), transpondernumber, pluggablenumber; spectrumslots, isexternal, offsettime, useshortreachtransmissionmodules)
        end for (va, extrafielddict) in zip(AG.vertex_attr(ag), extrafielddicts)
    ]
    edgeviews = Dict(Edge(k[1], k[2]) => EdgeView(constructfromdict(EdgeProperties, v)) for (k, v) in edge_attr(ag))
    ibnfid = AG.graph_attr(ag)[:ibnfid]
    # return IBNAttributeGraph(AG.getgraph(ag), nodeviews, edgeviews, UUID(ibnfid))
    return AG.AttributeGraph(AG.getgraph(ag), nodeviews, edgeviews, UUID(ibnfid))
end

"""
$(TYPEDSIGNATURES)

Read a multi-domain network from a TOML file and return a `name => attribute graph` pair per domain, as expected by
[`default_IBNAttributeGraph`](@ref).

The file has one `[[domains]]` table per domain with
- `name`, `ibnfid` and `spectrumslots`,
- `nodes`: one row `[localnode, globalnode_ibnfid, globalnode_node, latitude, longitude, label]` per node, in local node order.
  Border nodes are the nodes of other domains (another `globalnode_ibnfid`).
- `fibers`: one row `[src, dst, distance_km]` per fiber, used in both directions.
"""
function loadnetworkfile(networkfile::AbstractString)
    return map(TOML.parsefile(networkfile)["domains"]) do domain
        nodes = domain["nodes"]
        fibers = domain["fibers"]
        graph = SimpleDiGraph(length(nodes))
        for (s, d, _) in fibers
            add_edge!(graph, s, d)
            add_edge!(graph, d, s)
        end
        ag = AG.OAttributeGraph(graph; vertex_type = Dict{Symbol}, edge_type = Dict{Symbol}, graph_type = Dict{Symbol, Any})
        for (i, (localnode, globalnode_ibnfid, globalnode_node, latitude, longitude, label)) in enumerate(nodes)
            @assert localnode == i "the nodes of domain $(domain["name"]) must be listed in local node order"
            push!(AG.vertex_attr(ag), Dict{Symbol, Any}(:localnode => localnode, :globalnode_ibnfid => globalnode_ibnfid, :globalnode_node => globalnode_node, :Latitude => latitude, :Longitude => longitude, :label => label))
        end
        for (s, d, distance) in fibers
            AG.edge_attr(ag)[(s, d, 1)] = Dict{Symbol, Any}(:distance => float(distance))
            AG.edge_attr(ag)[(d, s, 1)] = Dict{Symbol, Any}(:distance => float(distance))
        end
        AG.graph_attr(ag)[:ibnfid] = domain["ibnfid"]
        AG.graph_attr(ag)[:spectrumslots] = domain["spectrumslots"]
        domain["name"] => ag
    end
end
