@testset ExtendedTestSet "logintraintertest.jl"  begin
nowtime = starttime = DateTime("2026-01-01")
ibnfs = loadmultidomaintestibnfs()

avcon1 = MINDF.AvailabilityConstraint(0.999, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [avcon1])
intentuuid1 = addintent!(ibnfs[1], conintent1, NetworkOperator(); offsettime = nowtime)
beacomp = MINDF.BestEmpiricalAvailabilityCompilation(5,5)

compileintent!(ibnfs[1], intentuuid1, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS

installintent!(ibnfs[1], intentuuid1, beacomp; offsettime = nowtime)

setlinkstate!(ibnfs[1], Edge(3=>14), false; offsettime = starttime + Dates.Month(3))
setlinkstate!(ibnfs[1], Edge(3=>14), true; offsettime = starttime + Dates.Month(6))

nowtime += Dates.Year(2) 
uninstallintent!(ibnfs[1], intentuuid1; offsettime = nowtime)

nowtime += Dates.Year(1) 

logstates1 = MINDF.getlogstate(MINDF.getidagnode(getidag(ibnfs[1]), intentuuid1))
updowntimes1 = MINDF.getupdowntimes(logstates1, nowtime)
@test length(MINDF.getuptimes(updowntimes1)) == 2
@test length(MINDF.getdowntimes(updowntimes1)) == 1
@test 20 <= sum(MINDF.getuptimesmonth(updowntimes1)) <= 22
@test 2 <= sum(MINDF.getdowntimesmonth(updowntimes1)) <= 4
@test MINDF.getlogintrapaths(beacomp)[Edge(4,8)][[MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1; onlyinstalled=false))]] == 1

installintent!(ibnfs[1], intentuuid1, beacomp; offsettime = nowtime)
@test MINDF.getlogintrapaths(beacomp)[Edge(4,8)][[MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid1))]] == 2

conintent2 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[3]), 12), u"5.0Gbps", [avcon1])
intentuuid2 = addintent!(ibnfs[1], conintent2, NetworkOperator(); offsettime = nowtime)
@test compileintent!(ibnfs[1], intentuuid2, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
nowtime = MINDF.getlateststateloggeddatetime(MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid2))
installintent!(ibnfs[1], intentuuid2, beacomp; offsettime = nowtime)
nowtime = MINDF.getlateststateloggeddatetime(MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid2))

remidagnode2 = getfirst(x -> getintent(x) isa RemoteIntent{<:ConnectivityIntent}, MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[1]), intentuuid2))

@test MINDF.getlogintrapaths(beacomp)[Edge(4,29)][[MINDF.logicalordergetpath(MINDF.getlogicallliorder(ibnfs[1], intentuuid2))]] == 1
@test length(MINDF.getloginterupdowntimes(beacomp)) == 1
updowntimesndatetime2 = MINDF.getloginterupdowntimes(beacomp)[GlobalEdge(GlobalNode(UUID(0x3), 25), GlobalNode(UUID(0x3), 12))][getidagnodeid(remidagnode2)]
@test sum(MINDF.getuptimes(updowntimesndatetime2)) < Dates.Second(5)
@test sum(MINDF.getdowntimes(updowntimesndatetime2)) < Dates.Second(5)


nowtime1 = nowtime
nowtime += Dates.Year(1) 
MINDF.updatelogintentcomp!(ibnfs[1], beacomp; offsettime=nowtime)

@test (nowtime - nowtime1) - Dates.Second(5) <= sum(MINDF.getuptimes(updowntimesndatetime2)) < (nowtime - nowtime1) + Dates.Second(5)

nowtime += Dates.Month(3) 
MINDF.updatelogintentcomp!(ibnfs[1], beacomp; offsettime=nowtime)

@test (nowtime - nowtime1) - Dates.Second(5) <= sum(MINDF.getuptimes(updowntimesndatetime2)) < (nowtime - nowtime1) + Dates.Second(5)
# upon compilation of another intent that should change time

nowtime2 = nowtime
setlinkstate!(ibnfs[3], Edge(23=>15), false; offsettime = nowtime)
nowtime += Dates.Second(5)

nowtime += Dates.Month(2) 
MINDF.updatelogintentcomp!(ibnfs[1], beacomp; offsettime=nowtime)

@test (nowtime - nowtime2) - Dates.Second(10) <= sum(MINDF.getdowntimes(updowntimesndatetime2)) < (nowtime - nowtime2) + Dates.Second(10)

nowtime += Dates.Month(2) 
MINDF.updatelogintentcomp!(ibnfs[1], beacomp; offsettime=nowtime)

@test (nowtime - nowtime2) - Dates.Second(10) <= sum(MINDF.getdowntimes(updowntimesndatetime2)) < (nowtime - nowtime2) + Dates.Second(10)

nowtime3 = nowtime
setlinkstate!(ibnfs[3], Edge(23=>15), true; offsettime = nowtime)
nowtime += Dates.Second(5)

nowtime += Dates.Month(3) 
MINDF.updatelogintentcomp!(ibnfs[1], beacomp; offsettime=nowtime)

upperiod2 = (nowtime - nowtime1) - (nowtime3 - nowtime2)
@test upperiod2 - Dates.Second(5) <= sum(MINDF.getuptimes(updowntimesndatetime2)) < upperiod2 + Dates.Second(5)
@test length(MINDF.getuptimes(updowntimesndatetime2)) == 2
@test length(MINDF.getdowntimes(updowntimesndatetime2)) == 1

nowtime4 = nowtime
setlinkstate!(ibnfs[3], Edge(23=>15), false; offsettime = nowtime)
nowtime += Dates.Second(5)

nowtime += Dates.Month(4) 
MINDF.updatelogintentcomp!(ibnfs[1], beacomp; offsettime=nowtime)

downperiod = (nowtime - nowtime4) + (nowtime3 - nowtime2)
@test downperiod - Dates.Second(5) <= sum(MINDF.getdowntimes(updowntimesndatetime2)) < downperiod + Dates.Second(5)
@test length(MINDF.getuptimes(updowntimesndatetime2)) == 2
@test length(MINDF.getdowntimes(updowntimesndatetime2)) == 2

nowtime5 = nowtime
setlinkstate!(ibnfs[3], Edge(23=>15), true; offsettime = nowtime)
nowtime += Dates.Second(5)

#### Conintent3

nowtime += Dates.Year(1)
conintent3 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 22), GlobalNode(getibnfid(ibnfs[3]), 12), u"5.0Gbps", [avcon1])
intentuuid3 = addintent!(ibnfs[1], conintent3, NetworkOperator(); offsettime = nowtime)
compileintent!(ibnfs[1], intentuuid3, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
nowtime = MINDF.getlateststateloggeddatetime(MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid3))

upperiod2_2 = upperiod2 + (nowtime - nowtime5)
@test upperiod2_2 - Dates.Second(10) <= sum(MINDF.getuptimes(updowntimesndatetime2)) < upperiod2_2 + Dates.Second(10)
@test length(MINDF.getuptimes(updowntimesndatetime2)) == 3
@test length(MINDF.getdowntimes(updowntimesndatetime2)) == 2

# uncompiling should also update the logs

uncompileintent!(ibnfs[1], intentuuid3, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
@test upperiod2_2 - Dates.Second(10) <= sum(MINDF.getuptimes(updowntimesndatetime2)) < upperiod2_2 + Dates.Second(10)
@test length(MINDF.getuptimes(updowntimesndatetime2)) == 3
@test length(MINDF.getdowntimes(updowntimesndatetime2)) == 2

# compile and keep going
compileintent!(ibnfs[1], intentuuid3, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS

# give some time
nowtime += Dates.Month(2)
upperiod2_3 = upperiod2 + (nowtime - nowtime5)
uncompileintent!(ibnfs[1], intentuuid3, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS
@test upperiod2_3 - Dates.Second(10) <= sum(MINDF.getuptimes(updowntimesndatetime2)) < upperiod2_3 + Dates.Second(10)
@test length(MINDF.getuptimes(updowntimesndatetime2)) == 3
@test length(MINDF.getdowntimes(updowntimesndatetime2)) == 2

# compile and keep going
compileintent!(ibnfs[1], intentuuid3, beacomp; offsettime = nowtime) == ReturnCodes.SUCCESS


installintent!(ibnfs[1], intentuuid3, beacomp; offsettime = nowtime)
nowtime = MINDF.getlateststateloggeddatetime(MINDF.getidagnode(MINDF.getidag(ibnfs[1]), intentuuid3))

@test length(MINDF.getloginterupdowntimes(beacomp)[GlobalEdge(GlobalNode(UUID(0x3), 25), GlobalNode(UUID(0x3), 12))]) == 2
remidagnode3 = getfirst(x -> getintent(x) isa RemoteIntent{<:ConnectivityIntent}, MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[1]), intentuuid3))
updowntimesndatetime3 = MINDF.getloginterupdowntimes(beacomp)[GlobalEdge(GlobalNode(UUID(0x3), 25), GlobalNode(UUID(0x3), 12))][getidagnodeid(remidagnode3)]

end
