@testset ExtendedTestSet "failingtime.jl"  begin

    ibnfs = loadmultidomaintestibnfs()
    TM.testsuitefailingintime!(ibnfs)

    ibnfs = loadmultidomaintestidistributedbnfs()
    TM.testsuitefailingintime!(ibnfs)
    MINDF.closeibnfserver(ibnfs)
end
