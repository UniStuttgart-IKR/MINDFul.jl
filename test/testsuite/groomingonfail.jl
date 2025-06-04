@testset ExtendedTestSet "groomingonfail.jl"  begin

ibnfs = loadmultidomaintestibnfs()

conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
intentuuid1 = addintent!(ibnfs[1], conintent1, NetworkOperator())
conintent1idn = getidagnode(getidag(ibnfs[1]), intentuuid1)
compileintent!(ibnfs[1], intentuuid1, KShorestPathFirstFitCompilation(10))
installintent!(ibnfs[1], intentuuid1)

installedlightpathsibnfs1 = getinstalledlightpaths(getidaginfo(getidag(ibnfs[1])))
@test length(installedlightpathsibnfs1) == 1
lpr1 = installedlightpathsibnfs1[UUID(0x2)]
@test first(MINDF.getpath(lpr1)) == 4
@test last(MINDF.getpath(lpr1)) == 8
@test MINDF.getstartsoptically(lpr1) == false
@test MINDF.getterminatessoptically(lpr1) == false
@test MINDF.gettotalbandwidth(lpr1) == GBPSf(100)
@test getresidualbandwidth(ibnfs[1], UUID(0x2)) == GBPSf(70)

MINDF.setlinkstate!(ibnfs[1], Edge(20, 8), false) == ReturnCodes.SUCCESS
@test getidagnodestate(conintent1idn) == IntentState.Failed

groomconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"30.0Gbps")
groomintentuuid1 = addintent!(ibnfs[1], groomconintent1, NetworkOperator())
groomconintent1idn = getidagnode(getidag(ibnfs[1]), groomintentuuid1)
@test MINDF.prioritizegrooming_default(ibnfs[1], groomconintent1idn, KShorestPathFirstFitCompilation(4)) == UUID[]

# for external lightpaths now

mdconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[3]), 21), u"30.0Gbps")
mdconintent1id = addintent!(ibnfs[1], mdconintent1, NetworkOperator())
mdconintent1idn = getidagnode(getidag(ibnfs[1]), mdconintent1id)
compileintent!(ibnfs[1], mdconintent1id, KShorestPathFirstFitCompilation(10))
installintent!(ibnfs[1], mdconintent1id)

@test getidagnodestate(mdconintent1idn) == IntentState.Installed
MINDF.setlinkstate!(ibnfs[3], Edge(24, 23), false) == ReturnCodes.SUCCESS
@test getidagnodestate(mdconintent1idn) == IntentState.Failed


groommdconintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[3]), 21), u"30.0Gbps")
groommdconintent1id = addintent!(ibnfs[1], groommdconintent1, NetworkOperator())
groommdconintent1idn = getidagnode(getidag(ibnfs[1]), groommdconintent1id)
compileintent!(ibnfs[1], groommdconintent1id, KShorestPathFirstFitCompilation(10))
@test getidagnodestate(groommdconintent1idn) == IntentState.Compiled
installintent!(ibnfs[1], groommdconintent1id)
@test getidagnodestate(groommdconintent1idn) == IntentState.Installed
@test !MINDF.issubdaggrooming(getidag(ibnfs[1]), groommdconintent1id)

end
