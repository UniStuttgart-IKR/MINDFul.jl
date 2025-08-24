@testset ExtendedTestSet "singledomainavailabilityprotection_grooming.jl"  begin
starttime = DateTime("2026-01-01")
ibnfs = loadmultidomaintestibnfs()

# basically best effort
avcon1 = MINDF.AvailabilityConstraint(0.94, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [avcon1])
avcon2 = MINDF.AvailabilityConstraint(0.92, 0.9) 
conintent2 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [avcon2])

intentuuid1_1 = addintent!(ibnfs[1], conintent1, NetworkOperator())
intentuuid1_2 = addintent!(ibnfs[1], conintent1, NetworkOperator())
intentuuid2 = addintent!(ibnfs[1], conintent2, NetworkOperator())

nowtime = starttime + Dates.Year(3) 
beacomp = MINDF.BestEmpiricalAvailabilityCompilation(5,5)

setlinkstate!(ibnfs[1], Edge(3=>14), false; offsettime = starttime + Dates.Month(3))
setlinkstate!(ibnfs[1], Edge(3=>14), true; offsettime = starttime + Dates.Month(6))
#
setlinkstate!(ibnfs[1], Edge(1=>6), false; offsettime = starttime + Dates.Month(4))
setlinkstate!(ibnfs[1], Edge(1=>6), true; offsettime = starttime + Dates.Month(8))

@test compileintent!(ibnfs[1], intentuuid1_1, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
intentuuid1_protectedpath1 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1_1; onlyinstalled=false, choosealternativeorder=1))
@test intentuuid1_protectedpath1 == [4, 3, 14, 15, 20, 8]
intentuuid1_protectedpath2 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1_1; onlyinstalled=false, choosealternativeorder=2))
@test intentuuid1_protectedpath2 == [4, 1, 6, 20, 8]
@test installintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime) == ReturnCodes.SUCCESS

# @test installintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime) == ReturnCodes.SUCCESS

# intentuuid1_2 should groom to a protection lightpath of the intentuuid1_1
@test compileintent!(ibnfs[1], intentuuid1_2, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1_1) == MINDF.IntentState.Installed
@test installintent!(ibnfs[1], intentuuid1_2; offsettime = nowtime) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid1_2; onlyinstalled=true, noextrallis = false) == true
# test that it's groomed
@test getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_1)[1]) == getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_2)[1])

# uninstall protected intent
@test uninstallintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime) == ReturnCodes.SUCCESS
# the groomed intent should remain installed
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1_2) == MINDF.IntentState.Installed
@test issatisfied(ibnfs[1], intentuuid1_2; onlyinstalled=true, noextrallis = false) == true

# uncompile protected intent
@test uncompileintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime) == ReturnCodes.SUCCESS
# the groomed intent should remain installed
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1_2) == MINDF.IntentState.Installed
@test issatisfied(ibnfs[1], intentuuid1_2; onlyinstalled=true, noextrallis = false) == true

# recompile protected intent
@test compileintent!(ibnfs[1], intentuuid1_1, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
# recompilation is grooming again
@test getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_1)[1]) == getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_2)[1])
@test installintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime) == ReturnCodes.SUCCESS

# single intent should not groom
@test compileintent!(ibnfs[1], intentuuid2, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1_1) == MINDF.IntentState.Installed
@test installintent!(ibnfs[1], intentuuid2; offsettime = nowtime) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid2; onlyinstalled=true, noextrallis = false) == true
# test that it's not groomed
@test getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_1)[1]) != getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid2)[1])
@test uninstallintent!(ibnfs[1], intentuuid2; offsettime = nowtime) == ReturnCodes.SUCCESS
@test uncompileintent!(ibnfs[1], intentuuid2; offsettime = nowtime) == ReturnCodes.SUCCESS


# test that availability intents without protection can be groomed
conintent3 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 15), u"5.0Gbps")
intentuuid3 = addintent!(ibnfs[1], conintent3, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid3, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
@test installintent!(ibnfs[1], intentuuid3; offsettime = nowtime) == ReturnCodes.SUCCESS
MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid3; onlyinstalled=false, choosealternativeorder=1)) == [4,3,14,15]

# test that availability intents without protection can be groomed
conintent4 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 15), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps")
intentuuid4 = addintent!(ibnfs[1], conintent4, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid4, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
@test installintent!(ibnfs[1], intentuuid4; offsettime = nowtime) == ReturnCodes.SUCCESS
MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid4; onlyinstalled=false, choosealternativeorder=1)) == [15,20,8]


# recompile intentuuid2 which now should use grooming of intentuuid3
@test compileintent!(ibnfs[1], intentuuid2, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
@test getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_1)[1]) != 

@test all(getidagnodeid.(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid2))) do childintentuuid2
    childintentuuid2 == getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid3)[1]) ||
    childintentuuid2 == getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid4)[1])
end

@test uninstallintent!(ibnfs[1], intentuuid3; offsettime = nowtime) == ReturnCodes.SUCCESS
@test uninstallintent!(ibnfs[1], intentuuid4; offsettime = nowtime) == ReturnCodes.SUCCESS
@test all(getidagnodeid.(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid2))) do childintentuuid2
    childintentuuid2 == getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid3)[1]) ||
    childintentuuid2 == getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid4)[1])
end

@test uncompileintent!(ibnfs[1], intentuuid3; offsettime = nowtime) == ReturnCodes.SUCCESS
@test uncompileintent!(ibnfs[1], intentuuid4; offsettime = nowtime) == ReturnCodes.SUCCESS
@test installintent!(ibnfs[1], intentuuid2; offsettime = nowtime) == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid2; onlyinstalled=true, noextrallis = false) == true
end
