@testset ExtendedTestSet "singledomainavailabilityprotection_grooming_split.jl"  begin

nt = starttime = DateTime("2026-01-01")

compalg = MINDF.BestEmpiricalAvailabilityCompilation(10, 5; nodenum=1)
ibnfs = loadmultidomaintestibnfs(compalg, nt)

# basically best effort
avcon1 = MINDF.AvailabilityConstraint(0.94, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[3]), 12), u"5.0Gbps", [avcon1])

intentuuid1, _ = addintent!(ibnfs[1], conintent1, NetworkOperator())

returncode, nt = compileintent!(ibnfs[1], intentuuid1; offsettime = nt)
@test returncode == ReturnCodes.SUCCESS

idnchildren = getidagnodechildren(getidag(ibnfs[1]), intentuuid1)
@test length(idnchildren) == 3
@test getintent(idnchildren[1]) isa ConnectivityIntent
@test getintent(idnchildren[2]) isa ConnectivityIntent
getavcon1 = getfirst(x -> x isa AvailabilityConstraint, getconstraints(getintent(idnchildren[1])))
getavcon2 = getfirst(x -> x isa AvailabilityConstraint, getconstraints(getintent(idnchildren[2])))

@test MINDF.getavailabilityrequirement(getavcon1) * MINDF.getavailabilityrequirement(getavcon2) >= MINDF.getavailabilityrequirement(avcon1)
@test MINDF.getcompliancetarget(getavcon1) * MINDF.getcompliancetarget(getavcon2) >= MINDF.getcompliancetarget(avcon1)

rc, nt = installintent!(ibnfs[3], intentuuid1; offsettime = nt, verbose=false)
@test rc == ReturnCodes.SUCCESS

# TODO : more tests ?

# @test installintent!(ibnfs[1], intentuuid1, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
#
# @test uninstallintent!(ibnfs[1], intentuuid1; offsettime = nowtime) == ReturnCodes.SUCCESS
# @test uncompileintent!(ibnfs[1], intentuuid1; offsettime = nowtime) == ReturnCodes.SUCCESS
#
# TM.@test_nothrows MINDF.updatelogintentcomp!(ibnfs[1], beacomp)
#

end
