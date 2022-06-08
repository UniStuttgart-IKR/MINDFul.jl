using Revise
using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework, DrawIBNFramework
using CompositeGraphs
using TestSetExtensions
using GraphMakie
using GLMakie
using UUIDs
using Unitful

import MetaGraphsNext
MGN = MetaGraphsNext
IBNF = IBNFramework

using Logging

globalnet = loadgraph(open("../data/networksnest2.graphml"), GraphMLFormat(), CompositeGraphs.CompositeGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.compositeGraph2IBNs!(globalnet)

function intentdeploy(conint, ibn)
    intidx = addintent!(ibn, conint);
    deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath_opt!);
    deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!);
    return intidx
end

function intentdeployandfault(conint, ibns, ibnidx, edgecontained)
    ibn = ibns[ibnidx]
    ibnedge = Edge(edgecontained.src[2], edgecontained.dst[2])
    ibnofedge = ibns[edgecontained.src[1]]

    intidx = addintent!(ibn, conint);
    deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath_opt!);
    deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!);

    @test getroot(ibn.intents[intidx]).state == IBNF.installed

    glbs, _ = IBNF.logicalorderedintents(ibn, intidx);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa IBNF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test contains_edg

#    set_operation_status!(ibn, get_prop(ibnofedge.cgr, ibnedge.src, ibnedge.dst, :link), false)
#    @test getroot(ibn.intents[intidx]).state == IBNF.failure
#
#    deploy!(ibn, intidx, IBNF.douninstall, IBNF.SimpleIBNModus(), IBNFramework.directuninstall!);
#    @test getroot(ibn.intents[intidx]).state == IBNF.compiled
#
#    deploy!(ibn, intidx, IBNF.douncompile, IBNF.SimpleIBNModus(), () -> nothing)
#    @test getroot(ibn.intents[intidx]).state == IBNF.uncompiled
#
#    deploy!(ibn, intidx, IBNF.docompile, IBNF.SimpleIBNModus(), IBNF.kshortestpath_opt!)
#    @test getroot(ibn.intents[intidx]).state == IBNF.compiled
#
#    deploy!(ibn, intidx, IBNF.doinstall, IBNF.SimpleIBNModus(), IBNF.directinstall!)
#    @test getroot(ibn.intents[intidx]).state == IBNF.installed
#
#    glbs, _ = IBNF.logicalorderedintents(ibn, intidx);
#    contains_edg = edgecontained in 
#        getfield.(filter(x -> x isa IBNF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
#    @test !contains_edg
#
#    set_operation_status!(ibn, get_prop(ibnofedge.cgr, ibnedge.src, ibnedge.dst,:link), true)
end

# inter SDN, intra IBN intent
conint = ConnectivityIntent((myibns[1].id,4), (myibns[3].id,3), [CapacityConstraint(5)]);
edgecontained = CompositeEdge(2,4,3,4)
intentdeployandfault(conint, myibns, 1, edgecontained)
