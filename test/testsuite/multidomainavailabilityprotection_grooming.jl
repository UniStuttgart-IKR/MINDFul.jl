starttime = DateTime("2026-01-01")
ibnfs = loadmultidomaintestibnfs()

# basically best effort
avcon1 = MINDF.AvailabilityConstraint(0.94, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[3]), 12), u"5.0Gbps", [avcon1])

intentuuid1 = addintent!(ibnfs[1], conintent1, NetworkOperator())

nowtime = starttime + Dates.Year(3) 
beacomp = MINDF.BestEmpiricalAvailabilityCompilation(5,5)

@test compileintent!(ibnfs[1], intentuuid1, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
nowtime = MINDF.getlateststateloggeddatetime(MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid1))

# TODO : check that Availability was split as expected

# @test installintent!(ibnfs[1], intentuuid1, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
#
# @test uninstallintent!(ibnfs[1], intentuuid1; offsettime = nowtime) == ReturnCodes.SUCCESS
# @test uncompileintent!(ibnfs[1], intentuuid1; offsettime = nowtime) == ReturnCodes.SUCCESS
#
# TM.@test_nothrows MINDF.updatelogintentcomp!(ibnfs[1], beacomp)
