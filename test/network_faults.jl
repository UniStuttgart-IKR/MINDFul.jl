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

testlogger = ConsoleLogger(stderr, Logging.Error)

testdir =  dirname(@__FILE__)
globalnet0 = loadgraph(open(joinpath(testdir,"..", "data","4nets.graphml")), GraphMLFormat(), NestedGraphs.NestedGraphFormat())
globalnet = IBNFramework.simgraph(globalnet0)

myibns = IBNFramework.nestedGraph2IBNs!(globalnet)

# useless
ibnenv = IBNEnv(myibns, globalnet2)

@testset "network_faults.jl" begin
    with_logger(testlogger) do
        # inter SDN, intra IBN intent
        conint = ConnectivityIntent((myibns[1].id,2), (myibns[1].id,7), [CapacityConstraint(5)]);
        edgecontained = NestedEdge(1,3,1,5)
        intentdeployandfault(conint, myibns, 1, edgecontained)

        # inter IBN. intra-IBN edge fails
        conint = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,6), [CapacityConstraint(5)]);
        edgecontained = NestedEdge(2,3,2,5)
        intentdeployandfault(conint, myibns, 1, edgecontained)

        # inter IBN. inter-IBN edge fails
        conint = ConnectivityIntent((myibns[1].id,4), (myibns[2].id,7), [CapacityConstraint(5)]);
        edgecontained = NestedEdge(1,9,2,2)
        intentdeployandfault(conint, myibns, 1, edgecontained)

        # inter IBN. inter-IBN edge fails
        conint = ConnectivityIntent((myibns[1].id,4), (myibns[3].id,3), [CapacityConstraint(5)]);
        edgecontained = NestedEdge(2,4,3,4)
        intentdeployandfault(conint, myibns, 1, edgecontained)
    end
end
