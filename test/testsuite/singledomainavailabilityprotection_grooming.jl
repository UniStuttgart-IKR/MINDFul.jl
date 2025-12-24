@testset ExtendedTestSet "singledomainavailabilityprotection_grooming.jl"  begin
nowtime = starttime = DateTime("2026-01-01")

compalg = MINDF.BestEmpiricalAvailabilityCompilation(5, 5; nodenum=1)
ibnfs = loadmultidomaintestibnfs(compalg)

# basically best effort
avcon1 = MINDF.AvailabilityConstraint(0.94, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [avcon1])
avcon2 = MINDF.AvailabilityConstraint(0.90, 0.9) 
conintent2 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [avcon2])

intentuuid1_1, _ = addintent!(ibnfs[1], conintent1, NetworkOperator())
intentuuid1_2, _ = addintent!(ibnfs[1], conintent1, NetworkOperator())
intentuuid2, _ = addintent!(ibnfs[1], conintent2, NetworkOperator())

nowtime += Dates.Year(3) 

setlinkstate!(ibnfs[1], Edge(3=>14), false; offsettime = starttime + Dates.Month(3))
setlinkstate!(ibnfs[1], Edge(3=>14), true; offsettime = starttime + Dates.Month(6))
#
setlinkstate!(ibnfs[1], Edge(1=>6), false; offsettime = starttime + Dates.Month(4))
setlinkstate!(ibnfs[1], Edge(1=>6), true; offsettime = starttime + Dates.Month(8))

returncode, nowtime = compileintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
intentuuid1_protectedpath1 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1_1; onlyinstalled=false, choosealternativeorder=1))
@test intentuuid1_protectedpath1 == [4, 3, 14, 15, 20, 8]
intentuuid1_protectedpath2 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1_1; onlyinstalled=false, choosealternativeorder=2))
@test intentuuid1_protectedpath2 == [4, 1, 6, 20, 8]
returncode, nowtime = installintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS

# @test installintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime) == ReturnCodes.SUCCESS

# intentuuid1_2 should groom to a protection lightpath of the intentuuid1_1
returncode, nowtime = compileintent!(ibnfs[1], intentuuid1_2; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1_1) == MINDF.IntentState.Installed
returncode, nowtime = installintent!(ibnfs[1], intentuuid1_2; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid1_2; onlyinstalled=true, noextrallis = false) == true
# test that it's groomed
@test getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_1)[1]) == getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_2)[1])

# uninstall protected intent
returncode, nowtime = uninstallintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
# the groomed intent should remain installed
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1_2) == MINDF.IntentState.Installed
@test issatisfied(ibnfs[1], intentuuid1_2; onlyinstalled=true, noextrallis = false) == true

# uncompile protected intent
returncode, nowtime = uncompileintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
# the groomed intent should remain installed
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1_2) == MINDF.IntentState.Installed
@test issatisfied(ibnfs[1], intentuuid1_2; onlyinstalled=true, noextrallis = false) == true

# recompile protected intent
returncode, nowtime = compileintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
# recompilation is grooming again
@test getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_1)[1]) == getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_2)[1])
returncode, nowtime = installintent!(ibnfs[1], intentuuid1_1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS

# single intent should not groom because .... (of availability ?)
returncode, nowtime = compileintent!(ibnfs[1], intentuuid2; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1_1) == MINDF.IntentState.Installed
returncode, nowtime = installintent!(ibnfs[1], intentuuid2; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid2; onlyinstalled=true, noextrallis = false) == true
# test that it's not groomed
# @test getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid1_1)[1]) != getidagnodeid(MINDF.getidagnodechildren(getidag(ibnfs[1]), intentuuid2)[1])
returncode, nowtime = uninstallintent!(ibnfs[1], intentuuid2; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
returncode, nowtime = uncompileintent!(ibnfs[1], intentuuid2; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS


# test that availability intents without protection can be groomed
conintent3 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 15), u"5.0Gbps")
intentuuid3, _ = addintent!(ibnfs[1], conintent3, NetworkOperator())
returncode, nowtime = compileintent!(ibnfs[1], intentuuid3; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
returncode, nowtime = installintent!(ibnfs[1], intentuuid3; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid3; onlyinstalled=false, choosealternativeorder=1)) == [4,3,14,15]

# test that availability intents without protection can be groomed
conintent4 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 15), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps")
intentuuid4, _ = addintent!(ibnfs[1], conintent4, NetworkOperator())
returncode, nowtime = compileintent!(ibnfs[1], intentuuid4; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
returncode, nowtime = installintent!(ibnfs[1], intentuuid4; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid4; onlyinstalled=false, choosealternativeorder=1)) == [15,20,8]


# recompile intentuuid2 which now should use grooming of intentuuid3
returncode, nowtime = compileintent!(ibnfs[1], intentuuid2; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS

returncode, nowtime = uninstallintent!(ibnfs[1], intentuuid3; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
returncode, nowtime = uninstallintent!(ibnfs[1], intentuuid4; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS

returncode, nowtime = uncompileintent!(ibnfs[1], intentuuid3; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
returncode, nowtime = uncompileintent!(ibnfs[1], intentuuid4; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
returncode, nowtime = installintent!(ibnfs[1], intentuuid2; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS
@test issatisfied(ibnfs[1], intentuuid2; onlyinstalled=true, noextrallis = false) == true
end
