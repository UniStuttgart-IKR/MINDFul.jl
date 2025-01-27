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
            TransmissionMode(u"400.0km", u"800.0Gbps", 10)
        ],
        20.0)
end

function default_dummyflexiblepluggable()
    return TransmissionModuleView(
        TransmissionModuleDummy(),
        "DummyFlexiblePluggables",
        [
            TransmissionMode(u"5840.0km", u"100.0Gbps", 4),
            TransmissionMode(u"2880.0km", u"200.0Gbps", 6),
            TransmissionMode(u"1600.0km", u"300.0Gbps", 6),
            TransmissionMode(u"480.0km", u"400.0Gbps", 6)
        ],
        8.0)
end

function default_transmissionmodules() 
    return[
        fill(default_dummyflexibletransponder(), 25)...,
        fill(default_dummyflexiblepluggable(), 25)...
    ]
end

function default_routerview() 
    return RouterView(
        RouterDummy(),
        50,
        Dict{UUID, RouterPortLLI}())
end

"""
$(TYPEDSIGNATURES)
"""
function default_OXCview(nodeproperties::NodeProperties, spectrumslots::Int) 
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
    return OXCView(OXCDummy(), 50, Dict{UUID, OXCAddDropBypassSpectrumLLI}(), linkspectrumavailabilities)
end

function default_nodeview(nodeproperties::NodeProperties; spectrumslots::Int)
    return NodeView(nodeproperties, default_routerview(), default_OXCview(nodeproperties, spectrumslots), default_transmissionmodules())
end

function default_IBNAttributeGraph(ag::AG.OAttributeGraph{Int, SimpleDiGraph{Int}, Dict{Symbol}, Dict{Symbol}, Dict{Symbol,Any}})
    spectrumslots = AG.graph_attr(ag)[:spectrumslots]
    extrafielddict = [Dict(:inneighbors => innei, :outneighbors => outnei) for (innei, outnei) in zip(inneighbors.([ag], vertices(ag)), outneighbors.([ag], vertices(ag))) ]
    nodeviews = default_nodeview.(constructfromdict.(NodeProperties, vertex_attr(ag), extrafielddict); spectrumslots)
    edgeviews = Dict(Edge(k[1], k[2]) => EdgeView(constructfromdict(EdgeProperties, v)) for (k,v) in edge_attr(ag))
    ibnfid = AG.graph_attr(ag)[:ibnfid]
    return IBNAttributeGraph(AG.getgraph(ag), nodeviews, edgeviews, UUID(ibnfid))
end
