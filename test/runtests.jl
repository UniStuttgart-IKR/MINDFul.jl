using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework
using CompositeGraphs
using TestSetExtensions

@testset ExtendedTestSet "IBNFramework.jl" begin
#    @includetests ["connectivityIntentKshortestPath"]
#    @includetests ["network_faults"]
    @includetests ["connectivityIntentKshortestPath", "network_faults"]
end
