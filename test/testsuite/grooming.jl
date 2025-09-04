@testset ExtendedTestSet "grooming.jl"  begin
    # to test the following:
    # - do not groom if external lightpath is failed


    ibnfs = loadmultidomaintestibnfs()
    TM.testsuitegrooming!(ibnfs)

    ibnfs = loadmultidomaintestidistributedbnfs()
    TM.testsuitegrooming!(ibnfs)
    MINDF.closeibnfserver(ibnfs)

end
