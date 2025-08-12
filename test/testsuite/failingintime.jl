@testset ExtendedTestSet "failingtime.jl"  begin

ibnfs = loadmultidomaintestibnfs()
TM.testsuitefailingintime!(ibnfs)

# TODO MA1069 : rerun testinterface with 
ibnfs = loadmultidomaintestidistributedbnfs()
TM.testsuitefailingintime!(ibnfs)
MINDF.closeibnfserver(ibnfs)
end
