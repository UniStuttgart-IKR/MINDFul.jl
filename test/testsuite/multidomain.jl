@testset ExtendedTestSet "multidomain.jl"  begin
    ibnfs = loadmultidomaintestibnfs()
    TM.testsuitemultidomain!(ibnfs)

    ibnfs = loadmultidomaintestidistributedbnfs()
    TM.testsuitemultidomain!(ibnfs)
    MINDF.closeibnfserver(ibnfs)
end
