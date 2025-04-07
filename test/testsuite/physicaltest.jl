@testset ExtendedTestSet "physicaltest.jl"  begin

    # initialization
    domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]
    ag1 = first(domains_name_graph)[2]
    ibnag1 = MINDF.default_IBNAttributeGraph(ag1)

    # get the node view of a single random vertex
    nodeview1 = AG.vertex_attr(ibnag1)[1]
    routerview1 = MINDF.getrouterview(nodeview1)
    oxcview1 = MINDF.getoxcview(nodeview1)
    dagnodeid1 = UUID(1)

    rplli1 = MINDF.RouterPortLLI(1, 2)
    tmlli1 = MINDF.TransmissionModuleLLI(1, 1, 1)
    oxclli1 = MINDF.OXCAddDropBypassSpectrumLLI(1, 4, 0, 6, 2:4)

    sdndummy = MINDF.SDNdummy()
    for (reservableresource, lli) in zip([nodeview1, routerview1, oxcview1], [tmlli1, rplli1, oxclli1])
        @test MINDF.canreserve(sdndummy, reservableresource, lli)
        @test_nothrows @inferred MINDF.canreserve(sdndummy, reservableresource, lli)
        RUNJET && @test_opt target_modules=[MINDF] MINDF.canreserve(sdndummy, reservableresource, lli)

        RUNJET && @test_opt target_modules=[MINDF] MINDF.reserve!(sdndummy, reservableresource, lli, dagnodeid1; verbose = true)
        @test MINDF.reserve!(sdndummy, reservableresource, lli, dagnodeid1; verbose = true)
        if lli isa MINDF.OXCAddDropBypassSpectrumLLI
            @test !any(MINDF.getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][2:4])
            @test !any(MINDF.getlinkspectrumavailabilities(oxcview1)[Edge(1, 6)][2:4])
        end
        @test !MINDF.canreserve(sdndummy, reservableresource, lli)

        reservations = MINDF.getreservations(reservableresource)
        @test length(reservations) == 1
        @test first(reservations) == (dagnodeid1 => lli)

        RUNJET && @test_opt target_modules=[MINDF] MINDF.unreserve!(sdndummy, reservableresource, dagnodeid1)
        @test MINDF.unreserve!(sdndummy, reservableresource, dagnodeid1)
        if lli isa MINDF.OXCAddDropBypassSpectrumLLI
            @test all(MINDF.getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)])
            @test all(MINDF.getlinkspectrumavailabilities(oxcview1)[Edge(1, 6)])
        end
        @test MINDF.canreserve(sdndummy, reservableresource, lli)
        @test length(MINDF.getreservations(reservableresource)) == 0

        # TODO check OXC edges
    end

    @test MINDF.reserve!(sdndummy, oxcview1, oxclli1, dagnodeid1; checkfirst = true)
    @test !MINDF.reserve!(sdndummy, oxcview1, MINDF.OXCAddDropBypassSpectrumLLI(1, 4, 0, 6, 5:6), dagnodeid1; checkfirst = true)
    @test MINDF.reserve!(sdndummy, oxcview1, MINDF.OXCAddDropBypassSpectrumLLI(1, 4, 0, 6, 5:6), UUID(2); checkfirst = true)
    @test !any(MINDF.getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][2:6])
    @test MINDF.getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][1]
    @test all(MINDF.getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][7:end])

    # allocate also nodes 4 and 6 for OXClli to have a consistent OXC-level state
    # go from 4 to 1
    @test MINDF.reserve!(sdndummy, MINDF.getoxcview(AG.vertex_attr(ibnag1)[4]), MINDF.OXCAddDropBypassSpectrumLLI(4, 0, 1, 1, 2:4), UUID(3); checkfirst = true)
    @test MINDF.reserve!(sdndummy, MINDF.getoxcview(AG.vertex_attr(ibnag1)[4]), MINDF.OXCAddDropBypassSpectrumLLI(4, 0, 2, 1, 5:6), UUID(4); checkfirst = true)

    # go from 1 to 6
    @test MINDF.reserve!(sdndummy, MINDF.getoxcview(AG.vertex_attr(ibnag1)[6]), MINDF.OXCAddDropBypassSpectrumLLI(6, 1, 1, 0, 2:4), UUID(5); checkfirst = true)
    @test MINDF.reserve!(sdndummy, MINDF.getoxcview(AG.vertex_attr(ibnag1)[6]), MINDF.OXCAddDropBypassSpectrumLLI(6, 1, 2, 0, 5:6), UUID(6); checkfirst = true)

    # now test the intent workflow
    # reinitialize domain

    ibnf1 = MINDF.IBNFramework(ibnag1)
    conintent1 = MINDF.ConnectivityIntent(MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 1), MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 2), u"100.0Gbps")
    MINDF.addintent!(ibnf1, conintent1, MINDF.NetworkOperator())
    # add second intent
    intentid2 = MINDF.addintent!(ibnf1, conintent1, MINDF.NetworkOperator())
    @test nv(MINDF.getidag(ibnf1)) == 2
    # remove second intent
    @test MINDF.removeintent!(ibnf1, intentid2)
    @test nv(MINDF.getidag(ibnf1)) == 1

end
