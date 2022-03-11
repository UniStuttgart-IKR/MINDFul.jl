@testset "readinggraphml.jl" begin
    using EzXML
    using GraphIO
    using Graphs, MetaGraphs

    @testset "readonebyone" begin
        sdn11 = Graphs.loadgraph(open("../data/network.graphml"), "ibn1-sdn1", GraphMLFormat(), MGFormat())
        sdn12 = Graphs.loadgraph(open("../data/network.graphml"), "ibn1-sdn2", GraphMLFormat(), MGFormat())

        ssdn11 = IBNFramework.simgraph(sdn11)
        ssdn12 = IBNFramework.simgraph(sdn12)
    end

    @testset "readalltogether" begin
        grmls = Graphs.loadgraphs(open("../data/network.graphml"), GraphMLFormat(), MGFormat())
    end
end
