@testset ExtendedTestSet "basicintenttest.jl"  begin
# initialization
domains_name_graph = first(JLD2.load("data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]
ag1 = first(domains_name_graph)[2]
ibnag1 = MINDF.default_IBNAttributeGraph(ag1)
ibnf1 = MINDF.IBNFramework(ibnag1)

conintent1 = MINDF.ConnectivityIntent(MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 4), MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 8), u"100Gbps")

intentuuid1 = MINDF.addintent!(ibnf1, conintent1, MINDF.NetworkOperator())
@test intentuuid1 isa UUID
@test MINDF.getidagnodestate(MINDF.getidag(ibnf1), intentuuid1) == MINDF.IntentState.Uncompiled
@test isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf1), intentuuid1))

MINDF.compileintent!(ibnf1, intentuuid1, MINDF.KShorestPathFirstFitCompilation(10))
@test MINDF.getidagnodestate(MINDF.getidag(ibnf1), intentuuid1) == MINDF.IntentState.Compiled
@test !isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf1), intentuuid1))
@test MINDF.issatisfied(ibnf1, intentuuid1)


end

