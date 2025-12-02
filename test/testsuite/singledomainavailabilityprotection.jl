# @testset ExtendedTestSet "singledomainavailabilityprotection.jl"  begin

nowtime = DateTime("2026-01-01")
starttime = nowtime

compalg = MINDF.BestEmpiricalAvailabilityCompilation(5, 5; nodenum=1)

ibnfs = loadmultidomaintestibnfs(compalg, nowtime)

avcon1 = MINDF.AvailabilityConstraint(0.94, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [avcon1])

intentuuid1, nowtime = addintent!(ibnfs[1], conintent1, NetworkOperator(); offsettime=nowtime)

nowtime += Dates.Year(3) 

returncode, nowtime = compileintent!(ibnfs[1], intentuuid1; offsettime = nowtime)
path1 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1; onlyinstalled=false))
@test path1 == [4, 3, 14, 15, 20, 8]
@test MINDF.getempiricalavailability(ibnfs[1], path1; endtime = nowtime) > MINDF.getavailabilityrequirement(avcon1)
returncode, nowtime = MINDF.uncompileintent!(ibnfs[1], intentuuid1; offsettime = nowtime)

returncode, _ = setlinkstate!(ibnfs[1], Edge(3=>14), false; offsettime = starttime + Dates.Month(3))
returncode, _ = setlinkstate!(ibnfs[1], Edge(3=>14), true; offsettime = starttime + Dates.Month(6))
@test MINDF.getempiricalavailability(ibnfs[1], path1; endtime = nowtime) < 0.94


returncode, nowtime = compileintent!(ibnfs[1], intentuuid1; offsettime = nowtime)
path2 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1; onlyinstalled=false))
@test MINDF.getempiricalavailability(ibnfs[1], path2; endtime = nowtime) > MINDF.getavailabilityrequirement(avcon1)
MINDF.uncompileintent!(ibnfs[1], intentuuid1; offsettime = nowtime)

returncode, _ = setlinkstate!(ibnfs[1], Edge(1=>6), false; offsettime = starttime + Dates.Month(4))
returncode, _ = setlinkstate!(ibnfs[1], Edge(1=>6), true; offsettime = starttime + Dates.Month(8))
@test MINDF.getempiricalavailability(ibnfs[1], path2; endtime = nowtime) < 0.94

# now should pick a protected path
returncode, nowtime = compileintent!(ibnfs[1], intentuuid1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS

@test MINDF.issatisfied(ibnfs[1], intentuuid1; onlyinstalled=false, noextrallis=false, choosealternativeorder=0) == false
@test MINDF.issatisfied(ibnfs[1], intentuuid1; onlyinstalled=false, noextrallis=false, choosealternativeorder=1) == true
@test MINDF.issatisfied(ibnfs[1], intentuuid1; onlyinstalled=false, noextrallis=false, choosealternativeorder=2) == true

protectedpath1 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1; onlyinstalled=false, choosealternativeorder=1))
@test protectedpath1 == [4, 3, 14, 15, 20, 8]
protectedpath2 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1; onlyinstalled=false, choosealternativeorder=2))
@test protectedpath2 == [4, 1, 6, 20, 8]
protectedpath1availability = MINDF.getempiricalavailability(ibnfs[1], protectedpath1; endtime = nowtime)
protectedpath2availability = MINDF.getempiricalavailability(ibnfs[1], protectedpath2; endtime = nowtime)
@test MINDF.calculateparallelavailability(protectedpath1availability, protectedpath2availability) > MINDF.getavailabilityrequirement(avcon1)


# do an intent state circle 
returncode, nowtime = MINDF.installintent!(ibnfs[1], intentuuid1; offsettime=nowtime) 
@test returncode == ReturnCodes.SUCCESS
returncode, nowtime = MINDF.uninstallintent!(ibnfs[1], intentuuid1; offsettime=nowtime) 
@test returncode == ReturnCodes.SUCCESS
returncode, nowtime = MINDF.uncompileintent!(ibnfs[1], intentuuid1; offsettime=nowtime) 
@test returncode == ReturnCodes.SUCCESS

TM.testzerostaged(ibnfs[1])
#
returncode, nowtime = compileintent!(ibnfs[1], intentuuid1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS

returncode, nowtime = MINDF.installintent!(ibnfs[1], intentuuid1; offsettime = nowtime)
@test returncode == ReturnCodes.SUCCESS

#
installedpath1 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1; onlyinstalled=true))
@test installedpath1 == protectedpath1

idagnodes2install0 = MINDF.getidagnodeleafs2install(ibnfs[1], UUID(0x1))

# this should trigger the ProtectedLightpathIntent to change installation choice
nowtime += Dates.Hour(1)
returncode, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(15, 20), false; offsettime=nowtime)

# TODO check LLIs of the uninstalling branch must be "Compiled"

@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1) == MINDF.IntentState.Installed
@test MINDF.issatisfied(ibnfs[1], intentuuid1, noextrallis = false)
idagnodes2install1 = MINDF.getidagnodeleafs2install(ibnfs[1], UUID(0x1))

installedpath2 = MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1; onlyinstalled=true))
@test installedpath2 == protectedpath2

# fail also the other link
nowtime += Dates.Hour(1)
returncode, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(6, 20), false; offsettime=nowtime)

idagnodes2install2 = MINDF.getidagnodeleafs2install(ibnfs[1], UUID(0x1))

@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1) == MINDF.IntentState.Failed
@test !MINDF.issatisfied(ibnfs[1], intentuuid1, noextrallis = false)

# one of the links is up
nowtime += Dates.Hour(1)
_, nowtime =MINDF.setlinkstate!(ibnfs[1], Edge(6, 20), true; offsettime=nowtime)
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1) == MINDF.IntentState.Installed
@test MINDF.issatisfied(ibnfs[1], intentuuid1, noextrallis = false)

# make it down again
nowtime += Dates.Hour(1)
returncode, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(6, 20), false; offsettime=nowtime)

# now lift the other link. The intent should understand and change configuration automatically
nowtime += Dates.Hour(1)
returncode, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(15, 20), true; offsettime=nowtime)
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1) == MINDF.IntentState.Installed
@test MINDF.issatisfied(ibnfs[1], intentuuid1, noextrallis = false)
@test Dates.Millisecond(0) <= MINDF.getlogtuplettime(MINDF.getlogstate(MINDF.getidagnode(getidag(ibnfs[1]), intentuuid1))[end]) - nowtime < Dates.Millisecond(500)

# what if the failed equipment is shared ?
nowtime += Dates.Hour(1)
returncode, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(20, 8), false; offsettime=nowtime)
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1) == MINDF.IntentState.Failed
@test !MINDF.issatisfied(ibnfs[1], intentuuid1, noextrallis = false)
@test isempty(MINDF.getidagnodeleafs2install(ibnfs[1], intentuuid1))
@test Dates.Millisecond(0) <= MINDF.getlogtuplettime(MINDF.getlogstate(MINDF.getidagnode(getidag(ibnfs[1]), intentuuid1))[end]) - nowtime < Dates.Millisecond(500)

# make up but should'nt make a difference because common equipment is failing
nowtime += Dates.Hour(1)
returncode, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(6, 20), true; offsettime=nowtime)
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1) == MINDF.IntentState.Failed
@test !MINDF.issatisfied(ibnfs[1], intentuuid1, noextrallis = false)
@test isempty(MINDF.getidagnodeleafs2install(ibnfs[1], intentuuid1))
@test Dates.Hour(1) + Dates.Millisecond(100) >= nowtime - MINDF.getlogtuplettime(MINDF.getlogstate(MINDF.getidagnode(getidag(ibnfs[1]), intentuuid1))[end]) >= Dates.Hour(1)


# give an impossible availability to cover
avcon2 = MINDF.AvailabilityConstraint(0.9999, 0.99999) 
conintent2 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [avcon2])
intentuuid2, nowtime = addintent!(ibnfs[1], conintent2, NetworkOperator(); offsettime=nowtime)

returncode, nowtime = compileintent!(ibnfs[1], intentuuid2; offsettime = nowtime)
@test returncode == ReturnCodes.FAIL_CANDIDATEPATHS

# fail for an instance to see logs
nowtime += Dates.Year(3)
returncode, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(20, 8), true; offsettime=nowtime)
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1) == MINDF.IntentState.Installed
logstate1 = MINDF.getlogstate(MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid1))

lsuntilnow = length(logstate1)
nowtime += Dates.Month(3)
# one fail but should immediately switch to protection
returncode, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(3, 14), false; offsettime=nowtime)
@test MINDF.getidagnodestate(getidag(ibnfs[1]), intentuuid1) == MINDF.IntentState.Installed
newlogstates = logstate1[lsuntilnow:end]


# end
