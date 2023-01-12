using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO, NestedGraphsIO
using MINDFul
using NestedGraphs
using TestSetExtensions
using Logging

using MINDFul: uncompiled, compiled, installed
MINDF = MINDFul

testlogger = ConsoleLogger(stderr, Logging.Error)

testdir =  dirname(@__FILE__)
globalnet = open(joinpath(testdir,"..", "data","4nets.graphml")) do io
    loadgraph(io, "global-network", GraphMLFormat(), NestedGraphs.NestedGraphFormat())
end
globalnet2 = MINDFul.simgraph(globalnet)

myibns = MINDFul.nestedGraph2IBNs!(globalnet2)

# useless
ibnenv = IBNEnv(myibns, globalnet2)
