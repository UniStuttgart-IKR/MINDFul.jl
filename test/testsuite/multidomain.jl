@testset ExtendedTestSet "multidomain.jl"  begin
    ibnfs = loadmultidomaintestibnfs()
    # testsuitemultidomain!(ibnfs)
    TM.testsuitemultidomain!(ibnfs)

    # TODO MA1069 : rerun testinterface with
    ibnfs = loadmultidomaintestidistributedbnfs()
    TM.testsuitemultidomain!(ibnfs)
    MINDF.closeibnfserver(ibnfs)
end
