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
    for nodeview in MINDF.getintranodeviews(ibnag)
        @test isempty(MINDF.getreservations(nodeview))
        routerview = MINDF.getrouterview(nodeview)
        @test isempty(MINDF.getreservations(routerview))
        oxcview = MINDF.getoxcview(nodeview)
        @test isempty(MINDF.getreservations(oxcview))
    end
end

function localnodesaregraphnodeidx(ibnag::MINDF.IBNAttributeGraph)
    localnodes = MINDF.getlocalnode.(MINDF.getnodeproperties.(MINDF.getnodeviews(MINDF.getibnag(ibnag))))
    @test localnodes == collect(1:length(localnodes))
end

macro test_nothrows(expr)
    return quote
        @test try
            $(esc(expr))
            true
        catch 
            false
        end
    end
end

function JETfilteroutfunctions(@nospecialize f) 
    # don't know what wrong with that. Maybe future julia versions will be better. Check every now and then.
    return f !== MINDF.updateidagstates!
end
