@testset ExtendedTestSet "interface.jl"  begin
    compalg = MINDF.KShorestPathFirstFitCompilation(5; nodenum=1)

    ibnfs = loadmultidomaintestibnfs(compalg)
    TM.testsuiteinterface!(ibnfs)

    # ibnfs = loadmultidomaintestidistributedbnfs(compalg)
    # TM.testsuiteinterface!(ibnfs)
    # MINDF.closeibnfserver(ibnfs)


end
