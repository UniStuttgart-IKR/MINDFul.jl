function testsuitepermissions!(ibnfs)
    conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(1), 4), MINDFul.GlobalNode(UUID(3), 25), u"100.0Gbps")
    intentuuid_bordernode = MINDFul.addintent!(ibnfs[1], conintent_bordernode, MINDFul.NetworkOperator())
    @test MINDFul.compileintent!(ibnfs[1], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS

    conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(3), 25), MINDFul.GlobalNode(UUID(1), 4), u"100.0Gbps")
    intentuuid_bordernode = MINDFul.addintent!(ibnfs[3], conintent_bordernode, MINDFul.NetworkOperator())
    @test MINDFul.compileintent!(ibnfs[3], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10)) == ReturnCodes.FAIL_NO_PERMISSION
    
end

@testset ExtendedTestSet "permissions.jl"  begin

ibnfs = loadmultidomaintestidistributedbnfs()
testsuitepermissions!(ibnfs)
MINDF.closeibnfserver(ibnfs)

end