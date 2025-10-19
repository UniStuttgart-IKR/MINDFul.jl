@testset ExtendedTestSet "multidomain.jl"  begin
    compalg = KShorestPathFirstFitCompilation(10; nodenum=1)

    ibnfs = loadmultidomaintestibnfs(compalg)
    TM.testsuitemultidomain!(ibnfs)

    # ibnfs = loadmultidomaintestidistributedbnfs(compalg)
    # TM.testsuitemultidomain!(ibnfs)
    # MINDF.closeibnfserver(ibnfs)
end

nothing
