function testsuitephysical!(ibnag1, RUNJET)
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
        @test_nothrows @inferred canreserve(sdndummy, reservableresource, lli)
        RUNJET && @test_opt target_modules=[MINDF] canreserve(sdndummy, reservableresource, lli)

        RUNJET && @test_opt target_modules=[MINDF] reserve!(sdndummy, reservableresource, lli, dagnodeid1; verbose = true)
        @test issuccess(reserve!(sdndummy, reservableresource, lli, dagnodeid1; verbose = true))
        if lli isa OXCAddDropBypassSpectrumLLI
            @test !any(getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][2:4])
            @test !any(getlinkspectrumavailabilities(oxcview1)[Edge(1, 6)][2:4])
        end
        @test !canreserve(sdndummy, reservableresource, lli)

        reservations = getreservations(reservableresource)
        @test length(reservations) == 1
        @test first(reservations) == (dagnodeid1 => lli)

        RUNJET && @test_opt target_modules=[MINDF] unreserve!(sdndummy, reservableresource, dagnodeid1)
        @test issuccess(unreserve!(sdndummy, reservableresource, dagnodeid1))
        if lli isa OXCAddDropBypassSpectrumLLI
            @test all(getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)])
            @test all(getlinkspectrumavailabilities(oxcview1)[Edge(1, 6)])
        end
        @test canreserve(sdndummy, reservableresource, lli)
        @test length(getreservations(reservableresource)) == 0
    end

    @test issuccess(reserve!(sdndummy, oxcview1, oxclli1, dagnodeid1; checkfirst = true))
    @test !issuccess(reserve!(sdndummy, oxcview1, OXCAddDropBypassSpectrumLLI(1, 4, 0, 6, 5:6), dagnodeid1; checkfirst = true))
    @test issuccess(reserve!(sdndummy, oxcview1, OXCAddDropBypassSpectrumLLI(1, 4, 0, 6, 5:6), UUID(2); checkfirst = true))
    @test !any(getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][2:6])
    @test getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][1]
    @test all(getlinkspectrumavailabilities(oxcview1)[Edge(4, 1)][7:end])

    # allocate also nodes 4 and 6 for OXClli to have a consistent OXC-level state
    # go from 4 to 1
    @test issuccess(reserve!(sdndummy, getoxcview(AG.vertex_attr(ibnag1)[4]), OXCAddDropBypassSpectrumLLI(4, 0, 1, 1, 2:4), UUID(3); checkfirst = true))
    @test issuccess(reserve!(sdndummy, getoxcview(AG.vertex_attr(ibnag1)[4]), OXCAddDropBypassSpectrumLLI(4, 0, 2, 1, 5:6), UUID(4); checkfirst = true))

    # go from 1 to 6
    @test issuccess(reserve!(sdndummy, getoxcview(AG.vertex_attr(ibnag1)[6]), OXCAddDropBypassSpectrumLLI(6, 1, 1, 0, 2:4), UUID(5); checkfirst = true))
    @test issuccess(reserve!(sdndummy, getoxcview(AG.vertex_attr(ibnag1)[6]), OXCAddDropBypassSpectrumLLI(6, 1, 2, 0, 5:6), UUID(6); checkfirst = true))

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

function testsuitebasicintent!(ibnf1, RUNJET)
    testlocalnodeisindex(ibnf1)
    testoxcfiberallocationconsistency(ibnf1)

    conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnf1), 4), GlobalNode(getibnfid(ibnf1), 8), u"105.0Gbps")

    intentuuid1 = addintent!(ibnf1, conintent1, NetworkOperator())
    @test nv(getidag(ibnf1)) == 1
    @test intentuuid1 isa UUID
    @test getidagnodestate(getidag(ibnf1), intentuuid1) == IntentState.Uncompiled
    @test isempty(getidagnodechildren(getidag(ibnf1), intentuuid1))

    RUNJET && @test_opt broken=true target_modules=[MINDF] function_filter=JETfilteroutfunctions compileintent!(ibnf1, getidagnode(getidag(ibnf1), intentuuid1), KShorestPathFirstFitCompilation(10))
    @test compileintent!(ibnf1, intentuuid1, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    testcompilation(ibnf1, intentuuid1; withremote=false)

    @test installintent!(ibnf1, intentuuid1) == ReturnCodes.SUCCESS
    testinstallation(ibnf1, intentuuid1; withremote=false)

    @test uninstallintent!(ibnf1, intentuuid1) == ReturnCodes.SUCCESS
    testuninstallation(ibnf1, intentuuid1; withremote=false)

    @test uncompileintent!(ibnf1, UUID(1)) == ReturnCodes.SUCCESS
    testuncompilation(ibnf1, intentuuid1)
    @test nv(getidag(ibnf1)) == 1

    nothingisallocated(ibnf1)

    @test removeintent!(ibnf1, intentuuid1) == ReturnCodes.SUCCESS
    @test nv(getidag(ibnf1)) == 0

    testoxcfiberallocationconsistency(ibnf1)
    testzerostaged(ibnf1)
end

function testsuiteopticalconstraintssingledomain!(ibnfs)
    foreach(ibnfs) do ibnf
        testlocalnodeisindex(ibnf)
        testoxcfiberallocationconsistency(ibnf)
    end

    conintent_intra = ConnectivityIntent(GlobalNode(UUID(1), 2), GlobalNode(UUID(1), 19), u"100.0Gbps")
    intentuuid1 = addintent!(ibnfs[1], conintent_intra, NetworkOperator())
    @test compileintent!(ibnfs[1], intentuuid1, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test issatisfied(ibnfs[1], intentuuid1; onlyinstalled=false, noextrallis=true)
    @test installintent!(ibnfs[1], intentuuid1) == ReturnCodes.SUCCESS
    @test issatisfied(ibnfs[1], intentuuid1; onlyinstalled=true, noextrallis=true)

    # intradomain with `OpticalTerminateConstraint`
    conintent_intra_optterm = ConnectivityIntent(GlobalNode(UUID(1), 8), GlobalNode(UUID(1), 22), u"100.0Gbps", [OpticalTerminateConstraint(GlobalNode(UUID(1), 22))])
    intentuuid2 = addintent!(ibnfs[1], conintent_intra_optterm, NetworkOperator())
    # kspffintradomain_2!(ibnfs[1], getidagnode(getidag(ibnfs[1]), intentuuid2), KShorestPathFirstFitCompilation(10))
    @test compileintent!(ibnfs[1], intentuuid2, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    orderedllis2 = getlogicallliorder(ibnfs[1], intentuuid2; onlyinstalled=false)
    @test issatisfied(ibnfs[1], intentuuid2, orderedllis2; noextrallis=true)
    vorletzteglobalsnode = getglobalnode(getibnag(ibnfs[1]), getlocalnode(orderedllis2[end]))
    spectrumslots = getspectrumslotsrange(orderedllis2[end])
    transmode = gettransmissionmode(ibnfs[1], orderedllis2[2])
    transmodulename = getname(gettransmissionmodule(ibnfs[1], orderedllis2[2]))
    @test installintent!(ibnfs[1], intentuuid2) == ReturnCodes.SUCCESS
    @test issatisfied(ibnfs[1], intentuuid2; onlyinstalled=true, noextrallis=true)

    conintent_intra_optini_finishprevious = ConnectivityIntent(GlobalNode(UUID(1), 22), GlobalNode(UUID(1), 22), u"100.0Gbps", [OpticalInitiateConstraint(vorletzteglobalsnode, spectrumslots, u"10.0km", TransmissionModuleCompatibility(getrate(transmode), getspectrumslotsneeded(transmode), transmodulename))])
    intentuuid_intra_optini_finishprevious = addintent!(ibnfs[1], conintent_intra_optini_finishprevious, NetworkOperator())
    @test compileintent!(ibnfs[1], intentuuid_intra_optini_finishprevious, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test issatisfied(ibnfs[1], intentuuid_intra_optini_finishprevious; onlyinstalled=false, noextrallis=true)
    @test installintent!(ibnfs[1], intentuuid_intra_optini_finishprevious) == ReturnCodes.SUCCESS
    @test issatisfied(ibnfs[1], intentuuid_intra_optini_finishprevious; onlyinstalled=true, noextrallis=true)

    # intradomain with `OpticalInitaiteConstraint`
    conintent_intra_optini = ConnectivityIntent(GlobalNode(UUID(1), 8), GlobalNode(UUID(1), 22), u"100.0Gbps", [OpticalInitiateConstraint(GlobalNode(UUID(1), 2), 21:26, u"500.0km", TransmissionModuleCompatibility(u"300.0Gbps", 6, "DummyFlexiblePluggable"))])
    intentuuid3 = addintent!(ibnfs[1], conintent_intra_optini, NetworkOperator())
    @test compileintent!(ibnfs[1], intentuuid3, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test issatisfied(ibnfs[1], intentuuid3; onlyinstalled=false, noextrallis=true)
    @test installintent!(ibnfs[1], intentuuid3) == ReturnCodes.SUCCESS
    @test issatisfied(ibnfs[1], intentuuid3; onlyinstalled=true, noextrallis=true)

    oxcview1_2 = getoxcview(getnodeview(ibnfs[1], 2))
    oxcllifinishprevious3 = OXCAddDropBypassSpectrumLLI(2, 0, 2, 8, 21:26)
    @test canreserve(getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious3)
    @test issuccess(reserve!(getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious3, UUID(0xfffffff); verbose = true))

    # intradomain with `OpticalInitaiteConstraint and OpticalTerminateConstraint`
    conintent_intra_optseg = ConnectivityIntent(GlobalNode(UUID(1), 8), GlobalNode(UUID(1), 22), u"100.0Gbps", [OpticalTerminateConstraint(GlobalNode(UUID(1), 22)), OpticalInitiateConstraint(GlobalNode(UUID(1), 2), 31:34, u"500.0km", TransmissionModuleCompatibility(u"100.0Gbps", 4, "DummyFlexiblePluggable"))])
    intentuuid4 = addintent!(ibnfs[1], conintent_intra_optseg, NetworkOperator())
    @test compileintent!(ibnfs[1], intentuuid4, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    orderedllis4 = getlogicallliorder(ibnfs[1], intentuuid4; onlyinstalled=false)
    @test issatisfied(ibnfs[1], intentuuid4, orderedllis4; noextrallis=true)
    vorletzteglobalsnode4 = getlocalnode(orderedllis4[end])
    @test installintent!(ibnfs[1], intentuuid4) == ReturnCodes.SUCCESS
    @test issatisfied(ibnfs[1], intentuuid4; onlyinstalled=true, noextrallis=true)

    oxcllifinishprevious4 = OXCAddDropBypassSpectrumLLI(2, 0, 2, 8, 31:34)
    @test canreserve(getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious4)
    @test issuccess(reserve!(getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious4, UUID(0xffffff1); verbose = true))

    oxcview1_22 = getoxcview(getnodeview(ibnfs[1], 22))
    oxcllifinishprevious4_1 = OXCAddDropBypassSpectrumLLI(22, vorletzteglobalsnode4, 2, 0, 31:34)
    @test canreserve(getsdncontroller(ibnfs[1]), oxcview1_22, oxcllifinishprevious4_1)
    @test issuccess(reserve!(getsdncontroller(ibnfs[1]), oxcview1_22, oxcllifinishprevious4_1, UUID(0xffffff2); verbose = true))

    foreach(ibnfs) do ibnf
      testlocalnodeisindex(ibnf)
      testoxcfiberallocationconsistency(ibnf)
      testzerostaged(ibnf)
    end
end


function testsuitemultidomain!(ibnfs)
    # with border node
    conintent_bordernode = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 25), u"100.0Gbps")
    intentuuid_bordernode = addintent!(ibnfs[1], conintent_bordernode, NetworkOperator())

    @test compileintent!(ibnfs[1], intentuuid_bordernode, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], intentuuid_bordernode; withremote=true)
 
    # install
    @test installintent!(ibnfs[1], intentuuid_bordernode; verbose=false) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], intentuuid_bordernode; withremote=true)

    # uninstall
    @test uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose=false) == ReturnCodes.SUCCESS
    testuninstallation(ibnfs[1], intentuuid_bordernode; withremote=true)

    # uncompile
    @test uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose=false) == ReturnCodes.SUCCESS
    testuncompilation(ibnfs[1], intentuuid_bordernode)
    @test nv(getidag(ibnfs[1])) == 1
    @test nv(getidag(ibnfs[3])) == 0

    # to neighboring domain
    conintent_neigh = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 47), u"100.0Gbps")
    intentuuid_neigh = addintent!(ibnfs[1], conintent_neigh, NetworkOperator())

    @test compileintent!(ibnfs[1], intentuuid_neigh, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], intentuuid_neigh; withremote=true)

    @test installintent!(ibnfs[1], intentuuid_neigh; verbose=false) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], intentuuid_neigh; withremote=true)

    @test uninstallintent!(ibnfs[1], intentuuid_neigh; verbose=false) == ReturnCodes.SUCCESS
    testuninstallation(ibnfs[1], intentuuid_neigh; withremote=true)

    @test uncompileintent!(ibnfs[1], intentuuid_neigh; verbose=false) == ReturnCodes.SUCCESS
    testuncompilation(ibnfs[1], intentuuid_neigh)
    @test nv(getidag(ibnfs[1])) == 2
    @test nv(getidag(ibnfs[3])) == 0
    # to unknown domain
 
    foreach(ibnfs) do ibnf
        testoxcfiberallocationconsistency(ibnf)
        testzerostaged(ibnf)
    end
end



function testsuitefailingintime!(ibnfs)
    internaledge = Edge(3,4)
    getlinkstates(getoxcview(getnodeview(ibnfs[1], src(internaledge))))[internaledge]

    offsettime = now()
    entrytime = now()

    conintent_internal = ConnectivityIntent(GlobalNode(UUID(1), 14), GlobalNode(UUID(1), 1), u"100.0Gbps")
    intentuuid_internal_fail = addintent!(ibnfs[1], conintent_internal, NetworkOperator())
    @test compileintent!(ibnfs[1], intentuuid_internal_fail, KShorestPathFirstFitCompilation(10); @passtime) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], intentuuid_internal_fail; verbose=false, @passtime) == ReturnCodes.SUCCESS
    let 
        logord = getlogicallliorder(ibnfs[1], intentuuid_internal_fail, onlyinstalled=false)
        @test internaledge ∈ edgeify(logicalordergetpath(logord))
    end

    offsettime += Hour(1)
    @test setlinkstate!(ibnfs[1], internaledge, false; @passtime) == ReturnCodes.SUCCESS
    # should make first intent fail
    @test getidagnodestate(getidag(ibnfs[1]), intentuuid_internal_fail) == IntentState.Failed
    testexpectedfaileddag(getidag(ibnfs[1]), intentuuid_internal_fail, internaledge, 2)

    # second intent should avoud using the failed link
    intentuuid_internal = addintent!(ibnfs[1], conintent_internal, NetworkOperator())

    @test compileintent!(ibnfs[1], intentuuid_internal, KShorestPathFirstFitCompilation(10); @passtime) == ReturnCodes.SUCCESS

    let 
        logord = getlogicallliorder(ibnfs[1], intentuuid_internal, onlyinstalled=false)
        @test internaledge ∉ edgeify(logicalordergetpath(logord))
    end

    @test installintent!(ibnfs[1], intentuuid_internal; verbose=false, @passtime) == ReturnCodes.SUCCESS
    @test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_internal)])

    # should make the intent installed again
    offsettime += Hour(1)
    @test setlinkstate!(ibnfs[1], internaledge, true; @passtime) == ReturnCodes.SUCCESS
    @test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_internal_fail)])

    internaledgelinkstates = getlinkstates(ibnfs[1], internaledge)
    @test all(getindex.(internaledgelinkstates[2:end], 1) .- getindex.(internaledgelinkstates[1:end-1], 1) .>= Hour(1))
    intentuuid_internal_fail_timelog =  getindex.(MINDF.getlogstate(MINDF.getidagnode(getidag(ibnfs[1]), intentuuid_internal_fail)), 1)
    @test length(intentuuid_internal_fail_timelog) == 7
    @test intentuuid_internal_fail_timelog[end] - intentuuid_internal_fail_timelog[1] >= Hour(2) 


    # Border link is failing
    # 29 is border node
    offsettime = now()
    entrytime = now()
    borderedge = Edge(17,29)
    foreach(ibnfs) do ibnf
        @test all([MINDF.getcurrentlinkstate(ibnf, ed) for ed in edges(getibnag(ibnf))])
    end

    conintent_border = ConnectivityIntent(GlobalNode(UUID(1), 18), GlobalNode(UUID(3), 23), u"100.0Gbps")
    intentuuid_border_fail = addintent!(ibnfs[1], conintent_border, NetworkOperator())
    @test compileintent!(ibnfs[1], intentuuid_border_fail, KShorestPathFirstFitCompilation(10); @passtime) == ReturnCodes.SUCCESS
    remoteibnfid_border, remoteintentid_border = getfirstremoteintent(ibnfs[1], intentuuid_border_fail)
    remoteibnf_border = getibnfhandler(ibnfs[1], remoteibnfid_border)

    @test installintent!(ibnfs[1], intentuuid_border_fail; verbose=false, @passtime) == ReturnCodes.SUCCESS

    offsettime += Hour(1)
    @test setlinkstate!(ibnfs[1], borderedge, false; @passtime) == ReturnCodes.SUCCESS
    # should make first intent fail
    @test getidagnodestate(getidag(ibnfs[1]), intentuuid_border_fail) == IntentState.Failed
    testexpectedfaileddag(getidag(ibnfs[1]), intentuuid_border_fail, borderedge, 1)
    testexpectedfaileddag(MINDF.requestidag_init(ibnfs[1], remoteibnf_border), remoteintentid_border, Edge(58,25), 1)

    intentuuid_border = addintent!(ibnfs[1], conintent_border, NetworkOperator())
    @test compileintent!(ibnfs[1], intentuuid_border, KShorestPathFirstFitCompilation(10); @passtime) == ReturnCodes.SUCCESS
    let 
        logord = getlogicallliorder(ibnfs[1], intentuuid_border, onlyinstalled=false)
        @test borderedge ∉ edgeify(logicalordergetpath(logord))
    end
    @test installintent!(ibnfs[1], intentuuid_border; verbose=false, @passtime) == ReturnCodes.SUCCESS
    @test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_border)])


    # should make the intent installed again
    offsettime += Hour(1)
    @test setlinkstate!(ibnfs[1], borderedge, true; @passtime) == ReturnCodes.SUCCESS
    @test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_border_fail)])
    @test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(MINDF.requestidag_init(ibnfs[1], remoteibnf_border), remoteintentid_border)])

    borderedgelinkstates = getlinkstates(ibnfs[1], borderedge; checkfirst=true)
    @test all(getindex.(borderedgelinkstates[2:end], 1) .- getindex.(borderedgelinkstates[1:end-1], 1) .>= Hour(1))
    intentuuid_border_fail_timelog =  getindex.(MINDF.getlogstate(MINDF.getidagnode(getidag(ibnfs[1]), intentuuid_border_fail)), 1)
    @test length(intentuuid_border_fail_timelog) == 9
    @test intentuuid_border_fail_timelog[end] - intentuuid_border_fail_timelog[1] >= Hour(2) 
    intentuuid_border_fail_timelog_remote =  getindex.(MINDF.getlogstate(MINDF.getidagnode(MINDF.requestidag_init(ibnfs[1], remoteibnf_border), remoteintentid_border)), 1)
    @test length(intentuuid_border_fail_timelog_remote) == 7
    @test intentuuid_border_fail_timelog_remote[end] - intentuuid_border_fail_timelog_remote[1] >= Hour(2) 

    # uninstall, remove all
    @test uninstallintent!(ibnfs[1], intentuuid_border_fail; verbose=false) == ReturnCodes.SUCCESS
    testuninstallation(ibnfs[1], intentuuid_border_fail; withremote=true)
    @test uninstallintent!(ibnfs[1], intentuuid_border; verbose=false) == ReturnCodes.SUCCESS
    testuninstallation(ibnfs[1], intentuuid_border; withremote=true)

    @test uncompileintent!(ibnfs[1], intentuuid_border_fail; verbose=false) == ReturnCodes.SUCCESS
    testuncompilation(ibnfs[1], intentuuid_border_fail)
    @test uncompileintent!(ibnfs[1], intentuuid_border; verbose=false) == ReturnCodes.SUCCESS
    testuncompilation(ibnfs[1], intentuuid_border)

    # External link is failing (ibnfs[3])
    externaledge = Edge(23, 15)
    conintent_external = ConnectivityIntent(GlobalNode(UUID(1), 14), GlobalNode(UUID(3), 12), u"100.0Gbps")
    intentuuid_external_fail = addintent!(ibnfs[1], conintent_external, NetworkOperator())
    @test compileintent!(ibnfs[1], intentuuid_external_fail, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    remoteibnfid_external_fail, remoteintentid_external_fail = getfirstremoteintent(ibnfs[1], intentuuid_external_fail)
    remoteibnf_external_fail = getibnfhandler(ibnfs[1], remoteibnfid_external_fail)
    @test installintent!(ibnfs[1], intentuuid_external_fail; verbose=false) == ReturnCodes.SUCCESS

    @test setlinkstate!(ibnfs[3], externaledge, false) == ReturnCodes.SUCCESS
    testexpectedfaileddag(MINDF.requestidag_init(ibnfs[1], remoteibnf_external_fail), remoteintentid_external_fail, externaledge, 2)
    @test getidagnodestate(getidag(ibnfs[1]), intentuuid_external_fail) == IntentState.Failed
    @test count(x -> getidagnodestate(x) == IntentState.Failed, getidagnodes(getidag(ibnfs[1]))) == 4

    intentuuid_external = addintent!(ibnfs[1], conintent_external, NetworkOperator())
    @test compileintent!(ibnfs[1], intentuuid_external, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    remoteibnfid_external, remoteintentid_external = getfirstremoteintent(ibnfs[1], intentuuid_external)
    remoteibnf_external = getibnfhandler(ibnfs[1], remoteibnfid_external)
    @test installintent!(ibnfs[1], intentuuid_external; verbose=false) == ReturnCodes.SUCCESS
    @test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_external)])
    @test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(MINDF.requestidag_init(ibnfs[1], remoteibnf_external), remoteintentid_external)])
    let 
        logord = MINDF.requestlogicallliorder_init(ibnfs[1], remoteibnf_external, remoteintentid_external, onlyinstalled=false)
        @test externaledge ∉ edgeify(logicalordergetpath(logord))
    end

    # uninstall, remove all
    @test uninstallintent!(ibnfs[1], intentuuid_external_fail; verbose=false) == ReturnCodes.SUCCESS
    testuninstallation(ibnfs[1], intentuuid_external_fail; withremote=true)
    @test uninstallintent!(ibnfs[1], intentuuid_external; verbose=false) == ReturnCodes.SUCCESS
    testuninstallation(ibnfs[1], intentuuid_external; withremote=true)

    @test uncompileintent!(ibnfs[1], intentuuid_external_fail; verbose=false) == ReturnCodes.SUCCESS
    testuncompilation(ibnfs[1], intentuuid_external_fail)
    @test uncompileintent!(ibnfs[1], intentuuid_external; verbose=false) == ReturnCodes.SUCCESS
    testuncompilation(ibnfs[1], intentuuid_external)

    # test bordernodes have the same logs

    # get all link states, set them, and reget
    for ibnf in ibnfs
        ibnag = getibnag(ibnf)
        for ed in edges(ibnag)
            ls1 = getcurrentlinkstate(ibnf, ed)
            setlinkstate!(ibnf, ed, !ls1)
            ls2 = getcurrentlinkstate(ibnf, ed)
            @test ls1 !== ls2
        end
    end

    for ibnf in ibnfs
        testedgeoxclogs(ibnf)
        testoxcllistateconsistency(ibnf)
    end
end



function testsuitegrooming!(ibnfs)
    # internal
    conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
    intentuuid1 = addintent!(ibnfs[1], conintent1, NetworkOperator())
    conintent1idn = getidagnode(getidag(ibnfs[1]), intentuuid1)
    compileintent!(ibnfs[1], intentuuid1, KShorestPathFirstFitCompilation(10))
    installintent!(ibnfs[1], intentuuid1)

    installedlightpathsibnfs1 = getinstalledlightpaths(getidaginfo(getidag(ibnfs[1])))
    @test length(installedlightpathsibnfs1) == 1
    lpr1 = installedlightpathsibnfs1[UUID(0x2)]
    @test first(MINDF.getpath(lpr1)) == 4
    @test last(MINDF.getpath(lpr1)) == 8
    @test MINDF.getstartsoptically(lpr1) == false
    @test MINDF.getterminatessoptically(lpr1) == false
    @test MINDF.gettotalbandwidth(lpr1) == GBPSf(100)
    @test getresidualbandwidth(ibnfs[1], UUID(0x2)) == GBPSf(70)

    groomconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
    groomintentuuid1 = addintent!(ibnfs[1], groomconintent1, NetworkOperator())
    groomconintent1idn = getidagnode(getidag(ibnfs[1]), groomintentuuid1)
    @test MINDF.prioritizegrooming_default(ibnfs[1], groomconintent1idn, KShorestPathFirstFitCompilation(4)) == [[UUID(0x2)]]
    compileintent!(ibnfs[1], groomintentuuid1, KShorestPathFirstFitCompilation(10))
    @test getidagnodestate(groomconintent1idn) == IntentState.Compiled
    @test length(installedlightpathsibnfs1) == 1
    @test getresidualbandwidth(ibnfs[1], UUID(0x2); onlyinstalled=true) == GBPSf(70)
    @test getresidualbandwidth(ibnfs[1], UUID(0x2); onlyinstalled=false) == GBPSf(40)
    testcompilation(ibnfs[1], groomintentuuid1; withremote=false)
    testinstallation(ibnfs[1], intentuuid1; withremote=false)

    @test installintent!(ibnfs[1], groomintentuuid1) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], intentuuid1; withremote=false)
    testinstallation(ibnfs[1], groomintentuuid1; withremote=false)

    # uninstall one
    @test uninstallintent!(ibnfs[1], groomintentuuid1) == ReturnCodes.SUCCESS
    @test getidagnodestate(groomconintent1idn) == IntentState.Compiled
    # all other remain installed
    @test all(x -> getidagnodestate(x) == IntentState.Installed, MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid1; includeroot=true))
    testinstallation(ibnfs[1], intentuuid1; withremote=false)

    # uninstall also the other one
    @test uninstallintent!(ibnfs[1], intentuuid1) == ReturnCodes.SUCCESS
    @test all(x -> getidagnodestate(x) == IntentState.Compiled, MINDF.getidagnodes(getidag(ibnfs[1])))
    @test length(installedlightpathsibnfs1) == 0
    testcompilation(ibnfs[1], groomintentuuid1; withremote=false)
    testcompilation(ibnfs[1], intentuuid1; withremote=false)

    # install the second
    @test installintent!(ibnfs[1], groomintentuuid1) == ReturnCodes.SUCCESS
    @test all(x -> getidagnodestate(x) == IntentState.Installed, MINDF.getidagnodedescendants(getidag(ibnfs[1]), groomintentuuid1; includeroot=true))
    @test getidagnodestate(conintent1idn) == IntentState.Compiled
    @test length(installedlightpathsibnfs1) == 1

    # uncompile the first one
    @test uncompileintent!(ibnfs[1], intentuuid1) == ReturnCodes.SUCCESS
    @test getidagnodestate(conintent1idn) == IntentState.Uncompiled
    @test isempty(Graphs.neighbors(getidag(ibnfs[1]), getidagnodeidx(getidag(ibnfs[1]), intentuuid1)))

    # compile again 
    @test compileintent!(ibnfs[1], intentuuid1, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS

    # uninstall the second
    @test uninstallintent!(ibnfs[1], groomintentuuid1) == ReturnCodes.SUCCESS

    # uncompile the first one
    @test uncompileintent!(ibnfs[1], intentuuid1) == ReturnCodes.SUCCESS

    # uncompile the second one
    @test uncompileintent!(ibnfs[1], groomintentuuid1) == ReturnCodes.SUCCESS
    @test length(getidagnodes(getidag(ibnfs[1]))) == 2
    @test all(x -> getidagnodestate(x) == IntentState.Uncompiled, getidagnodes(getidag(ibnfs[1])))

    # compile install the first one
    @test compileintent!(ibnfs[1], intentuuid1, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], intentuuid1) == ReturnCodes.SUCCESS

    # try grooming with lightpath and a new intent
    groomandnewconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 22), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
    groomandnewconintent1id = addintent!(ibnfs[1], groomandnewconintent1, NetworkOperator())
    @test compileintent!(ibnfs[1], groomandnewconintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], groomandnewconintent1id; withremote=false)
    @test MINDF.issatisfied(ibnfs[1], groomandnewconintent1id; onlyinstalled=false)
    @test installintent!(ibnfs[1], groomandnewconintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], groomandnewconintent1id; withremote=false)
    @test MINDF.issatisfied(ibnfs[1], groomandnewconintent1id; onlyinstalled=true)
    @test MINDF.issubdaggrooming(getidag(ibnfs[1]), groomandnewconintent1id)
    @test length(installedlightpathsibnfs1) == 2

    # should be separate intent
    nogroomandnewconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 5), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
    nogroomandnewconintent1id = addintent!(ibnfs[1], nogroomandnewconintent1, NetworkOperator())
    @test compileintent!(ibnfs[1], nogroomandnewconintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], nogroomandnewconintent1id) == ReturnCodes.SUCCESS
    @test MINDF.issatisfied(ibnfs[1], nogroomandnewconintent1id; onlyinstalled=true)
    @test !MINDF.issubdaggrooming(getidag(ibnfs[1]), nogroomandnewconintent1id)

    nogroomandnewconintent1lpid = getidagnodeid(MINDF.getfirst(x -> getintent(x) isa MINDF.LightpathIntent, MINDF.getidagnodedescendants(getidag(ibnfs[1]), nogroomandnewconintent1id)))
    @test MINDF.getresidualbandwidth(ibnfs[1], nogroomandnewconintent1lpid) == GBPSf(70)

    nogroomandnewconintent1_over = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 5), GlobalNode(getibnfid(ibnfs[1]), 8), u"80.0Gbps")
    nogroomandnewconintent1_overid = addintent!(ibnfs[1], nogroomandnewconintent1_over, NetworkOperator())
    @test compileintent!(ibnfs[1], nogroomandnewconintent1_overid, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], nogroomandnewconintent1_overid) == ReturnCodes.SUCCESS
    @test !MINDF.issubdaggrooming(getidag(ibnfs[1]), nogroomandnewconintent1_overid)

    nogroomandnewconintent1_down = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 5), GlobalNode(getibnfid(ibnfs[1]), 10), u"10.0Gbps")
    nogroomandnewconintent1_downid = addintent!(ibnfs[1], nogroomandnewconintent1_down, NetworkOperator())
    @test compileintent!(ibnfs[1], nogroomandnewconintent1_downid, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], nogroomandnewconintent1_downid) == ReturnCodes.SUCCESS
    @test MINDF.issubdaggrooming(getidag(ibnfs[1]), nogroomandnewconintent1_downid)

    testzerostaged(ibnfs[1])

    # uncompile uninstall remove all
    for idagnode in MINDF.getnetworkoperatoridagnodes(getidag(ibnfs[1]))
        if getidagnodestate(idagnode) == IntentState.Installed
            @test uninstallintent!(ibnfs[1], getidagnodeid(idagnode)) == ReturnCodes.SUCCESS
        end
        if getidagnodestate(idagnode) == IntentState.Compiled
            @test uncompileintent!(ibnfs[1], getidagnodeid(idagnode)) == ReturnCodes.SUCCESS
        end
        if getidagnodestate(idagnode) == IntentState.Uncompiled
            @test removeintent!(ibnfs[1], getidagnodeid(idagnode)) == ReturnCodes.SUCCESS
        end
    end

    @test iszero(nv(MINDF.getidag(ibnfs[1])))
    @test iszero(ne(MINDF.getidag(ibnfs[1])))

    # border intent 
    cdintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 21), GlobalNode(getibnfid(ibnfs[3]), 25), u"10.0Gbps")
    cdintent1id = addintent!(ibnfs[1], cdintent1, NetworkOperator())
    @test compileintent!(ibnfs[1], cdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS

    # grooming border intent
    gcdintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 21), GlobalNode(getibnfid(ibnfs[3]), 25), u"10.0Gbps")
    gcdintent1id = addintent!(ibnfs[1], gcdintent1, NetworkOperator())
    gcdintent1idagnode = getidagnode(getidag(ibnfs[1]), gcdintent1id)
    @test compileintent!(ibnfs[1], gcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test MINDF.issubdaggrooming(getidag(ibnfs[1]), gcdintent1id)
    testcompilation(ibnfs[1], gcdintent1id; withremote=true)
    testinstallation(ibnfs[1], cdintent1id; withremote=true)
    @test installintent!(ibnfs[1], gcdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], gcdintent1id; withremote=true)
    testinstallation(ibnfs[1], cdintent1id; withremote=true)

    # uninstall 
    @test uninstallintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], cdintent1id; withremote=true)
    @test uncompileintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS
    @test isempty(MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[1]), cdintent1id))
    testinstallation(ibnfs[1], gcdintent1id; withremote=true)
    @test uninstallintent!(ibnfs[1], gcdintent1id) == ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], gcdintent1id) == ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], gcdintent1id) == ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS

    foreach(ibnfs) do ibnf
        testoxcfiberallocationconsistency(ibnf)
        testzerostaged(ibnf)
        nothingisallocated(ibnf)
    end
    @test iszero(nv(MINDF.getidag(ibnfs[1])))
    @test iszero(ne(MINDF.getidag(ibnfs[1])))


    cdintent1id = addintent!(ibnfs[1], cdintent1, NetworkOperator())
    @test compileintent!(ibnfs[1], cdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS
    crosslightpathidagnode = MINDF.getfirst(x -> getintent(x) isa CrossLightpathIntent, getidagnodedescendants(getidag(ibnfs[1]), cdintent1id))
    @test !isnothing(crosslightpathidagnode)

    # grooming border intent + new LP
    lpgcdintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 1), GlobalNode(getibnfid(ibnfs[3]), 25), u"10.0Gbps")
    lpgcdintent1id = addintent!(ibnfs[1], lpgcdintent1, NetworkOperator())
    @test compileintent!(ibnfs[1], lpgcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], lpgcdintent1id) == ReturnCodes.SUCCESS
    @test MINDF.issubdaggrooming(getidag(ibnfs[1]), lpgcdintent1id)

    # non grooming border intent
    ngcdintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 1), GlobalNode(getibnfid(ibnfs[3]), 24), u"10.0Gbps")
    ngcdintent1id = addintent!(ibnfs[1], ngcdintent1, NetworkOperator())
    @test compileintent!(ibnfs[1], ngcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], ngcdintent1id) == ReturnCodes.SUCCESS
    # doesn't contain the cross light path intent from before
    @test !any(x -> getidagnodeid(x) == getidagnodeid(crosslightpathidagnode), getidagnodedescendants(getidag(ibnfs[1]), ngcdintent1id))

    # non grooming border intent
    ongcdintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 16), GlobalNode(getibnfid(ibnfs[3]), 38), u"10.0Gbps")
    ongcdintent1id = addintent!(ibnfs[1], ongcdintent1, NetworkOperator())
    @test compileintent!(ibnfs[1], ongcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], ongcdintent1id) == ReturnCodes.SUCCESS
    # doesn't contain the cross light path intent from before
    @test !MINDF.issubdaggrooming(getidag(ibnfs[1]), ongcdintent1id)
    @test !any(x -> getidagnodeid(x) == getidagnodeid(crosslightpathidagnode), getidagnodedescendants(getidag(ibnfs[1]), ongcdintent1id))

    # grooming intent regardless path
    gongcdintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 19), GlobalNode(getibnfid(ibnfs[3]), 38), u"10.0Gbps")
    gongcdintent1id = addintent!(ibnfs[1], gongcdintent1, NetworkOperator())
    @test compileintent!(ibnfs[1], gongcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(ibnfs[1], gongcdintent1id) == ReturnCodes.SUCCESS
    # doesn't contain the cross light path intent from before
    @test !MINDF.issubdaggrooming(getidag(ibnfs[1]), gongcdintent1id)
    @test !any(x -> getidagnodeid(x) == getidagnodeid(crosslightpathidagnode), getidagnodedescendants(getidag(ibnfs[1]), gongcdintent1id))

    # test all and unistall one by one
    testinstallation(ibnfs[1], cdintent1id; withremote=true)
    testinstallation(ibnfs[1], lpgcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], cdintent1id) ==  ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], cdintent1id; withremote=true)
    testinstallation(ibnfs[1], lpgcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], lpgcdintent1id) ==  ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], cdintent1id; withremote=true)
    testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], ngcdintent1id) ==  ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], cdintent1id; withremote=true)
    testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], ongcdintent1id) ==  ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], cdintent1id; withremote=true)
    testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], gongcdintent1id) ==  ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], cdintent1id; withremote=true)
    testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    # uncompile one by one

    @test uncompileintent!(ibnfs[1], cdintent1id) ==  ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uncompileintent!(ibnfs[1], lpgcdintent1id) ==  ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uncompileintent!(ibnfs[1], ngcdintent1id) ==  ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uncompileintent!(ibnfs[1], ongcdintent1id) ==  ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uncompileintent!(ibnfs[1], gongcdintent1id) ==  ReturnCodes.SUCCESS


    @test nv(MINDF.getidag(ibnfs[1])) == 5
    @test iszero(ne(MINDF.getidag(ibnfs[1])))
    foreach(ibnfs) do ibnf
        testoxcfiberallocationconsistency(ibnf)
        testzerostaged(ibnf)
        nothingisallocated(ibnf)
    end


    # compile install all again 
    @test compileintent!(ibnfs[1], cdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], cdintent1id; withremote=true)
    @test installintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], cdintent1id; withremote=true)

    @test compileintent!(ibnfs[1], lpgcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    @test installintent!(ibnfs[1], lpgcdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], lpgcdintent1id; withremote=true)

    @test compileintent!(ibnfs[1], ngcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    @test installintent!(ibnfs[1], ngcdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], ngcdintent1id; withremote=true)

    @test compileintent!(ibnfs[1], ongcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    @test installintent!(ibnfs[1], ongcdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], ongcdintent1id; withremote=true)

    @test compileintent!(ibnfs[1], gongcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    testcompilation(ibnfs[1], gongcdintent1id; withremote=true)
    @test installintent!(ibnfs[1], gongcdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    # uncompiled uninstall one by one
    @test uninstallintent!(ibnfs[1], cdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], cdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], lpgcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], lpgcdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], lpgcdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], lpgcdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], ngcdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], ngcdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], ngcdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], ongcdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], ongcdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], ongcdintent1id) == ReturnCodes.SUCCESS
    testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], gongcdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], gongcdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], gongcdintent1id) == ReturnCodes.SUCCESS

    foreach(ibnfs) do ibnf
        testoxcfiberallocationconsistency(ibnf)
        testzerostaged(ibnf)
        nothingisallocated(ibnf)
    end
    @test iszero(nv(MINDF.getidag(ibnfs[1])))
    @test iszero(ne(MINDF.getidag(ibnfs[1])))
end

function testsuitegroomingonfail!(ibnfs)
    conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
    intentuuid1 = addintent!(ibnfs[1], conintent1, NetworkOperator())
    conintent1idn = getidagnode(getidag(ibnfs[1]), intentuuid1)
    compileintent!(ibnfs[1], intentuuid1, KShorestPathFirstFitCompilation(10))
    installintent!(ibnfs[1], intentuuid1)

    installedlightpathsibnfs1 = getinstalledlightpaths(getidaginfo(getidag(ibnfs[1])))
    @test length(installedlightpathsibnfs1) == 1
    lpr1 = installedlightpathsibnfs1[UUID(0x2)]
    @test first(MINDF.getpath(lpr1)) == 4
    @test last(MINDF.getpath(lpr1)) == 8
    @test MINDF.getstartsoptically(lpr1) == false
    @test MINDF.getterminatessoptically(lpr1) == false
    @test MINDF.gettotalbandwidth(lpr1) == GBPSf(100)
    @test getresidualbandwidth(ibnfs[1], UUID(0x2)) == GBPSf(70)

    MINDF.setlinkstate!(ibnfs[1], Edge(20, 8), false) == ReturnCodes.SUCCESS
    @test getidagnodestate(conintent1idn) == IntentState.Failed

    groomconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
    groomintentuuid1 = addintent!(ibnfs[1], groomconintent1, NetworkOperator())
    groomconintent1idn = getidagnode(getidag(ibnfs[1]), groomintentuuid1)
    @test MINDF.prioritizegrooming_default(ibnfs[1], groomconintent1idn, KShorestPathFirstFitCompilation(4)) == UUID[]

    # for external lightpaths now

    mdconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[3]), 21), u"30.0Gbps")
    mdconintent1id = addintent!(ibnfs[1], mdconintent1, NetworkOperator())
    mdconintent1idn = getidagnode(getidag(ibnfs[1]), mdconintent1id)
    compileintent!(ibnfs[1], mdconintent1id, KShorestPathFirstFitCompilation(10))
    installintent!(ibnfs[1], mdconintent1id)

    @test getidagnodestate(mdconintent1idn) == IntentState.Installed
    MINDF.setlinkstate!(ibnfs[3], Edge(24, 23), false) == ReturnCodes.SUCCESS
    @test getidagnodestate(mdconintent1idn) == IntentState.Failed


    groommdconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[3]), 21), u"30.0Gbps")
    groommdconintent1id = addintent!(ibnfs[1], groommdconintent1, NetworkOperator())
    groommdconintent1idn = getidagnode(getidag(ibnfs[1]), groommdconintent1id)
    compileintent!(ibnfs[1], groommdconintent1id, KShorestPathFirstFitCompilation(10))
    @test getidagnodestate(groommdconintent1idn) == IntentState.Compiled
    installintent!(ibnfs[1], groommdconintent1id)
    @test getidagnodestate(groommdconintent1idn) == IntentState.Installed
    @test !MINDF.issubdaggrooming(getidag(ibnfs[1]), groommdconintent1id)
end

function testsuiteinterface!(ibnfs)
    # do some random allocations
    rng = MersenneTwister(0)
    # for counter in 1:100
    for counter in 1:100
        srcibnf = rand(rng, ibnfs)
        srcnglobalnode = rand(rng, MINDF.getglobalnode.(MINDF.getproperties.(MINDF.getintranodeviews(getibnag(srcibnf)))) )
        dstibnf = rand(rng, ibnfs)
        dstglobalnode = rand(rng, MINDF.getglobalnode.(MINDF.getproperties.(MINDF.getintranodeviews(getibnag(dstibnf)))) )
        while dstglobalnode == srcnglobalnode
            dstglobalnode = rand(rng, MINDF.getglobalnode.(MINDF.getproperties.(MINDF.getintranodeviews(getibnag(dstibnf)))) )
        end

        rate = GBPSf(rand(rng)*100) 

        conintent = ConnectivityIntent(srcnglobalnode, dstglobalnode, rate)
        conintentid = addintent!(srcibnf, conintent, NetworkOperator())
        @test compileintent!(srcibnf, conintentid, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
        @test installintent!(srcibnf, conintentid; verbose=false) == ReturnCodes.SUCCESS
        @test issatisfied(srcibnf, conintentid)
    end

    # check ibnfs generally
    for ibnf in ibnfs
        testoxcllistateconsistency(ibnf)
        testedgeoxclogs(ibnf)
    end

    function getibnfwithid(ibnfs::Vector{<:IBNFramework}, ibnfid::UUID)
        for ibnf in ibnfs
            if getibnfid(ibnf) == ibnfid
                return ibnf
            end
        end
    end

    # check ALL requests with the real counterpart
    for ibnf in ibnfs
        firstenter = true
        for ibnfhandler in getibnfhandlers(ibnf)
            if !(ibnfhandler isa IBNFramework) && firstenter
                firstenter = false
                continue
            end
            ibnfhandlerframework = getibnfwithid(ibnfs, getibnfid(ibnfhandler))

            networkoperatoridagnodes = MINDF.getnetworkoperatoridagnodes(getidag(ibnfhandlerframework))
            rps = randperm(length(networkoperatoridagnodes))
            someidagnodes = first(networkoperatoridagnodes[rps], 10)


            allglobaledges = [GlobalEdge(getglobalnode(getibnag(ibnf), src(ed)), getglobalnode(getibnag(ibnf), dst(ed))) for ed in edges(getibnag(ibnf))] 

            aglobaledge = getfirst(allglobaledges) do ge
                getibnfid(src(ge)) == getibnfid(ibnf) && getibnfid(dst(ge)) == getibnfid(ibnfhandler) && return true
                getibnfid(dst(ge)) == getibnfid(ibnf) && getibnfid(src(ge)) == getibnfid(ibnfhandler) && return true
                return false
            end
            @test !isnothing(aglobaledge)
            # here all the requests
            @test MINDF.requestspectrumavailability_init!(ibnf, ibnfhandler, aglobaledge) == MINDF.requestspectrumavailability_init!(ibnf, ibnfhandlerframework, aglobaledge)
            @test MINDF.requestcurrentlinkstate_init(ibnf, ibnfhandler, aglobaledge) == MINDF.requestcurrentlinkstate_init(ibnf, ibnfhandlerframework, aglobaledge)
            @test MINDF.requestlinkstates_init(ibnf, ibnfhandler, aglobaledge) == MINDF.requestlinkstates_init(ibnf, ibnfhandlerframework, aglobaledge)
            MINDF.requestsetlinkstate_init!(ibnf, ibnfhandler, aglobaledge, false)
            @test MINDF.requestcurrentlinkstate_init(ibnf, ibnfhandler, aglobaledge) == MINDF.requestcurrentlinkstate_init(ibnf, ibnfhandlerframework, aglobaledge) == false

            @test MINDF.isthesame(MINDF.requestibnattributegraph_init(ibnf, ibnfhandler), MINDF.requestibnattributegraph_init(ibnf, ibnfhandlerframework))
            @test MINDF.isthesame(MINDF.requestidag_init(ibnf, ibnfhandler),  MINDF.requestidag_init(ibnf, ibnfhandlerframework))
            @test MINDF.isthesame(MINDF.requestibnfhandlers_init(ibnf, ibnfhandler), MINDF.requestibnfhandlers_init(ibnf, ibnfhandlerframework))

            for idagnode in someidagnodes
                @test MINDF.requestlogicallliorder_init(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestlogicallliorder_init(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 
                @test MINDF.requestintentglobalpath_init(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestintentglobalpath_init(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 
                @test MINDF.requestglobalnodeelectricalpresence_init(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestglobalnodeelectricalpresence_init(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 
                @test MINDF.requestintentgloballightpaths_init(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestintentgloballightpaths_init(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 
                @test MINDF.requestissatisfied_init(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestissatisfied_init(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 

            end
        end
    end
end


function testsuitepermissions!(ibnfs)
    #Requesting compiling an intent (only possible with full permission)
    conintent_bordernode = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 25), u"100.0Gbps")
    intentuuid_bordernode = MINDF.addintent!(ibnfs[1], conintent_bordernode, MINDF.NetworkOperator())
    @test MINDF.compileintent!(ibnfs[1], intentuuid_bordernode, MINDF.KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS #1 -> 3 (Full permission)

    conintent_bordernode = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(3), 25), MINDF.GlobalNode(UUID(1), 4), u"100.0Gbps")
    intentuuid_bordernode = MINDF.addintent!(ibnfs[3], conintent_bordernode, MINDF.NetworkOperator())
    @test_permissionsthrows MINDF.compileintent!(ibnfs[3], intentuuid_bordernode, MINDF.KShorestPathFirstFitCompilation(10)) #3 -> 1 (Limited permission)

    conintent_bordernode = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(3), 43), MINDF.GlobalNode(UUID(2), 37), u"100.0Gbps")
    intentuuid_bordernode = MINDF.addintent!(ibnfs[3], conintent_bordernode, MINDF.NetworkOperator())
    @test_permissionsthrows MINDF.compileintent!(ibnfs[3], intentuuid_bordernode, MINDF.KShorestPathFirstFitCompilation(10)) #3 -> 2 (None permission)

    #Requesting the IBNAttributeGraph (possible with full and limited permission)
    @test MINDF.isthesame(MINDF.requestibnattributegraph_init(ibnfs[1], getibnfhandler(ibnfs[1], getibnfid(ibnfs[2]))), getibnag(ibnfs[2])) #1 -> 2 (Full permission)
    @test MINDF.isthesame(MINDF.requestibnattributegraph_init(ibnfs[2], getibnfhandler(ibnfs[2], getibnfid(ibnfs[1]))), getibnag(ibnfs[1])) #2 -> 1 (Limited permission)
    @test_permissionsthrows MINDF.requestibnattributegraph_init(ibnfs[3], getibnfhandler(ibnfs[3], getibnfid(ibnfs[2]))) #3 -> 2 (None permission)
end
