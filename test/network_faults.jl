using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework
using CompositeGraphs
using TestSetExtensions
using Logging

using IBNFramework: uncompiled, compiled, installed
IBNF = IBNFramework

testlogger = ConsoleLogger(stderr, Logging.Error)

globalnet = loadgraph(open("../data/networksnest2.graphml"), GraphMLFormat(), CompositeGraphs.CompositeGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.compositeGraph2IBNs!(globalnet)

function intentdeployandfault(conint, ibns, ibnidx, edgecontained)
    ibn = ibns[ibnidx]
#    ibnedge = Edge(edgecontained.src[2], edgecontained.dst[2])
    # let's take source (randomly)
    ibnofedge = ibns[edgecontained.src[1]]
    ibnedge = IBNF.localedge(ibnofedge, edgecontained, subnetwork_view=false)
    linktofail = get_prop(ibnofedge.cgr, ibnedge.src, ibnedge.dst, :link)

    intidx = addintent!(ibn, conint);
    deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath_opt!);
    deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!);

    @test getroot(ibn.intents[intidx]).state == IBNF.installed

    glbs, _ = IBNF.logicalorderedintents(ibn, intidx);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa IBNF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test contains_edg

    set_operation_status!(ibnofedge, linktofail, false)
    @test getroot(ibn.intents[intidx]).state == IBNF.failure

    deploy!(ibn, intidx, IBNF.douninstall, IBNF.SimpleIBNModus(), IBNFramework.directuninstall!);
    @test getroot(ibn.intents[intidx]).state == IBNF.compiled

    deploy!(ibn, intidx, IBNF.douncompile, IBNF.SimpleIBNModus(), () -> nothing)
    @test getroot(ibn.intents[intidx]).state == IBNF.uncompiled

    deploy!(ibn, intidx, IBNF.docompile, IBNF.SimpleIBNModus(), IBNF.kshortestpath_opt!)
    @test getroot(ibn.intents[intidx]).state == IBNF.compiled

    deploy!(ibn, intidx, IBNF.doinstall, IBNF.SimpleIBNModus(), IBNF.directinstall!)
    @test getroot(ibn.intents[intidx]).state == IBNF.installed

    glbs, _ = IBNF.logicalorderedintents(ibn, intidx);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa IBNF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test !contains_edg

    set_operation_status!(ibnofedge, linktofail, true)
end

@testset "network_faults.jl" begin
    with_logger(testlogger) do
        # inter SDN, intra IBN intent
        conint = ConnectivityIntent((myibns[1].id,2), (myibns[1].id,7), [CapacityConstraint(5)]);
        edgecontained = CompositeEdge(1,3,1,5)
        intentdeployandfault(conint, myibns[1], edgecontained)

        # inter IBN. intra-IBN edge fails
        conint = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,6), [CapacityConstraint(5)]);
        edgecontained = CompositeEdge(2,3,2,5)
        intentdeployandfault(conint, myibns, 1, edgecontained)

        # inter IBN. inter-IBN edge fails
        conint = ConnectivityIntent((myibns[1].id,4), (myibns[2].id,7), [CapacityConstraint(5)]);
        edgecontained = CompositeEdge(1,9,2,2)
        intentdeployandfault(conint, myibns, 1, edgecontained)

        # inter IBN. inter-IBN edge fails
        conint = ConnectivityIntent((myibns[1].id,4), (myibns[3].id,3), [CapacityConstraint(5)]);
        edgecontained = CompositeEdge(2,4,3,4)
        intentdeployandfault(conint, myibns, 1, edgecontained)
    end
end
