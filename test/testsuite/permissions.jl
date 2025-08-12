@testset ExtendedTestSet "permissions.jl"  begin

ibnfs = loadpermissionedbnfs()
TM.testsuitepermissions!(ibnfs)
MINDF.closeibnfserver(ibnfs)

end
