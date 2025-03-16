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
@test MINDF.compileintent!(ibnfs[1], intentuuid1, MINDF.KShorestPathFirstFitCompilation(10))
@test MINDF.issatisfied(ibnfs[1], intentuuid1; onlyinstalled=false, noextrallis=true)
@test MINDF.installintent!(ibnfs[1], intentuuid1)


# # intradomain with `OpticalTerminateConstraint`
# conintent_intra_optterm = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalTerminateConstraint()])
# # conintent_intra_optterm = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps")
# intentuuid2 = MINDF.addintent!(ibnfs[1], conintent_intra_optterm, MINDF.NetworkOperator())
# # MINDF.kspffintradomain_2!(ibnfs[1], MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid2), MINDF.KShorestPathFirstFitCompilation(10))
# @test MINDF.compileintent!(ibnfs[1], intentuuid2, MINDF.KShorestPathFirstFitCompilation(10))
# orderedllis2 = MINDF.LowLevelIntent[]
# @test MINDF.issatisfied(ibnfs[1], intentuuid2; onlyinstalled=false, noextrallis=true, orderedllis = orderedllis2)
# vorletzteglobalsnode = MINDF.getglobalnode(MINDF.getibnag(ibnfs[1]), MINDF.getlocalnode(orderedllis2[end]))
# spectrumslots = MINDF.getspectrumslotsrange(orderedllis2[end])
# transmode = MINDF.gettransmissionmode(ibnfs[1], orderedllis2[2])
# transmodulename = MINDF.getname(MINDF.gettransmissionmodule(ibnfs[1], orderedllis2[2]))
# @test MINDF.installintent!(ibnfs[1], intentuuid2)

# conintent_intra_optini_finishprevious_ = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 22), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalInitiateConstraint(vorletzteglobalsnode, spectrumslots, u"10.0km", MINDF.TransmissionModuleCompatibility(MINDF.getrate(transmode), MINDF.getspectrumslotsneeded(transmode), transmodulename))])
# intentuuid_intra_optini_finishprevious = MINDF.addintent!(ibnfs[1], conintent_intra_optini_finishprevious, MINDF.NetworkOperator())
# @test MINDF.compileintent!(ibnfs[1], intentuuid_intra_optini_finishprevious, MINDF.KShorestPathFirstFitCompilation(10))
# @test MINDF.installintent!(ibnfs[1], intentuuid_intra_optini_finishprevious)
# # @test MINDF.compileintent!(ibnfs[1], intentuuid_intra_optini_finishprevious, MINDF.KShorestPathFirstFitCompilation(10))

# # MINDF.getfiberspectrumavailabilities(ibnfs[1], Edge(1,22))

# # # # intradomain with `OpticalInitaiteConstraint`
# conintent_intra_optini = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalInitiateConstraint(MINDF.GlobalNode(UUID(1), 2), 21:26, u"500.0km", MINDF.TransmissionModuleCompatibility(u"300.0Gbps", 6, "DummyFlexiblePluggable"))])
# intentuuid3 = MINDF.addintent!(ibnfs[1], conintent_intra_optini, MINDF.NetworkOperator())
# @test MINDF.compileintent!(ibnfs[1], intentuuid3, MINDF.KShorestPathFirstFitCompilation(10))
# @test MINDF.issatisfied(ibnfs[1], intentuuid3; onlyinstalled=false, noextrallis=true)
# @test MINDF.installintent!(ibnfs[1], intentuuid3)

# # MINDF.compileintent!(ibnfs[1], intentuuid2, MINDF.KShorestPathFirstFitCompilation(10))

# # intradomain with `OpticalInitaiteConstraint`
# conintent_intra_optseg = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalTerminateConstraint(), MINDF.OpticalInitiateConstraint(MINDF.GlobalNode(UUID(1), 2), 21:24, u"500.0km", MINDF.TransmissionModuleCompatibility(u"300.0Gbps", 6, "DummyFlexiblePluggable"))])
# intentuuid4 = MINDF.addintent!(ibnfs[1], conintent_intra_optseg, MINDF.NetworkOperator())
# @test MINDF.compileintent!(ibnfs[1], intentuuid4, MINDF.KShorestPathFirstFitCompilation(10))
# @test MINDF.issatisfied(ibnfs[1], intentuuid4; onlyinstalled=false, noextrallis=true)
# # @test MINDF.installintent!(ibnfs[1], intentuuid4)

# # MINDF.compileintent!(ibnfs[1], intentuuid2, MINDF.KShorestPathFirstFitCompilation(10))
# # with border node
# conintent_bordernode = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 25), u"100.0Gbps")
# intentuuid5 = MINDF.addintent!(ibnfs[1], conintent_bordernode, MINDF.NetworkOperator())

# # to neighboring domain
# conintent_neigh = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 47), u"100.0Gbps")
# intentuuid6 = MINDF.addintent!(ibnfs[1], conintent_neigh, MINDF.NetworkOperator())

nothing
