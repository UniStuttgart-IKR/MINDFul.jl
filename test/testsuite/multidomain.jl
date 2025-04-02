@testset ExtendedTestSet "multidomain.jl"  begin

domains_name_graph = first(JLD2.load("data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]


ibnfs = [
    let
        ag = name_graph[2]
        ibnag = MINDF.default_IBNAttributeGraph(ag)
        ibnf = MINDF.IBNFramework(ibnag)
    end for name_graph in domains_name_graph
]


# add ibnf handlers

for i in eachindex(ibnfs)
    for j in eachindex(ibnfs)
        i == j && continue
        push!(MINDF.getibnfhandlers(ibnfs[i]), ibnfs[j] )
    end
end

# with border node
conintent_bordernode = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 25), u"100.0Gbps")
intentuuid_bordernode = MINDF.addintent!(ibnfs[1], conintent_bordernode, MINDF.NetworkOperator())

@test MINDF.compileintent!(ibnfs[1], intentuuid_bordernode, MINDF.KShorestPathFirstFitCompilation(10))
@test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid_bordernode)) == MINDF.IntentState.Compiled
@test all(==(MINDF.IntentState.Compiled),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[1]), intentuuid_bordernode)))
MINDF.issatisfied(ibnfs[1], intentuuid_bordernode; onlyinstalled=false, noextrallis=false)
@test !MINDF.issatisfied(ibnfs[1], intentuuid_bordernode; onlyinstalled=true, noextrallis=false)
foreach(MINDF.getidagnodeid.(MINDF.getidagnodechildren(MINDF.getidag(ibnfs[1]), intentuuid_bordernode))) do intentuuid
    @test MINDF.issatisfied(ibnfs[1], intentuuid; onlyinstalled=false, noextrallis=false)
end

idagnoderemoteintent = MINDF.getfirst(x -> MINDF.getintent(x) isa MINDF.RemoteIntent ,MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[1]), intentuuid_bordernode))
@test !isnothing(idagnoderemoteintent)
remoteintent_bordernode = MINDF.getintent(idagnoderemoteintent)
ibnfhandler_bordernode = MINDF.getibnfhandler(ibnfs[1], MINDF.getibnfid(remoteintent_bordernode))
idagnodeid_remote_bordernode = MINDF.getidagnodeid(remoteintent_bordernode)
@test MINDF.requestissatisfied(ibnfs[1], ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=false, noextrallis=true)
if ibnfhandler_bordernode isa MINDF.IBNFramework
    @test MINDF.issatisfied(ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=false, noextrallis=true)
    @test all(==(MINDF.IntentState.Compiled),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnfhandler_bordernode), idagnodeid_remote_bordernode)))
end

# install
@test MINDF.installintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
@test all(==(MINDF.IntentState.Installed),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[1]), intentuuid_bordernode)))
@test MINDF.issatisfied(ibnfs[1], intentuuid_bordernode; onlyinstalled=true, noextrallis=false)
foreach(MINDF.getidagnodeid.(MINDF.getidagnodechildren(MINDF.getidag(ibnfs[1]), intentuuid_bordernode))) do intentuuid
    @test MINDF.issatisfied(ibnfs[1], intentuuid; onlyinstalled=true, noextrallis=false)
end
@test MINDF.requestissatisfied(ibnfs[1], ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=true, noextrallis=true)
if ibnfhandler_bordernode isa MINDF.IBNFramework
    @test MINDF.issatisfied(ibnfhandler_bordernode, idagnodeid_remote_bordernode; onlyinstalled=true, noextrallis=true)
    @test all(==(MINDF.IntentState.Installed),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnfhandler_bordernode), idagnodeid_remote_bordernode)))
end
orderedllis = MINDF.getlogicallliorder(ibnfs[1], intentuuid_bordernode)
foreach(orderedllis) do olli
    islowlevelintentdagnodeinstalled(ibnfs[1], olli)
end

# check that allocations are non empty
@test any(nodeview -> !isempty(MINDF.getreservations(nodeview)), MINDF.getintranodeviews(MINDF.getibnag(ibnfs[1])))
@test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getrouterview(nodeview))), MINDF.getintranodeviews(MINDF.getibnag(ibnfs[1])))
@test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getoxcview(nodeview))), MINDF.getintranodeviews(MINDF.getibnag(ibnfs[1])))
if ibnfhandler_bordernode isa MINDF.IBNFramework
    @test any(nodeview -> !isempty(MINDF.getreservations(nodeview)), MINDF.getintranodeviews(MINDF.getibnag(ibnfhandler_bordernode)))
    @test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getrouterview(nodeview))), MINDF.getintranodeviews(MINDF.getibnag(ibnfhandler_bordernode)))
    @test any(nodeview -> !isempty(MINDF.getreservations(MINDF.getoxcview(nodeview))), MINDF.getintranodeviews(MINDF.getibnag(ibnfhandler_bordernode)))
end

# uninstall
@test MINDF.uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
@test all(==(MINDF.IntentState.Compiled),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[1]), intentuuid_bordernode)))
@test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid_bordernode)) == MINDF.IntentState.Compiled
MINDF.issatisfied(ibnfs[1], intentuuid_bordernode; onlyinstalled=false, noextrallis=false)
@test !MINDF.issatisfied(ibnfs[1], intentuuid_bordernode; onlyinstalled=true, noextrallis=false)

# check that allocations are empty
for nodeview in MINDF.getintranodeviews(MINDF.getibnag(ibnfs[1]))
    @test isempty(MINDF.getreservations(nodeview))
    @test isempty(MINDF.getreservations(MINDF.getrouterview(nodeview)))
    @test isempty(MINDF.getreservations(MINDF.getoxcview(nodeview)))
end
if ibnfhandler_bordernode isa MINDF.IBNFramework
    for nodeview in MINDF.getintranodeviews(MINDF.getibnag(ibnfhandler_bordernode))
        @test isempty(MINDF.getreservations(nodeview))
        @test isempty(MINDF.getreservations(MINDF.getrouterview(nodeview)))
        @test isempty(MINDF.getreservations(MINDF.getoxcview(nodeview)))
    end
end

# uncompile
@test MINDF.uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
@test MINDF.getidagnodestate(MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid_bordernode)) == MINDF.IntentState.Uncompiled
@test isempty(MINDF.getidagnodechildren(MINDF.getidag(ibnfs[1]), intentuuid_bordernode))
@test nv(MINDF.getidag(ibnfs[1])) == 1
@test nv(MINDF.getidag(ibnfs[3])) == 0

# to neighboring domain
conintent_neigh = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 47), u"100.0Gbps")
intentuuid_neigh = MINDF.addintent!(ibnfs[1], conintent_neigh, MINDF.NetworkOperator())

# to unknown domain
 
foreach(ibnfs) do ibnf
    testoxcfiberallocationconsistency(ibnf)
end

end
