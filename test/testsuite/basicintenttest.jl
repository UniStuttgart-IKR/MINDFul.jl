@testset ExtendedTestSet "basicintenttest.jl"  begin
    # initialization
    domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]
    ag1 = first(domains_name_graph)[2]
    ibnag1 = MINDF.default_IBNAttributeGraph(ag1)
    ibnf1 = IBNFramework(ibnag1)

    TM.testlocalnodeisindex(ibnf1)
    TM.testoxcfiberallocationconsistency(ibnf1)

    conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnf1), 4), GlobalNode(getibnfid(ibnf1), 8), u"100.0Gbps")

    intentuuid1 = addintent!(ibnf1, conintent1, NetworkOperator())
    @test nv(getidag(ibnf1)) == 1
    @test intentuuid1 isa UUID
    @test getidagnodestate(getidag(ibnf1), intentuuid1) == IntentState.Uncompiled
    @test isempty(getidagnodechildren(getidag(ibnf1), intentuuid1))

    RUNJET && @test_opt broken=true target_modules=[MINDF] function_filter=TM.JETfilteroutfunctions compileintent!(ibnf1, getidagnode(getidag(ibnf1), intentuuid1), KShorestPathFirstFitCompilation(10))
    @test compileintent!(ibnf1, intentuuid1, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    TM.testcompilation(ibnf1, intentuuid1; withremote=false)

    @test installintent!(ibnf1, intentuuid1) == ReturnCodes.SUCCESS
    TM.testinstallation(ibnf1, intentuuid1; withremote=false)

    @test uninstallintent!(ibnf1, intentuuid1) == ReturnCodes.SUCCESS
    TM.testuninstallation(ibnf1, intentuuid1; withremote=false)

    @test uncompileintent!(ibnf1, UUID(1)) == ReturnCodes.SUCCESS
    TM.testuncompilation(ibnf1, intentuuid1)
    @test nv(getidag(ibnf1)) == 1

    TM.nothingisallocated(ibnf1)

    @test removeintent!(ibnf1, intentuuid1) == ReturnCodes.SUCCESS
    @test nv(getidag(ibnf1)) == 0

    TM.testoxcfiberallocationconsistency(ibnf1)
    TM.testzerostaged(ibnf1)
end

# nothing
