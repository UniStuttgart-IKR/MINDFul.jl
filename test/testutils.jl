function islowlevelintentdagnodeinstalled(ibnf::MINDF.IBNFramework, lli::MINDF.LowLevelIntent)
    ibnag = MINDF.getibnag(ibnf)
    nodeview = MINDF.getnodeview(ibnag, MINDF.getlocalnode(lli))
    if lli isa MINDF.RouterPortLLI
        routerview = MINDF.getrouterview(nodeview)
        @test lli in values(MINDF.getreservations(routerview))
    elseif lli isa MINDF.TransmissionModuleLLI
        @test lli in values(MINDF.getreservations(nodeview))
    elseif lli isa MINDF.OXCAddDropBypassSpectrumLLI
        oxcview = MINDF.getoxcview(nodeview)
        @test lli in values(MINDF.getreservations(oxcview))
    end
end

function nothingisallocated(ibnf::MINDF.IBNFramework)
    ibnag = MINDF.getibnag(ibnf)
    for localnode in vertices(ibnag)
        nodeview = MINDF.getnodeview(ibnag, localnode)
        @test isempty(MINDF.getreservations(nodeview))
        routerview = MINDF.getrouterview(nodeview)
        @test isempty(MINDF.getreservations(routerview))
        oxcview = MINDF.getoxcview(nodeview)
        @test isempty(MINDF.getreservations(oxcview))
    end
end
