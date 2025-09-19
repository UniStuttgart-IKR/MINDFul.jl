@testset ExtendedTestSet "permissions.jl"  begin
    compalg = MINDF.KShorestPathFirstFitCompilation(5; nodenum=1)

    ibnfs = loadpermissionedbnfs(compalg)
    TM.testsuitepermissions!(ibnfs)
    MINDF.closeibnfserver(ibnfs)

end
