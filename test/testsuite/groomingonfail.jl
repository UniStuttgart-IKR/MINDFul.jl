# @testset ExtendedTestSet "groomingonfail.jl"  begin
    compalg = MINDF.KShorestPathFirstFitCompilation(10; nodenum=1)

    ibnfs = loadmultidomaintestibnfs(compalg)
    TM.testsuitegroomingonfail!(ibnfs)

# end
