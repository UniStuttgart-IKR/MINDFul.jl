@testset ExtendedTestSet "physicaltest.jl"  begin

    # initialization
    domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]
    ag1 = first(domains_name_graph)[2]
    ibnag1 = MINDF.default_IBNAttributeGraph(ag1)

    # get the node view of a single random vertex
    nodeview1 = AG.vertex_attr(ibnag1)[1]
    routerview1 = getrouterview(nodeview1)
    oxcview1 = getoxcview(nodeview1)
    dagnodeid1 = UUID(1)

    rplli1 = RouterPortLLI(1, 2)
    tmlli1 = TransmissionModuleLLI(1, 1, 1, 1, 1)
    oxclli1 = OXCAddDropBypassSpectrumLLI(1, 4, 0, 6, 2:4)

    sdndummy = MINDF.SDNdummy()
    for (reservableresource, lli) in zip([nodeview1, routerview1, oxcview1], [tmlli1, rplli1, oxclli1])
        @test canreserve(sdndummy, reservableresource, lli)
        TM.@test_nothrows @inferred canreserve(sdndummy, reservableresource, lli)
        RUNJET && @test_opt target_modules=[MINDF] canreserve(sdndummy, reservableresource, lli)

        RUNJET && @test_opt target_modules=[MINDF] reserve!(sdndummy, reservableresource, lli, dagnodeid1; verbose = true)
        @test reserve!(sdndummy, reservableresource, lli, dagnodeid1; verbose = true)
        if lli isa OXCAddDropBypassSpectrumLLI
            @test !any(getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][2:4])
            @test !any(getlinkspectrumavailabilities(oxcview1)[Edge(1, 6)][2:4])
        end
        @test !canreserve(sdndummy, reservableresource, lli)

        reservations = getreservations(reservableresource)
        @test length(reservations) == 1
        @test first(reservations) == (dagnodeid1 => lli)

        RUNJET && @test_opt target_modules=[MINDF] unreserve!(sdndummy, reservableresource, dagnodeid1)
        @test unreserve!(sdndummy, reservableresource, dagnodeid1)
        if lli isa OXCAddDropBypassSpectrumLLI
            @test all(getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)])
            @test all(getlinkspectrumavailabilities(oxcview1)[Edge(1, 6)])
        end
        @test canreserve(sdndummy, reservableresource, lli)
        @test length(getreservations(reservableresource)) == 0

        # TODO check OXC edges
    end

    @test reserve!(sdndummy, oxcview1, oxclli1, dagnodeid1; checkfirst = true)
    @test !reserve!(sdndummy, oxcview1, OXCAddDropBypassSpectrumLLI(1, 4, 0, 6, 5:6), dagnodeid1; checkfirst = true)
    @test reserve!(sdndummy, oxcview1, OXCAddDropBypassSpectrumLLI(1, 4, 0, 6, 5:6), UUID(2); checkfirst = true)
    @test !any(getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][2:6])
    @test getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][1]
    @test all(getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][7:end])

    # allocate also nodes 4 and 6 for OXClli to have a consistent OXC-level state
    # go from 4 to 1
    @test reserve!(sdndummy, getoxcview(AG.vertex_attr(ibnag1)[4]), OXCAddDropBypassSpectrumLLI(4, 0, 1, 1, 2:4), UUID(3); checkfirst = true)
    @test reserve!(sdndummy, getoxcview(AG.vertex_attr(ibnag1)[4]), OXCAddDropBypassSpectrumLLI(4, 0, 2, 1, 5:6), UUID(4); checkfirst = true)

    # go from 1 to 6
    @test reserve!(sdndummy, getoxcview(AG.vertex_attr(ibnag1)[6]), OXCAddDropBypassSpectrumLLI(6, 1, 1, 0, 2:4), UUID(5); checkfirst = true)
    @test reserve!(sdndummy, getoxcview(AG.vertex_attr(ibnag1)[6]), OXCAddDropBypassSpectrumLLI(6, 1, 2, 0, 5:6), UUID(6); checkfirst = true)

    # now test the intent workflow
    # reinitialize domain

    ibnf1 = IBNFramework(ibnag1)
    conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnf1), 1), GlobalNode(getibnfid(ibnf1), 2), u"100.0Gbps")
    addintent!(ibnf1, conintent1, NetworkOperator())
    # add second intent
    intentid2 = addintent!(ibnf1, conintent1, NetworkOperator())
    @test nv(getidag(ibnf1)) == 2
    # remove second intent
    @test removeintent!(ibnf1, intentid2) == ReturnCodes.SUCCESS
    @test nv(getidag(ibnf1)) == 1

end
