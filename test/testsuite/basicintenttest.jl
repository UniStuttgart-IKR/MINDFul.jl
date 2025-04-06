@testset ExtendedTestSet "basicintenttest.jl"  begin
    # initialization
    domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]
    ag1 = first(domains_name_graph)[2]
    ibnag1 = MINDF.default_IBNAttributeGraph(ag1)
    ibnf1 = MINDF.IBNFramework(ibnag1)

    testlocalnodeisindex(ibnf1)
    testoxcfiberallocationconsistency(ibnf1)

    conintent1 = MINDF.ConnectivityIntent(MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 4), MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 8), u"100.0Gbps")

    intentuuid1 = MINDF.addintent!(ibnf1, conintent1, MINDF.NetworkOperator())
    @test nv(MINDF.getidag(ibnf1)) == 1
    @test intentuuid1 isa UUID
    @test MINDF.getidagnodestate(MINDF.getidag(ibnf1), intentuuid1) == MINDF.IntentState.Uncompiled
    @test isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf1), intentuuid1))

    RUNJET && @test_opt broken=true target_modules=[MINDF] function_filter=JETfilteroutfunctions MINDF.compileintent!(ibnf1, MINDF.getidagnode(MINDF.getidag(ibnf1), intentuuid1), MINDF.KShorestPathFirstFitCompilation(10))
    @test MINDF.compileintent!(ibnf1, intentuuid1, MINDF.KShorestPathFirstFitCompilation(10))
    testcompilation(ibnf1, intentuuid1; withremote=false)

    @test MINDF.installintent!(ibnf1, intentuuid1)
    testinstallation(ibnf1, intentuuid1; withremote=false)

    @test MINDF.uninstallintent!(ibnf1, intentuuid1)
    testuninstallation(ibnf1, intentuuid1; withremote=false)

    @test MINDF.uncompileintent!(ibnf1, UUID(1))
    testuncompilation(ibnf1, intentuuid1)
    @test nv(MINDF.getidag(ibnf1)) == 1

    nothingisallocated(ibnf1)

    @test MINDF.removeintent!(ibnf1, intentuuid1)
    @test nv(MINDF.getidag(ibnf1)) == 0

    testoxcfiberallocationconsistency(ibnf1)
end

# nothing
