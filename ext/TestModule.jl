module TestModule

using DocStringExtensions, UUIDs, Graphs
import HTTP
import MINDFul as MINDF
import AttributeGraphs as AG

import MINDFul: getibnag, getoxcview, getrouterview, getstaged, NodeView, getglobalnode, isbordernode, requestlinkstates_init, GlobalEdge, getnodeview, getlinkstates, getibnfhandler, getibnfid, IBNFramework, getreservations, getidag

# weak dependencies
using Test, JET


function islowlevelintentdagnodeinstalled(ibnf::MINDF.IBNFramework, lli::MINDF.LowLevelIntent)
    return islowlevelintentdagnodeinstalled(getibnag(ibnf), lli)
end
"""
$(TYPEDSIGNATURES)
"""
function islowlevelintentdagnodeinstalled(ibnag::MINDF.IBNAttributeGraph, lli::MINDF.LowLevelIntent)
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
    return nothingisallocated(getibnag(ibnf))
end

"""
$(TYPEDSIGNATURES)
"""
function nothingisallocated(ibnag::MINDF.IBNAttributeGraph)
    for nodeview in MINDF.getintranodeviews(ibnag)
        @test isempty(MINDF.getreservations(nodeview))
        routerview = MINDF.getrouterview(nodeview)
        @test isempty(MINDF.getreservations(routerview))
        oxcview = MINDF.getoxcview(nodeview)
        @test isempty(MINDF.getreservations(oxcview))
    end
end

"""
$(TYPEDSIGNATURES)
"""
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

macro test_permissionsthrows(expr)
    return quote
        @test try
            $(esc(expr))
            false
        catch e
            if isa(e, HTTP.Exceptions.StatusError)
                true
            else
                false
            end
        end
    end
end

"""
$(TYPEDSIGNATURES)
"""
function JETfilteroutfunctions(@nospecialize f) 
    # don't know what wrong with that. Maybe future julia versions will be better. Check every now and then.
    return f !== MINDF.updateidagstates! &&
    # ibnhandlers are generally type unstable, but I think this shouldn't be a problem because I access type stable fields...
        f !== MINDF.requestspectrumavailability_init! && 
    # although I think the logic is there to be type stable, the compiler struggles
        f !== MINDF.getopticalinitiateconstraint
end

"""
$(TYPEDSIGNATURES)
"""
function testlocalnodeisindex(ibnf)
    ibnag = MINDF.getibnag(ibnf)
    indices = collect(vertices(ibnag))
    localnodes = MINDF.getlocalnode.(MINDF.getnodeproperties.(MINDF.getnodeviews(ibnag)))
    @test indices == localnodes
end

"""
$(TYPEDSIGNATURES)
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
        firstenter = true
        for ibnfhandler in MINDF.getibnfhandlers(ibnf)
            if !(ibnfhandler isa IBNFramework) # if there are HTTP handlers the first one is the self
                if firstenter 
                    firstenter = false
                    continue
                end
            end
            if MINDF.getibnfid(ibnfhandler) == MINDF.getibnfid(src(ge)) 
                remotespecavail = MINDF.requestspectrumavailability_init!(ibnf, ibnfhandler, ge)
                le = Edge(MINDF.getlocalnode(ibnag, src(ge)), MINDF.getlocalnode(ibnag, dst(ge)))
                localspecavail = MINDF.getlinkspectrumavailabilities(something(MINDF.getoxcview(MINDF.getnodeview(ibnag, dst(ge) ))))[le]
                @test remotespecavail == localspecavail
            end
                
            if MINDF.getibnfid(ibnfhandler) == MINDF.getibnfid(dst(ge))
                remotespecavail = MINDF.requestspectrumavailability_init!(ibnf, ibnfhandler, ge)
                le = Edge(MINDF.getlocalnode(ibnag, src(ge)), MINDF.getlocalnode(ibnag, dst(ge)))
                localspecavail = MINDF.getlinkspectrumavailabilities(something(MINDF.getoxcview(MINDF.getnodeview(ibnag, src(ge) ))))[le]
                @test remotespecavail == localspecavail
            end
        end
    end
    
end

"""
$(TYPEDSIGNATURES)
"""
function testcompilation(ibnf::MINDF.IBNFramework, idagnodeid::UUID; withremote::Bool=false)
    @test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnf), idagnodeid)) == MINDF.IntentState.Compiled
    @test !isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf), idagnodeid))
    if !MINDF.issubdaggrooming(getidag(ibnf), idagnodeid)
        @test all(==(MINDF.IntentState.Compiled),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid)))
    else
        @test all(x -> x in [MINDF.IntentState.Compiled, MINDF.IntentState.Installed],MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid)))
    end
    @test MINDF.issatisfied(ibnf, idagnodeid; onlyinstalled=false, noextrallis=false)
    if !MINDF.issubdaggrooming(getidag(ibnf), idagnodeid)
        @test !MINDF.issatisfied(ibnf, idagnodeid; onlyinstalled=true, noextrallis=false)
    end

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
        @test MINDF.requestissatisfied_init(ibnf, ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=false, noextrallis=true)
        # if ibnfhandler_bordernode isa MINDF.IBNFramework
        @test MINDF.requestissatisfied_init(ibnf, ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=false, noextrallis=true)
        if !MINDF.issubdaggrooming(getidag(ibnf), idagnodeid)
            @test all(==(MINDF.IntentState.Compiled),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.requestidag_init(ibnf, ibnfhandler_bordernode), idagnodeid_remote_bordernode)))
        else
            @test all(x -> x in [MINDF.IntentState.Compiled, MINDF.IntentState.Installed],MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.requestidag_init(ibnf, ibnfhandler_bordernode), idagnodeid_remote_bordernode)))
        end
    end
end

"""
$(TYPEDSIGNATURES)
"""
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
        
        @test MINDF.requestissatisfied_init(ibnf, ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=true, noextrallis=true)
        
        # if ibnfhandler_bordernode isa MINDF.IBNFramework
        @test MINDF.requestissatisfied_init(ibnf, ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=true, noextrallis=true)
        @test all(==(MINDF.IntentState.Installed),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.requestidag_init(ibnf, ibnfhandler_bordernode), idagnodeid_remote_bordernode)))
    
        ibnfhandler_bordernode_ibnag = MINDF.requestibnattributegraph_init(ibnf, ibnfhandler_bordernode)
        orderedllis = MINDF.requestlogicallliorder_init(ibnf, ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=true, verbose=false)
        foreach(orderedllis) do olli
            islowlevelintentdagnodeinstalled(ibnfhandler_bordernode_ibnag, olli)
        end

        # check that allocations are non empty
        @test any(nodeview -> !isempty(MINDF.getreservations(nodeview)), MINDF.getintranodeviews(ibnfhandler_bordernode_ibnag))
        @test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getrouterview(nodeview))), MINDF.getintranodeviews(ibnfhandler_bordernode_ibnag))
        @test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getoxcview(nodeview))), MINDF.getintranodeviews(ibnfhandler_bordernode_ibnag))
    end
end

"""
$(TYPEDSIGNATURES)
"""
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
        
        if shouldempty
            nothingisallocated(MINDF.requestibnattributegraph_init(ibn, ibnfhandler_bordernode))
        end
    end
end

"""
$(TYPEDSIGNATURES)
"""
function testuncompilation(ibnf::MINDF.IBNFramework, idagnodeid::UUID)
    @test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnf), idagnodeid)) == MINDF.IntentState.Uncompiled
    @test isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnf), idagnodeid))
end

function testexpectedfaileddag(idag::MINDF.IntentDAG, idagnodeid::UUID, failededge::Edge, numberoffailedoxcllis::Int)
    oxclliidagnodewithedge = filter(MINDF.getidagnodedescendants(idag, idagnodeid)) do idagnode
        MINDF.getintent(idagnode) isa MINDF.OXCAddDropBypassSpectrumLLI && MINDF.oxcllicontainsedge(MINDF.getintent(idagnode), failededge)
    end
    @test length(oxclliidagnodewithedge) == numberoffailedoxcllis
    @test all([MINDF.getidagnodestate(idagnode) == MINDF.IntentState.Failed for idagnode in oxclliidagnodewithedge])
end

function getfirstremoteintent(ibnf::MINDF.IBNFramework, idagnodeid::UUID)
    remoteintent = MINDF.getfirst(MINDF.getintent.(MINDF.getidagnodedescendants(MINDF.getidag(ibnf), idagnodeid))) do intent
        intent isa MINDF.RemoteIntent && MINDF.getisinitiator(intent)
    end
    @test !isnothing(remoteintent)
    MINDF.getibnfid(remoteintent), MINDF.getidagnodeid(remoteintent)
end

function testzerostaged(ibnf::MINDF.IBNFramework)
    for nodeview in MINDF.getintranodeviews(getibnag(ibnf))
        @test isempty(getstaged(nodeview))
        @test isempty(getstaged(getoxcview(nodeview)))
        @test isempty(getstaged(getrouterview(nodeview)))
    end
end

function testzerostaged(nodeview::NodeView)
    @test isempty(getstaged(nodeview))
    @test isempty(getstaged(getoxcview(nodeview)))
    @test isempty(getstaged(getrouterview(nodeview)))
end

function testedgeoxclogs(ibnf::IBNFramework)
    ibnag = getibnag(ibnf)
    for ed in edges(ibnag)
        srcglobalnode = getglobalnode(ibnag, src(ed))
        dstglobalnode = getglobalnode(ibnag, dst(ed))
        if isbordernode(ibnf, srcglobalnode) 
            ibnfhandler = getibnfhandler(ibnf, getibnfid(srcglobalnode))
            edgestatesrc = requestlinkstates_init(ibnf, ibnfhandler, GlobalEdge(srcglobalnode, dstglobalnode))
        else
            edgestatesrc = getlinkstates(getoxcview(getnodeview(ibnf, src(ed))), ed)
        end

        if isbordernode(ibnf, dstglobalnode)
            ibnfhandler = getibnfhandler(ibnf, getibnfid(dstglobalnode))
            edgestatedst = requestlinkstates_init(ibnf, ibnfhandler, GlobalEdge(srcglobalnode, dstglobalnode))
        else
            edgestatedst = getlinkstates(getoxcview(getnodeview(ibnf, dst(ed))), ed)

        end

        @test getindex.(edgestatesrc, 2) == getindex.(edgestatedst, 2)
    end
end

function testoxcllistateconsistency(ibnf::IBNFramework)
    for nodeview in MINDF.getintranodeviews(getibnag(ibnf))
        oxcview = getoxcview(nodeview)
        for (intentuuid,oxclli) in getreservations(oxcview)
            for ed in edges(getibnag(ibnf))
                MINDF.oxcllicontainsedge(oxclli, ed) || continue
                if MINDF.getcurrentlinkstate(ibnf, ed)
                    @test MINDF.getidagnodestate(getidag(ibnf), intentuuid) == MINDF.IntentState.Installed
                else
                    @test MINDF.getidagnodestate(getidag(ibnf), intentuuid) == MINDF.IntentState.Failed
                end
            end
        end
    end
end

end

