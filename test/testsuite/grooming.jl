using MbedTLS: NetworkOptions
@testset ExtendedTestSet "grooming.jl"  begin
    # to test the following:
    # - do not groom if external lightpath is failed
    compalg = MINDF.KShorestPathFirstFitCompilation(10; nodenum=1)
    #
    ibnfs = loadmultidomaintestibnfs(compalg)
    TM.testsuitegrooming!(ibnfs)

    # ibnfs = loadmultidomaintestidistributedbnfs(compalg)
    # TM.testsuitegrooming!(ibnfs)
    # MINDF.closeibnfserver(ibnfs)

end

