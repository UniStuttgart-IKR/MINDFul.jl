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
        push!(ibnfs[i].interIBNFs, ibnfs[j] )
    end
end

conintent_intra = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 2), MINDF.GlobalNode(UUID(1), 19), u"100.0Gbps")
intentuuid1 = MINDF.addintent!(ibnfs[1], conintent_intra, MINDF.NetworkOperator())


# intradomain with `OpticalTerminateConstraint`
conintent_intra_optterm = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalTerminateConstraint()])
intentuuid2 = MINDF.addintent!(ibnfs[1], conintent_intra_optterm, MINDF.NetworkOperator())

# intradomain with `OpticalInitaiteConstraint`
conintent_intra_optini = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalInitiateConstraint(MINDF.GlobalNode(UUID(1), 2), 21:24, u"500.0km", MINDF.TransmissionModuleCompatibility(u"300.0Gbps", 4, "DummyFlexibleTransponder"))])
intentuuid3 = MINDF.addintent!(ibnfs[1], conintent_intra_optini, MINDF.NetworkOperator())

# MINDF.compileintent!(ibnfs[1], intentuuid2, MINDF.KShorestPathFirstFitCompilation(10))

# intradomain with `OpticalInitaiteConstraint`
conintent_intra_optseg = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalTerminateConstraint(), MINDF.OpticalInitiateConstraint(MINDF.GlobalNode(UUID(1), 2), 21:24, u"500.0km", MINDF.TransmissionModuleCompatibility(u"300.0Gbps", 4, "DummyFlexibleTransponder"))])
intentuuid4 = MINDF.addintent!(ibnfs[1], conintent_intra_optseg, MINDF.NetworkOperator())

@test MINDF.kspffintradomain_2!(ibnfs[1], MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid4), MINDF.KShorestPathFirstFitCompilation(10))
# MINDF.compileintent!(ibnfs[1], intentuuid2, MINDF.KShorestPathFirstFitCompilation(10))
# with border node
conintent_bordernode = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 25), u"100.0Gbps")
intentuuid5 = MINDF.addintent!(ibnfs[1], conintent_bordernode, MINDF.NetworkOperator())

# to neighboring domain
conintent_neigh = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 47), u"100.0Gbps")
intentuuid6 = MINDF.addintent!(ibnfs[1], conintent_neigh, MINDF.NetworkOperator())
