using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using MINDFul
using NestedGraphs
using TestSetExtensions
using Unitful

include("testutils.jl")

testdir =  dirname(@__FILE__)

@testset ExtendedTestSet "MINDFul.jl" begin
     @includetests ["connectivityIntentKshortestPath", "network_faults"]
end
