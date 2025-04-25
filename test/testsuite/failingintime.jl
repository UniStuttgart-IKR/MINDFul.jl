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


internaledge = Edge(3,4)
getlinkstates(getoxcview(getnodeview(ibnfs[1], src(internaledge))))[internaledge]
setlinkstate!(ibnfs[1], internaledge, false)

conintent_internal = ConnectivityIntent(GlobalNode(UUID(1), 14), GlobalNode(UUID(1), 1), u"100.0Gbps")
intentuuid_internal = addintent!(ibnfs[1], conintent_internal, NetworkOperator())
compileintent!(ibnfs[1], intentuuid_internal, KShorestPathFirstFitCompilation(10))
installintent!(ibnfs[1], intentuuid_internal; verbose=true)

# fail the link and see how the intent DAG reacts

# 29 is border node
borderdstedge = Edge(17,29)
getlinkstates(getoxcview(getnodeview(ibnfs[1], src(borderdstedge))))[borderdstedge]
setlinkstate!(ibnfs[1], borderdstedge, false)

conintent_cross = ConnectivityIntent(GlobalNode(UUID(1), 23), GlobalNode(UUID(3), 25), u"100.0Gbps")
intentuuid_cross = addintent!(ibnfs[1], conintent_cross, NetworkOperator())
compileintent!(ibnfs[1], intentuuid_cross, KShorestPathFirstFitCompilation(10))
installintent!(ibnfs[1], intentuuid_cross; verbose=true)

# fail the link and see how the intent DAG reacts

nothing
