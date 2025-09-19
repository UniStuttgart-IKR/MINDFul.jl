@testset ExtendedTestSet "opticalconstraintssingledomain.jl"  begin

    kspffcomp = KShorestPathFirstFitCompilation(10; nodenum=1)

    ibnfs = loadmultidomaintestibnfs(kspffcomp)
    TM.testsuiteopticalconstraintssingledomain!(ibnfs)

end

nothing
