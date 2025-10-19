@testset ExtendedTestSet "installingstate.jl"  begin
    compalg = MINDF.BestEmpiricalAvailabilityCompilation(10, 5; nodenum=1)
    #
    nowtime = DateTime("2026-01-01")
    ibnfs = loadmultidomaintestibnfs(compalg, nowtime)

    conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"105.0Gbps")

    intentuuid1, _ = addintent!(ibnfs[1], conintent1, NetworkOperator())
    returncode, nowtime = compileintent!(ibnfs[1], intentuuid1)
    returncode, nowtime = installintent!(ibnfs[1], intentuuid1)
    returncode, nowtime = uninstallintent!(ibnfs[1], intentuuid1; forceinstallable=true)

    @test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1) == MINDF.IntentState.Installing
end
