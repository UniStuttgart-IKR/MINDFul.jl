@testset ExtendedTestSet "interface.jl"  begin


    ibnfs = loadmultidomaintestibnfs()
    TM.testsuiteinterface!(ibnfs)

    ibnfs = loadmultidomaintestidistributedbnfs()
    TM.testsuiteinterface!(ibnfs)
    MINDF.closeibnfserver(ibnfs)


end
