@testset ExtendedTestSet "failingtime.jl"  begin
    compalg = MINDF.BestEmpiricalAvailabilityCompilation(10, 5; nodenum=1)
    #
    nowtime = DateTime("2026-01-01")
    ibnfs = loadmultidomaintestibnfs(compalg, nowtime)
    TM.testsuitefailingintime!(ibnfs, nowtime)

    ibnfs = loadmultidomaintestidistributedbnfs(compalg, nowtime)
    TM.testsuitefailingintime!(ibnfs, nowtime)
    MINDF.closeibnfserver(ibnfs)
end
