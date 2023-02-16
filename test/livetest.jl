using Test
using Graphs, MetaGraphs
using GraphIO, NestedGraphsIO
using MINDFul
using NestedGraphs
using TestSetExtensions
using Logging

using MINDFul: uncompiled, compiled, installed
MINDF = MINDFul

testlogger = ConsoleLogger(stderr, Logging.Error)

testdir =  dirname(@__FILE__)

Base.show(io::IO, ::MIME"text/plain", ibn::IBN) = print(io,"IBN($(ibn.id), $(length(ibn.intents)) intents, $(length(ibn.controllers)) controllers, $(ibn.ngr), $(ibn.interprops))")

globalnet = open(joinpath(testdir,"..", "data","4nets.graphml")) do io
    loadgraph(io, "global-network", GraphMLFormat(), NestedGraphs.NestedGraphFormat())
end
globalnet2 = MINDFul.simgraph(globalnet)

myibns = MINDFul.nestedGraph2IBNs!(globalnet2)
