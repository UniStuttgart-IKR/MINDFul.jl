@testset ExtendedTestSet "physicaltest.jl"  begin
    # initialization
    ibnag1 = loadsingledomaintestibnag()
    TM.testsuitephysical!(ibnag1, runjet())
end
