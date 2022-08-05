using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework
using NestedGraphs
using TestSetExtensions
using Logging

using IBNFramework: uncompiled, compiled, installed
IBNF = IBNFramework

resetIBNF!()
testlogger = ConsoleLogger(stderr, Logging.Error)

globalnet = loadgraph(open("../data/networksnest2.graphml"), GraphMLFormat(), NestedGraphs.NestedGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.nestedGraph2IBNs!(globalnet)


function capacity_N_gothrough(myibns, ibn1idx, ibn1node, ibn2idx, ibn2node, ibnIssueidx, gothroughnode)
    conint = ConnectivityIntent((myibns[ibn1idx].id, ibn1node), 
                                (myibns[ibn2idx].id, ibn2node), 
                                [CapacityConstraint(5), GoThroughConstraint(gothroughnode)]);
    testintentdeployment(conint, myibns[ibnIssueidx])
end

@testset "connectivityIntentsKshortestPath.jl" begin
    with_logger(testlogger) do

        intenttuples = [
        # intra SDN, intra IBN intent
        (1, 1, 1, 3, 1, (1,2)),
        (1, 1, 1, 3, 1, (1,4)),
        (1, 1, 1, 3, 1, (1,8)),

        # inter SDN, intra IBN intent
        (1, 2, 1, 7, 1, (1,2)),
        (1, 2, 1, 7, 1, (1,3)),

        # inter IBN Intent: src the IBN, destination edge node known
        (1, 2, 2, 1, 1, (1,5)),
        (1, 2, 2, 1, 1, (1,8)),

        # inter IBN Intent: src the IBN, destination known
        (1, 2, 2, 3, 1, (1,5)),
        (1, 2, 2, 3, 1, (1,8)),
        # go through edge nodes
        (1, 2, 2, 3, 1, (2,1)),
        (1, 2, 2, 3, 1, (2,2)),

        # inter IBN Intent: src the IBN, destination unknown
        (1, 1, 3, 1, 1, (1,5)),
        (1, 1, 3, 1, 1, (1,8)),
        # go through edge nodes
        (1, 1, 3, 1, 1, (2,1)),
        (1, 1, 3, 1, 1, (2,2)),

        # inter IBN Intent: src known, destination the IBN
        (2, 3, 1, 1, 1, (1,5)),
        (2, 3, 1, 1, 1, (1,8)),
        # go through edge nodes
        (2, 3, 1, 1, 1, (2,1)),
        (2, 3, 1, 1, 1, (2,2)),
        # go through outside by ibn
        # doesn't work
#        (2, 3, 1, 1, 1, (2,4)),

#        # inter IBN Intent: src known, destination edge node known
#        (2, 3, 3, 7, 1),
#        # inter IBN Intent: src known, destination edge node known (my)
#        (2, 6, 1, 6, 1),
#        # inter IBN Intent: src known, destination known (not passing through)
#        (2, 3, 3, 1, 1),
#        # inter IBN Intent: src known, destination known (passing through)
#        (1, 3, 3, 1, 2),
#        # inter IBN Intent: src known, destination unknown
#        (2, 3, 3, 1, 1),
#        # inter IBN Intent: src unknown, destination the IBN
#        (3, 6, 1, 1, 1),
#        # inter IBN Intent: src unknown, destination known 
#        (3, 1, 2, 3, 1),
#        # inter IBN Intent: src unknown, destination unknown 
#        (3, 1, 3, 6, 1)
        ]

        for intenttuple in intenttuples
                capacity_N_gothrough(myibns, intenttuple...) 
        end

#        capacity_N_gothrough(myibns, intenttuples[1]..., gothroughvertices[2])
    end
end
