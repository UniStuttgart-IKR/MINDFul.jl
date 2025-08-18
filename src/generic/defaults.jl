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

function default_transmissionmodules()
    return [
        fill(default_dummyflexibletransponder(), 25)...,
        fill(default_dummyflexiblepluggable(), 25)...,
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

function default_nodeview(nodeproperties::NodeProperties; spectrumslots::Int, isexternal::Bool, offsettime = now())
    rv = default_routerview()
    ov = default_OXCview(nodeproperties, spectrumslots, offsettime)
    tms = default_transmissionmodules()
    if isexternal
        return NodeView{typeof(rv), typeof(ov), eltype(tms)}(nodeproperties, nothing, nothing, nothing, nothing, nothing)
    else
        return NodeView(nodeproperties, rv, ov, tms)
    end
end

function default_IBNAttributeGraph(ag::AG.OAttributeGraph{Int, SimpleDiGraph{Int}, Dict{Symbol}, Dict{Symbol}, Dict{Symbol, Any}}; offsettime=now())
    spectrumslots = AG.graph_attr(ag)[:spectrumslots]
    ibnfid = AG.graph_attr(ag)[:ibnfid]
    extrafielddicts = [Dict(:inneighbors => innei, :outneighbors => outnei) for (innei, outnei) in zip(inneighbors.([ag], vertices(ag)), outneighbors.([ag], vertices(ag))) ]
    # nodeviews = default_nodeview.(constructfromdict.(NodeProperties, vertex_attr(ag), extrafielddict); spectrumslots)
    nodeviews = [
        let
                isexternal = va[:globalnode_ibnfid] != ibnfid
                default_nodeview(constructfromdict(NodeProperties, va, extrafielddict); spectrumslots, isexternal, offsettime)
        end for (va, extrafielddict) in zip(AG.vertex_attr(ag), extrafielddicts)
    ]
    edgeviews = Dict(Edge(k[1], k[2]) => EdgeView(constructfromdict(EdgeProperties, v)) for (k, v) in edge_attr(ag))
    ibnfid = AG.graph_attr(ag)[:ibnfid]
    # return IBNAttributeGraph(AG.getgraph(ag), nodeviews, edgeviews, UUID(ibnfid))
    return AG.AttributeGraph(AG.getgraph(ag), nodeviews, edgeviews, UUID(ibnfid))
end
