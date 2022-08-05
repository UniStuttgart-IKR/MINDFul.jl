using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework
using NestedGraphs
using TestSetExtensions
using Unitful

include("testutils.jl")

testdir =  dirname(@__FILE__)

@testset ExtendedTestSet "IBNFramework.jl" begin
    # @includetests ["connectivityIntentKshortestPath"]
#    @includetests ["connectivityIntentKshortestPath"]
#    @includetests ["GoThroughConstraintsConnectivity"]
     @includetests ["connectivityIntentKshortestPath", "network_faults"]
end
