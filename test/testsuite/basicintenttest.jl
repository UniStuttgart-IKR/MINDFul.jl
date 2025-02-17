@testset ExtendedTestSet "basicintenttest.jl"  begin
    # initialization
    domains_name_graph = first(JLD2.load("data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]
    ag1 = first(domains_name_graph)[2]
    ibnag1 = MINDF.default_IBNAttributeGraph(ag1)
    ibnf1 = MINDF.IBNFramework(ibnag1)

    conintent1 = MINDF.ConnectivityIntent(MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 4), MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 8), u"100Gbps")

    intentuuid1 = MINDF.addintent!(ibnf1, conintent1, MINDF.NetworkOperator())
    @test nv(MINDF.getidag(ibnf1)) == 1
    @test intentuuid1 isa UUID
    @test MINDF.getidagnodestate(MINDF.getidag(ibnf1), intentuuid1) == MINDF.IntentState.Uncompiled
    @test isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf1), intentuuid1))

    MINDF.compileintent!(ibnf1, intentuuid1, MINDF.KShorestPathFirstFitCompilation(10))
    @test MINDF.getidagnodestate(MINDF.getidag(ibnf1), intentuuid1) == MINDF.IntentState.Compiled
    @test !isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf1), intentuuid1))
    @test MINDF.issatisfied(ibnf1, intentuuid1; onlyinstalled=false)

    @test MINDF.installintent!(ibnf1, intentuuid1)

    leafs = MINDF.getidagnodeleafs(MINDF.getidag(ibnf1), intentuuid1)
    @test all(x -> MINDF.getintent(x) isa MINDF.LowLevelIntent, leafs)
    @test all(x -> MINDF.getidagnodestate(x) == MINDF.IntentState.Installed, leafs)
    @test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnf1), intentuuid1)) == MINDF.IntentState.Installed
    orderedllis = MINDF.LowLevelIntent[]
    @test MINDF.issatisfied(ibnf1, intentuuid1; orderedllis = orderedllis)

    foreach(orderedllis) do olli
        islowlevelintentdagnodeinstalled(ibnf1, olli)
    end

    @test MINDF.uninstallintent!(ibnf1, intentuuid1)
    @test all(x -> MINDF.getidagnodestate(x) == MINDF.IntentState.Compiled, leafs)
    @test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnf1), intentuuid1)) == MINDF.IntentState.Compiled
    @test !MINDF.issatisfied(ibnf1, intentuuid1; onlyinstalled=true)
    @test MINDF.issatisfied(ibnf1, intentuuid1; onlyinstalled=false)
    
    for nodeview in MINDF.getnodeviews(MINDF.getibnag(ibnf1))
        @test isempty(MINDF.getreservations(nodeview))
        @test isempty(MINDF.getreservations(MINDF.getrouterview(nodeview)))
        @test isempty(MINDF.getreservations(MINDF.getoxcview(nodeview)))
    end

    @test MINDF.uncompileintent!(ibnf1, UUID(1))
    @test isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf1), intentuuid1))
    @test nv(MINDF.getidag(ibnf1)) == 1
    @test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnf1), intentuuid1)) == MINDF.IntentState.Uncompiled
    nothingisallocated(ibnf1)

    @test MINDF.removeintent!(ibnf1, intentuuid1)
    @test nv(MINDF.getidag(ibnf1)) == 0
end
