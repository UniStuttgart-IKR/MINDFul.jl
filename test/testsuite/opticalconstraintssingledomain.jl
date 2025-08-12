@testset ExtendedTestSet "opticalconstraintssingledomain.jl"  begin

ibnfs = loadmultidomaintestibnfs()
TM.testsuiteopticalconstraintssingledomain!(ibnfs)

end

nothing
