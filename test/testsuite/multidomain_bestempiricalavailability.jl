function testsuiteheacomp!(ibnfs, RUNJET)
    # with border node
    conintent_bordernode = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 25), u"100.0Gbps")
    intentuuid_bordernode, _ = addintent!(ibnfs[1], conintent_bordernode, NetworkOperator())

    returncode, nowtime = compileintent!(ibnfs[1], intentuuid_bordernode)
    @test returncode == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], intentuuid_bordernode; withremote = true)

    # install
    returncode, nowtime = installintent!(ibnfs[1], intentuuid_bordernode; verbose = false)
    @test returncode == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], intentuuid_bordernode; withremote = true)

    # uninstall
    returncode, nowtime =  uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose = false)
    @test returncode == ReturnCodes.SUCCESS
    TM.testuninstallation(ibnfs[1], intentuuid_bordernode; withremote = true)

    # uncompile
    returncode, nowtime =  uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose = false)
    @test returncode == ReturnCodes.SUCCESS
    TM.testuncompilation(ibnfs[1], intentuuid_bordernode)
    @test nv(getidag(ibnfs[1])) == 1
    @test nv(getidag(ibnfs[3])) == 0

    # to neighboring domain
    conintent_neigh = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 47), u"100.0Gbps")
    intentuuid_neigh, _ = addintent!(ibnfs[1], conintent_neigh, NetworkOperator())

    returncode, nowtime = compileintent!(ibnfs[1], intentuuid_neigh)
    @test returncode == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], intentuuid_neigh; withremote = true)

    returncode, nowtime = installintent!(ibnfs[1], intentuuid_neigh; verbose = false)
    @test returncode == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], intentuuid_neigh; withremote = true)

    returncode, nowtime = uninstallintent!(ibnfs[1], intentuuid_neigh; verbose = false)
    @test returncode == ReturnCodes.SUCCESS
    TM.testuninstallation(ibnfs[1], intentuuid_neigh; withremote = true)

    returncode, nowtime = uncompileintent!(ibnfs[1], intentuuid_neigh; verbose = false)
    @test returncode == ReturnCodes.SUCCESS
    TM.testuncompilation(ibnfs[1], intentuuid_neigh)
    @test nv(getidag(ibnfs[1])) == 2
    @test nv(getidag(ibnfs[3])) == 0
    # to unknown domain

    return foreach(ibnfs) do ibnf
        TM.testoxcfiberallocationconsistency(ibnf)
        TM.testzerostaged(ibnf)
    end
end

@testset ExtendedTestSet "multidomain_bestempiricalavailability.jl"  begin
    # initialization
    compalg = MINDF.BestEmpiricalAvailabilityCompilation(10, 5; nodenum=1)

    ibnfs = loadmultidomaintestibnfs(compalg)
    testsuiteheacomp!(ibnfs, RUNJET)
end


