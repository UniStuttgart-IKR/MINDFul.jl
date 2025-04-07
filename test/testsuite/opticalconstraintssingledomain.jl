@testset ExtendedTestSet "opticalconstraintssingledomain.jl"  begin
domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]


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

foreach(ibnfs) do ibnf
    testlocalnodeisindex(ibnf)
    testoxcfiberallocationconsistency(ibnf)
end

conintent_intra = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 2), MINDF.GlobalNode(UUID(1), 19), u"100.0Gbps")
intentuuid1 = MINDF.addintent!(ibnfs[1], conintent_intra, MINDF.NetworkOperator())
@test MINDF.compileintent!(ibnfs[1], intentuuid1, MINDF.KShorestPathFirstFitCompilation(10))
@test MINDF.issatisfied(ibnfs[1], intentuuid1; onlyinstalled=false, noextrallis=true)
@test MINDF.installintent!(ibnfs[1], intentuuid1)
@test MINDF.issatisfied(ibnfs[1], intentuuid1; onlyinstalled=true, noextrallis=true)


# intradomain with `OpticalTerminateConstraint`
conintent_intra_optterm = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalTerminateConstraint()])
intentuuid2 = MINDF.addintent!(ibnfs[1], conintent_intra_optterm, MINDF.NetworkOperator())
# MINDF.kspffintradomain_2!(ibnfs[1], MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid2), MINDF.KShorestPathFirstFitCompilation(10))
@test MINDF.compileintent!(ibnfs[1], intentuuid2, MINDF.KShorestPathFirstFitCompilation(10))
orderedllis2 = MINDF.getlogicallliorder(ibnfs[1], intentuuid2; onlyinstalled=false)
@test MINDF.issatisfied(ibnfs[1], intentuuid2, orderedllis2; noextrallis=true)
vorletzteglobalsnode = MINDF.getglobalnode(MINDF.getibnag(ibnfs[1]), MINDF.getlocalnode(orderedllis2[end]))
spectrumslots = MINDF.getspectrumslotsrange(orderedllis2[end])
transmode = MINDF.gettransmissionmode(ibnfs[1], orderedllis2[2])
transmodulename = MINDF.getname(MINDF.gettransmissionmodule(ibnfs[1], orderedllis2[2]))
@test MINDF.installintent!(ibnfs[1], intentuuid2)
@test MINDF.issatisfied(ibnfs[1], intentuuid2; onlyinstalled=true, noextrallis=true)

conintent_intra_optini_finishprevious = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 22), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalInitiateConstraint(vorletzteglobalsnode, spectrumslots, u"10.0km", MINDF.TransmissionModuleCompatibility(MINDF.getrate(transmode), MINDF.getspectrumslotsneeded(transmode), transmodulename))])
intentuuid_intra_optini_finishprevious = MINDF.addintent!(ibnfs[1], conintent_intra_optini_finishprevious, MINDF.NetworkOperator())
@test MINDF.compileintent!(ibnfs[1], intentuuid_intra_optini_finishprevious, MINDF.KShorestPathFirstFitCompilation(10))
@test MINDF.issatisfied(ibnfs[1], intentuuid_intra_optini_finishprevious; onlyinstalled=false, noextrallis=true)
@test MINDF.installintent!(ibnfs[1], intentuuid_intra_optini_finishprevious)
@test MINDF.issatisfied(ibnfs[1], intentuuid_intra_optini_finishprevious; onlyinstalled=true, noextrallis=true)

# intradomain with `OpticalInitaiteConstraint`
conintent_intra_optini = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalInitiateConstraint(MINDF.GlobalNode(UUID(1), 2), 21:26, u"500.0km", MINDF.TransmissionModuleCompatibility(u"300.0Gbps", 6, "DummyFlexiblePluggable"))])
intentuuid3 = MINDF.addintent!(ibnfs[1], conintent_intra_optini, MINDF.NetworkOperator())
@test MINDF.compileintent!(ibnfs[1], intentuuid3, MINDF.KShorestPathFirstFitCompilation(10))
@test MINDF.issatisfied(ibnfs[1], intentuuid3; onlyinstalled=false, noextrallis=true)
@test MINDF.installintent!(ibnfs[1], intentuuid3)
@test MINDF.issatisfied(ibnfs[1], intentuuid3; onlyinstalled=true, noextrallis=true)

oxcview1_2 = MINDF.getoxcview(MINDF.getnodeview(ibnfs[1], 2))
oxcllifinishprevious3 = MINDF.OXCAddDropBypassSpectrumLLI(2, 0, 2, 8, 21:26)
@test MINDF.canreserve(MINDF.getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious3)
@test MINDF.reserve!(MINDF.getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious3, UUID(0xfffffff); verbose = true)

# intradomain with `OpticalInitaiteConstraint and OpticalTerminateConstraint`
conintent_intra_optseg = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 8), MINDF.GlobalNode(UUID(1), 22), u"100.0Gbps", [MINDF.OpticalTerminateConstraint(), MINDF.OpticalInitiateConstraint(MINDF.GlobalNode(UUID(1), 2), 31:34, u"500.0km", MINDF.TransmissionModuleCompatibility(u"100.0Gbps", 4, "DummyFlexiblePluggable"))])
intentuuid4 = MINDF.addintent!(ibnfs[1], conintent_intra_optseg, MINDF.NetworkOperator())
@test MINDF.compileintent!(ibnfs[1], intentuuid4, MINDF.KShorestPathFirstFitCompilation(10))
orderedllis4 = MINDF.getlogicallliorder(ibnfs[1], intentuuid4; onlyinstalled=false)
@test MINDF.issatisfied(ibnfs[1], intentuuid4, orderedllis4; noextrallis=true)
vorletzteglobalsnode4 = MINDF.getlocalnode(orderedllis4[end])
@test MINDF.installintent!(ibnfs[1], intentuuid4)
@test MINDF.issatisfied(ibnfs[1], intentuuid4; onlyinstalled=true, noextrallis=true)

oxcllifinishprevious4 = MINDF.OXCAddDropBypassSpectrumLLI(2, 0, 2, 8, 31:34)
@test MINDF.canreserve(MINDF.getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious4)
@test MINDF.reserve!(MINDF.getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious4, UUID(0xffffff1); verbose = true)

oxcview1_22 = MINDF.getoxcview(MINDF.getnodeview(ibnfs[1], 22))
oxcllifinishprevious4_1 = MINDF.OXCAddDropBypassSpectrumLLI(22, vorletzteglobalsnode4, 2, 0, 31:34)
@test MINDF.canreserve(MINDF.getsdncontroller(ibnfs[1]), oxcview1_22, oxcllifinishprevious4_1)
@test MINDF.reserve!(MINDF.getsdncontroller(ibnfs[1]), oxcview1_22, oxcllifinishprevious4_1, UUID(0xffffff2); verbose = true)

foreach(ibnfs) do ibnf
  testlocalnodeisindex(ibnf)
  testoxcfiberallocationconsistency(ibnf)
end

nothing
end
