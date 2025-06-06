@testset ExtendedTestSet "opticalconstraintssingledomain.jl"  begin

ibnfs = loadmultidomaintestibnfs()

foreach(ibnfs) do ibnf
    TM.testlocalnodeisindex(ibnf)
    TM.testoxcfiberallocationconsistency(ibnf)
end

conintent_intra = ConnectivityIntent(GlobalNode(UUID(1), 2), GlobalNode(UUID(1), 19), u"100.0Gbps")
intentuuid1 = addintent!(ibnfs[1], conintent_intra, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid1, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid1; onlyinstalled=false, noextrallis=true)
@test installintent!(ibnfs[1], intentuuid1) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid1; onlyinstalled=true, noextrallis=true)


# intradomain with `OpticalTerminateConstraint`
conintent_intra_optterm = ConnectivityIntent(GlobalNode(UUID(1), 8), GlobalNode(UUID(1), 22), u"100.0Gbps", [OpticalTerminateConstraint(GlobalNode(UUID(1), 22))])
intentuuid2 = addintent!(ibnfs[1], conintent_intra_optterm, NetworkOperator())
# kspffintradomain_2!(ibnfs[1], getidagnode(getidag(ibnfs[1]), intentuuid2), KShorestPathFirstFitCompilation(10))
@test compileintent!(ibnfs[1], intentuuid2, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
orderedllis2 = getlogicallliorder(ibnfs[1], intentuuid2; onlyinstalled=false)
@test issatisfied(ibnfs[1], intentuuid2, orderedllis2; noextrallis=true)
vorletzteglobalsnode = getglobalnode(getibnag(ibnfs[1]), getlocalnode(orderedllis2[end]))
spectrumslots = getspectrumslotsrange(orderedllis2[end])
transmode = gettransmissionmode(ibnfs[1], orderedllis2[2])
transmodulename = getname(gettransmissionmodule(ibnfs[1], orderedllis2[2]))
@test installintent!(ibnfs[1], intentuuid2) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid2; onlyinstalled=true, noextrallis=true)

conintent_intra_optini_finishprevious = ConnectivityIntent(GlobalNode(UUID(1), 22), GlobalNode(UUID(1), 22), u"100.0Gbps", [OpticalInitiateConstraint(vorletzteglobalsnode, spectrumslots, u"10.0km", TransmissionModuleCompatibility(getrate(transmode), getspectrumslotsneeded(transmode), transmodulename))])
intentuuid_intra_optini_finishprevious = addintent!(ibnfs[1], conintent_intra_optini_finishprevious, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid_intra_optini_finishprevious, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid_intra_optini_finishprevious; onlyinstalled=false, noextrallis=true)
@test installintent!(ibnfs[1], intentuuid_intra_optini_finishprevious) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid_intra_optini_finishprevious; onlyinstalled=true, noextrallis=true)

# intradomain with `OpticalInitaiteConstraint`
conintent_intra_optini = ConnectivityIntent(GlobalNode(UUID(1), 8), GlobalNode(UUID(1), 22), u"100.0Gbps", [OpticalInitiateConstraint(GlobalNode(UUID(1), 2), 21:26, u"500.0km", TransmissionModuleCompatibility(u"300.0Gbps", 6, "DummyFlexiblePluggable"))])
intentuuid3 = addintent!(ibnfs[1], conintent_intra_optini, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid3, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid3; onlyinstalled=false, noextrallis=true)
@test installintent!(ibnfs[1], intentuuid3) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid3; onlyinstalled=true, noextrallis=true)

oxcview1_2 = getoxcview(getnodeview(ibnfs[1], 2))
oxcllifinishprevious3 = OXCAddDropBypassSpectrumLLI(2, 0, 2, 8, 21:26)
@test canreserve(getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious3)
@test issuccess(reserve!(getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious3, UUID(0xfffffff); verbose = true))

# intradomain with `OpticalInitaiteConstraint and OpticalTerminateConstraint`
conintent_intra_optseg = ConnectivityIntent(GlobalNode(UUID(1), 8), GlobalNode(UUID(1), 22), u"100.0Gbps", [OpticalTerminateConstraint(GlobalNode(UUID(1), 22)), OpticalInitiateConstraint(GlobalNode(UUID(1), 2), 31:34, u"500.0km", TransmissionModuleCompatibility(u"100.0Gbps", 4, "DummyFlexiblePluggable"))])
intentuuid4 = addintent!(ibnfs[1], conintent_intra_optseg, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid4, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
orderedllis4 = getlogicallliorder(ibnfs[1], intentuuid4; onlyinstalled=false)
@test issatisfied(ibnfs[1], intentuuid4, orderedllis4; noextrallis=true)
vorletzteglobalsnode4 = getlocalnode(orderedllis4[end])
@test installintent!(ibnfs[1], intentuuid4) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid4; onlyinstalled=true, noextrallis=true)

oxcllifinishprevious4 = OXCAddDropBypassSpectrumLLI(2, 0, 2, 8, 31:34)
@test canreserve(getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious4)
@test issuccess(reserve!(getsdncontroller(ibnfs[1]), oxcview1_2, oxcllifinishprevious4, UUID(0xffffff1); verbose = true))

oxcview1_22 = getoxcview(getnodeview(ibnfs[1], 22))
oxcllifinishprevious4_1 = OXCAddDropBypassSpectrumLLI(22, vorletzteglobalsnode4, 2, 0, 31:34)
@test canreserve(getsdncontroller(ibnfs[1]), oxcview1_22, oxcllifinishprevious4_1)
@test issuccess(reserve!(getsdncontroller(ibnfs[1]), oxcview1_22, oxcllifinishprevious4_1, UUID(0xffffff2); verbose = true))

foreach(ibnfs) do ibnf
  TM.testlocalnodeisindex(ibnf)
  TM.testoxcfiberallocationconsistency(ibnf)
  TM.testzerostaged(ibnf)
end

nothing
end
