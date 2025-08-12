@testset ExtendedTestSet "interface.jl"  begin


ibnfs = loadmultidomaintestibnfs()
TM.testsuiteinterface!(ibnfs)

# TODO MA1069 : rerun testinterface with 
ibnfs = loadmultidomaintestidistributedbnfs()
TM.testsuiteinterface!(ibnfs)
MINDF.closeibnfserver(ibnfs)


end
