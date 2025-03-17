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

function testlocalnodeisindex(ibnf)
    ibnag = MINDF.getibnag(ibnf)
    indices = collect(vertices(ibnag))
    localnodes = MINDF.getlocalnode.(MINDF.getnodeproperties.(MINDF.getnodeviews(ibnag)))
    @test indices == localnodes
end

"""
    Check if the IBNFramework fiber allocations are done from both endpoint oxcviews
"""
function testoxcfiberallocationconsistency(ibnf)
    nodeviews = AG.vertex_attr(MINDF.getibnag(ibnf))
    for edge in edges(MINDF.getibnag(ibnf))
        if (MINDF.isbordernode(ibnf, src(edge)) || MINDF.isbordernode(ibnf, dst(edge)))
            continue
        end
        @test MINDF.getlinkspectrumavailabilities(MINDF.getoxcview(nodeviews[src(edge)]))[edge] == MINDF.getlinkspectrumavailabilities(MINDF.getoxcview(nodeviews[dst(edge)]))[edge]
    end

    # do the same for cross domains
    borderglobaledges = MINDF.getborderglobaledges(ibnf)
    ibnag = MINDF.getibnag(ibnf)
    for ge in borderglobaledges
        for ibnfhandler in MINDF.getinteribnfs(ibnf)
            if MINDF.getibnfid(ibnfhandler) == MINDF.getibnfid(src(ge)) 
                remotespecavail = MINDF.requestspectrumavailability(ibnf, ibnfhandler, ge)
                le = Edge(MINDF.getlocalnode(ibnag, src(ge)), MINDF.getlocalnode(ibnag, dst(ge)))
                localspecavail = MINDF.getlinkspectrumavailabilities(something(MINDF.getoxcview(MINDF.getnodeview(ibnag, dst(ge) ))))[le]
                @test remotespecavail == localspecavail
            end
                
            if MINDF.getibnfid(ibnfhandler) == MINDF.getibnfid(dst(ge))
                remotespecavail = MINDF.requestspectrumavailability(ibnf, ibnfhandler, ge)
                le = Edge(MINDF.getlocalnode(ibnag, src(ge)), MINDF.getlocalnode(ibnag, dst(ge)))
                localspecavail = MINDF.getlinkspectrumavailabilities(something(MINDF.getoxcview(MINDF.getnodeview(ibnag, src(ge) ))))[le]
                @test remotespecavail == localspecavail
            end
        end
    end
    
end
