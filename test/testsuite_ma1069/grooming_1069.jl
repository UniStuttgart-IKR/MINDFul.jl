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
    TM.testcompilation(ibnfs[1], groomintentuuid1; withremote=false)
    TM.testinstallation(ibnfs[1], intentuuid1; withremote=false)

    @test installintent!(ibnfs[1], groomintentuuid1) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], intentuuid1; withremote=false)
    TM.testinstallation(ibnfs[1], groomintentuuid1; withremote=false)

    # uninstall one
    @test uninstallintent!(ibnfs[1], groomintentuuid1) == ReturnCodes.SUCCESS
    @test getidagnodestate(groomconintent1idn) == IntentState.Compiled
    # all other remain installed
    @test all(x -> getidagnodestate(x) == IntentState.Installed, MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid1; includeroot=true))
    TM.testinstallation(ibnfs[1], intentuuid1; withremote=false)

    # uninstall also the other one
    @test uninstallintent!(ibnfs[1], intentuuid1) == ReturnCodes.SUCCESS
    @test all(x -> getidagnodestate(x) == IntentState.Compiled, MINDF.getidagnodes(getidag(ibnfs[1])))
    @test length(installedlightpathsibnfs1) == 0
    TM.testcompilation(ibnfs[1], groomintentuuid1; withremote=false)
    TM.testcompilation(ibnfs[1], intentuuid1; withremote=false)

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
    TM.testcompilation(ibnfs[1], groomandnewconintent1id; withremote=false)
    @test MINDF.issatisfied(ibnfs[1], groomandnewconintent1id; onlyinstalled=false)
    @test installintent!(ibnfs[1], groomandnewconintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], groomandnewconintent1id; withremote=false)
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

    TM.testzerostaged(ibnfs[1])

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
    TM.testcompilation(ibnfs[1], gcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], cdintent1id; withremote=true)
    @test installintent!(ibnfs[1], gcdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], gcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], cdintent1id; withremote=true)

    # uninstall 
    @test uninstallintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], cdintent1id; withremote=true)
    @test uncompileintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS
    @test isempty(MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[1]), cdintent1id))
    TM.testinstallation(ibnfs[1], gcdintent1id; withremote=true)
    @test uninstallintent!(ibnfs[1], gcdintent1id) == ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], gcdintent1id) == ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], gcdintent1id) == ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS

    foreach(ibnfs) do ibnf
        TM.testoxcfiberallocationconsistency(ibnf)
        TM.testzerostaged(ibnf)
        TM.nothingisallocated(ibnf)
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
    TM.testinstallation(ibnfs[1], cdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], lpgcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], cdintent1id) ==  ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], cdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], lpgcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], lpgcdintent1id) ==  ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], cdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], ngcdintent1id) ==  ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], cdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], ongcdintent1id) ==  ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], cdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], gongcdintent1id) ==  ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], cdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    # uncompile one by one

    @test uncompileintent!(ibnfs[1], cdintent1id) ==  ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uncompileintent!(ibnfs[1], lpgcdintent1id) ==  ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uncompileintent!(ibnfs[1], ngcdintent1id) ==  ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uncompileintent!(ibnfs[1], ongcdintent1id) ==  ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uncompileintent!(ibnfs[1], gongcdintent1id) ==  ReturnCodes.SUCCESS


    @test nv(MINDF.getidag(ibnfs[1])) == 5
    @test iszero(ne(MINDF.getidag(ibnfs[1])))
    foreach(ibnfs) do ibnf
        TM.testoxcfiberallocationconsistency(ibnf)
        TM.testzerostaged(ibnf)
        TM.nothingisallocated(ibnf)
    end


    # compile install all again 
    @test compileintent!(ibnfs[1], cdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], cdintent1id; withremote=true)
    @test installintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], cdintent1id; withremote=true)

    @test compileintent!(ibnfs[1], lpgcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], lpgcdintent1id; withremote=true)
    @test installintent!(ibnfs[1], lpgcdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], lpgcdintent1id; withremote=true)

    @test compileintent!(ibnfs[1], ngcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], ngcdintent1id; withremote=true)
    @test installintent!(ibnfs[1], ngcdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], ngcdintent1id; withremote=true)

    @test compileintent!(ibnfs[1], ongcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], ongcdintent1id; withremote=true)
    @test installintent!(ibnfs[1], ongcdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], ongcdintent1id; withremote=true)

    @test compileintent!(ibnfs[1], gongcdintent1id, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], gongcdintent1id; withremote=true)
    @test installintent!(ibnfs[1], gongcdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    # uncompiled uninstall one by one
    @test uninstallintent!(ibnfs[1], cdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], cdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], cdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], lpgcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], lpgcdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], lpgcdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], lpgcdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], ngcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], ngcdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], ngcdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], ngcdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], ongcdintent1id; withremote=true)
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], ongcdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], ongcdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], ongcdintent1id) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], gongcdintent1id; withremote=true)

    @test uninstallintent!(ibnfs[1], gongcdintent1id) ==  ReturnCodes.SUCCESS
    @test uncompileintent!(ibnfs[1], gongcdintent1id) ==  ReturnCodes.SUCCESS
    @test removeintent!(ibnfs[1], gongcdintent1id) == ReturnCodes.SUCCESS

    foreach(ibnfs) do ibnf
        TM.testoxcfiberallocationconsistency(ibnf)
        TM.testzerostaged(ibnf)
        TM.nothingisallocated(ibnf)
    end
    @test iszero(nv(MINDF.getidag(ibnfs[1])))
    @test iszero(ne(MINDF.getidag(ibnfs[1])))
end


@testset ExtendedTestSet "grooming.jl"  begin
# to test the following:
# - do not groom if external lightpath is failed


ibnfs = loadmultidomaintestidistributedbnfs()
testsuitegrooming!(ibnfs)

# TODO MA1069 : rerun testinterface with 
# ibnfs = loadmultidomaintestidistributedbnfs()
# testsuiteinterface!(ibnfs)

end
