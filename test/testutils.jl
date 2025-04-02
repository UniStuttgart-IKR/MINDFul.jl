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
    return f !== MINDF.updateidagstates! &&
    # ibnhandlers are generally type unstable, but I think this shouldn't be a problem because I access type stable fields...
        f !== MINDF.requestspectrumavailability && 
    # although I think the logic is there to be type stable, the compiler struggles
        f !== MINDF.getopticalinitiateconstraint
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
        for ibnfhandler in MINDF.getibnfhandlers(ibnf)
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

function testcompilation(ibnf::MINDF.IBNFramework, idagnodeid::UUID; withremote::Bool=false)
    @test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnf), idagnodeid)) == MINDF.IntentState.Compiled
    @test !isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf), idagnodeid))
    @test all(==(MINDF.IntentState.Compiled),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid)))
    @test MINDF.issatisfied(ibnf, idagnodeid; onlyinstalled=false, noextrallis=false)
    @test !MINDF.issatisfied(ibnf, idagnodeid; onlyinstalled=true, noextrallis=false)

    if withremote
        foreach(MINDF.getidagnodeid.(MINDF.getidagnodechildren(MINDF.getidag(ibnf), idagnodeid))) do intentuuid
            @test MINDF.issatisfied(ibnf, intentuuid; onlyinstalled=false, noextrallis=false)
        end
        @test count(x -> MINDF.getintent(x) isa MINDF.RemoteIntent, MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid)) == 1
        idagnoderemoteintent = MINDF.getfirst(x -> MINDF.getintent(x) isa MINDF.RemoteIntent, MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid))
        @test !isnothing(idagnoderemoteintent)
        remoteintent_bordernode = MINDF.getintent(idagnoderemoteintent)
        ibnfhandler_bordernode = MINDF.getibnfhandler(ibnf, MINDF.getibnfid(remoteintent_bordernode))
        idagnodeid_remote_bordernode = MINDF.getidagnodeid(remoteintent_bordernode)
        @test MINDF.requestissatisfied(ibnf, ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=false, noextrallis=true)
        if ibnfhandler_bordernode isa MINDF.IBNFramework
            @test MINDF.issatisfied(ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=false, noextrallis=true)
            @test all(==(MINDF.IntentState.Compiled),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnfhandler_bordernode), idagnodeid_remote_bordernode)))
        end
    end
end

function testinstallation(ibnf::MINDF.IBNFramework, idagnodeid::UUID; withremote::Bool=false)
    leafs = MINDF.getidagnodeleafs(MINDF.getidag(ibnf), idagnodeid)
    @test all(x -> MINDF.getintent(x) isa MINDF.LowLevelIntent || MINDF.getintent(x) isa MINDF.RemoteIntent, leafs)

    @test all(==(MINDF.IntentState.Installed),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid)))
    @test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnf), idagnodeid)) == MINDF.IntentState.Installed
    @test MINDF.issatisfied(ibnf, idagnodeid; onlyinstalled=true, noextrallis=false)

    orderedllis = MINDF.getlogicallliorder(ibnf, idagnodeid)
    foreach(orderedllis) do olli
        islowlevelintentdagnodeinstalled(ibnf, olli)
    end

    # check that allocations are non empty
    @test any(nodeview -> !isempty(MINDF.getreservations(nodeview)), MINDF.getintranodeviews(MINDF.getibnag(ibnf)))
    @test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getrouterview(nodeview))), MINDF.getintranodeviews(MINDF.getibnag(ibnf)))
    @test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getoxcview(nodeview))), MINDF.getintranodeviews(MINDF.getibnag(ibnf)))

    if withremote
        foreach(MINDF.getidagnodeid.(MINDF.getidagnodechildren(MINDF.getidag(ibnf), idagnodeid))) do intentuuid
            @test MINDF.issatisfied(ibnf, intentuuid; onlyinstalled=true, noextrallis=false)
        end

        @test count(x -> MINDF.getintent(x) isa MINDF.RemoteIntent, MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid)) == 1
        idagnoderemoteintent = MINDF.getfirst(x -> MINDF.getintent(x) isa MINDF.RemoteIntent, MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid))
        @test !isnothing(idagnoderemoteintent)
        remoteintent_bordernode = MINDF.getintent(idagnoderemoteintent)
        ibnfhandler_bordernode = MINDF.getibnfhandler(ibnf, MINDF.getibnfid(remoteintent_bordernode))
        idagnodeid_remote_bordernode = MINDF.getidagnodeid(remoteintent_bordernode)
        
        @test MINDF.requestissatisfied(ibnf, ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=true, noextrallis=true)
        
        if ibnfhandler_bordernode isa MINDF.IBNFramework
            @test MINDF.issatisfied(ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=true, noextrallis=true)
            @test all(==(MINDF.IntentState.Installed),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnfhandler_bordernode), idagnodeid_remote_bordernode)))
        
            orderedllis = MINDF.getlogicallliorder(ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=true, verbose=false)
            foreach(orderedllis) do olli
                islowlevelintentdagnodeinstalled(ibnfhandler_bordernode, olli)
            end
    
            # check that allocations are non empty
            @test any(nodeview -> !isempty(MINDF.getreservations(nodeview)), MINDF.getintranodeviews(MINDF.getibnag(ibnfhandler_bordernode)))
            @test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getrouterview(nodeview))), MINDF.getintranodeviews(MINDF.getibnag(ibnfhandler_bordernode)))
            @test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getoxcview(nodeview))), MINDF.getintranodeviews(MINDF.getibnag(ibnfhandler_bordernode)))
        end
    end
end

function testuninstallation(ibnf::MINDF.IBNFramework, idagnodeid::UUID; withremote::Bool=false, shouldempty=false)
    @test all(==(MINDF.IntentState.Compiled),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid)))
    @test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnf), idagnodeid)) == MINDF.IntentState.Compiled
    MINDF.issatisfied(ibnf, idagnodeid; onlyinstalled=false, noextrallis=false)
    @test !MINDF.issatisfied(ibnf, idagnodeid; onlyinstalled=true, noextrallis=false)

    # check that allocations are empty
    if shouldempty
        nothingisallocated(ibnf)
    end

    if withremote
        @test count(x -> MINDF.getintent(x) isa MINDF.RemoteIntent, MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid)) == 1
        idagnoderemoteintent = MINDF.getfirst(x -> MINDF.getintent(x) isa MINDF.RemoteIntent, MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid))
        @test !isnothing(idagnoderemoteintent)
        remoteintent_bordernode = MINDF.getintent(idagnoderemoteintent)
        ibnfhandler_bordernode = MINDF.getibnfhandler(ibnf, MINDF.getibnfid(remoteintent_bordernode))
        idagnodeid_remote_bordernode = MINDF.getidagnodeid(remoteintent_bordernode)

        if ibnfhandler_bordernode isa MINDF.IBNFramework
            if shouldempty
                nothingisallocated(ibnfhandler_bordernode)
            end
        end
    end
end

function testuncompilation(ibnf::MINDF.IBNFramework, idagnodeid::UUID)
    @test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnf), idagnodeid)) == MINDF.IntentState.Uncompiled
    @test isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf), idagnodeid))
end
