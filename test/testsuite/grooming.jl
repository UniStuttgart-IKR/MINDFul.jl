domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]


ibnfs = [
    let
        ag = name_graph[2]
        ibnag = MINDF.default_IBNAttributeGraph(ag)
        ibnf = IBNFramework(ibnag)
    end for name_graph in domains_name_graph
]


# add ibnf handlers

for i in eachindex(ibnfs)
    for j in eachindex(ibnfs)
        i == j && continue
        push!(getibnfhandlers(ibnfs[i]), ibnfs[j] )
    end
end

# internal
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
intentuuid1 = addintent!(ibnfs[1], conintent1, NetworkOperator())
compileintent!(ibnfs[1], intentuuid1, KShorestPathFirstFitCompilation(10))
installintent!(ibnfs[1], intentuuid1)

installedlightpathsibnfs1 = getinstalledlightpaths(getidaginfo(getidag(ibnfs[1])))
@test length(installedlightpathsibnfs1) == 1
lpr1 = installedlightpathsibnfs1[intentuuid1]
@test first(MINDF.getpath(lpr1)) == 4
@test last(MINDF.getpath(lpr1)) == 8
@test MINDF.getstartsoptically(lpr1) == false
@test MINDF.getterminatessoptically(lpr1) == false
@test MINDF.gettotalbandwidth(lpr1) == GBPSf(100)
@test getresidualbandwidth(ibnfs[1], UUID(0x1)) == GBPSf(70)

groomconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
groomintentuuid1 = addintent!(ibnfs[1], groomconintent1, NetworkOperator())
groomconintent1idn = getidagnode(getidag(ibnfs[1]), groomintentuuid1)
@test MINDF.prioritizegrooming_default(ibnfs[1], groomconintent1idn, KShorestPathFirstFitCompilation(4)) == [[intentuuid1]]
compileintent!(ibnfs[1], groomintentuuid1, KShorestPathFirstFitCompilation(10))
installintent!(ibnfs[1], groomintentuuid1)

# conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"40.0Gbps")
# intentuuid1 = addintent!(ibnfs[1], conintent1, NetworkOperator())
# compileintent!(ibnfs[1], intentuuid1, KShorestPathFirstFitCompilation(10))
# installintent!(ibnfs[1], intentuuid1)

# have an intent installed with grooming IP router port

# conintent_bordernode = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 25), u"40.0Gbps")
# intentuuid_bordernode = addintent!(ibnfs[1], conintent_bordernode, NetworkOperator())
# compileintent!(ibnfs[1], intentuuid_bordernode, KShorestPathFirstFitCompilation(10))
# installintent!(ibnfs[1], intentuuid_bordernode; verbose=true)

# conintent_neigh = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 47), u"100.0Gbps")
# intentuuid_neigh = addintent!(ibnfs[1], conintent_neigh, NetworkOperator())
# compileintent!(ibnfs[1], intentuuid_neigh, KShorestPathFirstFitCompilation(10))
# installintent!(ibnfs[1], intentuuid_neigh; verbose=true)


