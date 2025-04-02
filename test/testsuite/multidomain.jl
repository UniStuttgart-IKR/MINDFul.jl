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
testcompilation(ibnfs[1], intentuuid_bordernode; withremote=true)
 
# install
@test MINDF.installintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
testinstallation(ibnfs[1], intentuuid_bordernode; withremote=true)

# uninstall
@test MINDF.uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
testuninstallation(ibnfs[1], intentuuid_bordernode; withremote=true)

# uncompile
@test MINDF.uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
testuncompilation(ibnfs[1], intentuuid_bordernode)
@test nv(MINDF.getidag(ibnfs[1])) == 1
@test nv(MINDF.getidag(ibnfs[3])) == 0

# to neighboring domain
conintent_neigh = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 47), u"100.0Gbps")
intentuuid_neigh = MINDF.addintent!(ibnfs[1], conintent_neigh, MINDF.NetworkOperator())

@test MINDF.compileintent!(ibnfs[1], intentuuid_neigh, MINDF.KShorestPathFirstFitCompilation(10))
testcompilation(ibnfs[1], intentuuid_neigh; withremote=true)

@test MINDF.installintent!(ibnfs[1], intentuuid_neigh; verbose=true)
testinstallation(ibnfs[1], intentuuid_neigh; withremote=true)

@test MINDF.uninstallintent!(ibnfs[1], intentuuid_neigh; verbose=true)
testuninstallation(ibnfs[1], intentuuid_neigh; withremote=true)

@test MINDF.uncompileintent!(ibnfs[1], intentuuid_neigh; verbose=true)
testuncompilation(ibnfs[1], intentuuid_neigh)
@test nv(MINDF.getidag(ibnfs[1])) == 2
@test nv(MINDF.getidag(ibnfs[3])) == 0
# to unknown domain
 
foreach(ibnfs) do ibnf
    testoxcfiberallocationconsistency(ibnf)
end

end
