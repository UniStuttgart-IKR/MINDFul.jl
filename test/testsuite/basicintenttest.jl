@testset ExtendedTestSet "basicintenttest.jl"  begin
    # initialization
    domains_name_graph = first(JLD2.load(TESTDIR * "/data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]
    ag1 = first(domains_name_graph)[2]
    ibnag1 = MINDF.default_IBNAttributeGraph(ag1, 25, 25)
    ibnf1 = IBNFramework(ibnag1, KShorestPathFirstFitCompilation(ibnag1, 10))
    TM.testsuitebasicintent!(ibnf1, RUNJET)
end

nothing
