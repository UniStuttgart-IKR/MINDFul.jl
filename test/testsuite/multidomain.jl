
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

# MINDF.compileintent!(ibnfs[1], intentuuid2, MINDF.KShorestPathFirstFitCompilation(10))
# with border node
conintent_bordernode = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 25), u"100.0Gbps")
intentuuid_bordernode = MINDF.addintent!(ibnfs[1], conintent_bordernode, MINDF.NetworkOperator())

@show MINDF.compileintent!(ibnfs[1], intentuuid_bordernode, MINDF.KShorestPathFirstFitCompilation(10))

# to neighboring domain
conintent_neigh = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 47), u"100.0Gbps")
intentuuid_neigh = MINDF.addintent!(ibnfs[1], conintent_neigh, MINDF.NetworkOperator())
