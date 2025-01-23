function default_dummyflexibletransponder()
    return TransmissionModuleView(
        TransmissionModuleDummy(),
        "DummyFlexibleTransponder",
        [
            TransmissionMode(5080.0, 300, 8),
            TransmissionMode(4400.0, 400, 8),
            TransmissionMode(2800.0, 500, 8),
            TransmissionMode(1200.0, 600, 8),
            TransmissionMode(700.0, 700, 10),
            TransmissionMode(400.0, 800, 10)
        ],
        20.0)
end

function default_dummyflexiblepluggable()
    return TransmissionModuleView(
        TransmissionModuleDummy(),
        "DummyFlexiblePluggables",
        [
            TransmissionMode(5840.0, 100, 4),
            TransmissionMode(2880.0, 200, 6),
            TransmissionMode(1600.0, 300, 6),
            TransmissionMode(480.0, 400, 6)
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
function default_OXCview() 
    return OXCView(OXCDummy(), 50, Dict{UUID, OXCAddDropBypassSpectrumLLI}())
end

function default_nodeview(nodeproperties::NodeProperties)
    return NodeView(nodeproperties, default_routerview(), default_OXCview(), default_transmissionmodules())
end

function default_IBNAttributeGraph(ag::AG.OAttributeGraph{Int, SimpleDiGraph{Int}, Dict{Symbol}, Dict{Symbol}, Dict{Symbol,Any}})
    extrafielddict = [Dict(:inneighbors => innei, :outneighbors => outnei) for (innei, outnei) in zip(inneighbors.([ag], vertices(ag)), outneighbors.([ag], vertices(ag))) ]
    nodeviews = default_nodeview.(constructfromdict.(NodeProperties, vertex_attr(ag), extrafielddict))
    edgeviews = Dict(Edge(k[1], k[2]) => EdgeView(constructfromdict(EdgeProperties, v)) for (k,v) in edge_attr(ag))
    ibnfid = AG.graph_attr(ag)[:ibnfid]
    return IBNAttributeGraph(AG.getgraph(ag), nodeviews, edgeviews, UUID(ibnfid))
end
