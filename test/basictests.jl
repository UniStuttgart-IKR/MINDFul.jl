@testset "basictests.jl" begin
    grmls = Graphs.loadgraphs(open("../data/network.graphml"), GraphMLFormat(), MGFormat())
    sdnds = SDNdummy.(IBNFramework.simgraph.(values(grmls)))

    ee1 = [CompositeEdge((1,3),(2,1)), CompositeEdge(1,4,2,4)]
    ee2 = [CompositeEdge((1,3),(2,1)), CompositeEdge((1,4), (2,3))]
    netcounter = Counter()
    ibn1 = IBNFramework.IBN!(netcounter,[sdnds[1], sdnds[2]], ee1)
    #ibn1 = IBNFramework.IBN!(netcounter,Vector{Union{SDNdummy, IBN}}([sdnd11, sdnd12]), ee1)
    ibn2 = IBNFramework.IBN!(netcounter,[sdnds[3], sdnds[4]], ee2)

    conint1 = ConnectivityIntent((ibn1.id,3), (ibn1.id,5), [CapacityConstraint(15)])
    intidx1 = addintent(ibn1, conint1)
    s = IBNFramework.step!(ibn1,intidx1, IBNFramework.InstallIntent(), IBNFramework.SimpleIBNModus())

    @test IBNFramework.state(ibn1.intents[1]) == IBNFramework.InstalledIntent()
    @test IBNFramework.compilation(ibn1.intents[1]) isa IBNFramework.ConnectivityIntentCompilation

    conint2 = ConnectivityIntent((ibn2.id,1), (ibn2.id,7), [CapacityConstraint(50)])
    intidx2 = addintent(ibn2, conint2)
    s = IBNFramework.step!(ibn2,intidx2, IBNFramework.InstallIntent(), IBNFramework.SimpleIBNModus())

    @test try CompositeGraph([ibn1.cgr, ibn2.cgr], [CompositeEdge((1,2),(2,3)), CompositeEdge(1,4,2,7)])
        true
    catch
        false
    end

    @test [Edge(cg.vmap[e.src][2],cg.vmap[e.dst][2] ) for e in edges(cg) if cg.vmap[e.src][1] == 1 && cg.vmap[e.dst][1] == 1] == collect(edges(cg.grv[1]))
    @test [Edge(cg.vmap[e.src][2],cg.vmap[e.dst][2] ) for e in edges(cg) if cg.vmap[e.src][1] == 2 && cg.vmap[e.dst][1] == 2] == collect(edges(cg.grv[2]))
end
