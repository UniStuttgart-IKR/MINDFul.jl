function testsuitemultidomain!(ibnfs)
    # with border node
    conintent_bordernode = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 25), u"100.0Gbps")
    intentuuid_bordernode = addintent!(ibnfs[1], conintent_bordernode, NetworkOperator())

    @test compileintent!(ibnfs[1], intentuuid_bordernode, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], intentuuid_bordernode; withremote=true)
 
    # install
    @test installintent!(ibnfs[1], intentuuid_bordernode; verbose=true) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], intentuuid_bordernode; withremote=true)

    # uninstall
    @test uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose=true) == ReturnCodes.SUCCESS
    TM.testuninstallation(ibnfs[1], intentuuid_bordernode; withremote=true)

    # uncompile
    @test uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose=true) == ReturnCodes.SUCCESS
    TM.testuncompilation(ibnfs[1], intentuuid_bordernode)
    @test nv(getidag(ibnfs[1])) == 1
    @test nv(getidag(ibnfs[3])) == 0

    # to neighboring domain
    conintent_neigh = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 47), u"100.0Gbps")
    intentuuid_neigh = addintent!(ibnfs[1], conintent_neigh, NetworkOperator())

    @test compileintent!(ibnfs[1], intentuuid_neigh, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    TM.testcompilation(ibnfs[1], intentuuid_neigh; withremote=true)

    @test installintent!(ibnfs[1], intentuuid_neigh; verbose=true) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnfs[1], intentuuid_neigh; withremote=true)

    @test uninstallintent!(ibnfs[1], intentuuid_neigh; verbose=true) == ReturnCodes.SUCCESS
    TM.testuninstallation(ibnfs[1], intentuuid_neigh; withremote=true)

    @test uncompileintent!(ibnfs[1], intentuuid_neigh; verbose=true) == ReturnCodes.SUCCESS
    TM.testuncompilation(ibnfs[1], intentuuid_neigh)
    @test nv(getidag(ibnfs[1])) == 2
    @test nv(getidag(ibnfs[3])) == 0
    # to unknown domain
 
    foreach(ibnfs) do ibnf
        TM.testoxcfiberallocationconsistency(ibnf)
        TM.testzerostaged(ibnf)
    end
end

@testset ExtendedTestSet "multidomain.jl"  begin


# ibnfs = loadmultidomaintestibnfs()
# testsuitemultidomain!(ibnfs)

# TODO MA1069 : rerun testinterface with 
ibnfs = loadmultidomaintestidistributedbnfs()
testsuitemultidomain!(ibnfs)

end
