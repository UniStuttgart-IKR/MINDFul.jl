using Test
using Graphs, MetaGraphs, NestedGraphs
using GraphIO, NestedGraphsIO
using MINDFul
using TestSetExtensions
using Unitful
using Logging
using MINDFul: uncompiled, compiled, installed
MINDF = MINDFul
testlogger = ConsoleLogger(stderr, Logging.Error)

include("testutils.jl")

testdir =  dirname(@__FILE__)

@testset ExtendedTestSet "MINDFul.jl" begin
     @includetests ["connectivityIntentKshortestPath", "network_faults"]
end
