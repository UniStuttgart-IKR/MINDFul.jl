
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
foreach(MINDF.getidagnodeid.(MINDF.getidagnodechildren(MINDF.getidag(ibnfs[1]), intentuuid_bordernode))) do intentuuid
    @test MINDF.issatisfied(ibnfs[1], intentuuid; onlyinstalled=false, noextrallis=false)
end

idagnoderemoteintent = MINDF.getfirst(x -> MINDF.getintent(x) isa MINDF.RemoteIntent ,MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[1]), intentuuid_bordernode))
@test !isnothing(idagnoderemoteintent)

let remoteintent = MINDF.getintent(idagnoderemoteintent)
    ibnfhandler = MINDF.getibnfhandler(ibnfs[1], MINDF.getibnfid(remoteintent))
    idagnodeid = MINDF.getidagnodeid(remoteintent)
    @test MINDF.requestissatisfied(ibnfs[1], ibnfhandler, idagnodeid; onlyinstalled=false, noextrallis=true)
    if ibnfhandler isa MINDF.IBNFramework
        @test MINDF.issatisfied(ibnfhandler, idagnodeid; onlyinstalled=false, noextrallis=true)
        @test all(==(MINDF.IntentState.Compiled),MINDF.getidagnodestate.(MINDF.getidagnodedescendants(MINDF.getidag(ibnfhandler), idagnodeid)))
    end
end

# install

# uninstall

# uncompile

# check for zero resource allocation

# to neighboring domain
conintent_neigh = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 47), u"100.0Gbps")
intentuuid_neigh = MINDF.addintent!(ibnfs[1], conintent_neigh, MINDF.NetworkOperator())

# to unknown domain
 
