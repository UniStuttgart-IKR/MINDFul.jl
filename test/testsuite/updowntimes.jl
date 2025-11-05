@testset ExtendedTestSet "updowntimes.jl"  begin

nowtime = starttime = DateTime("2026-01-01")

compalg = MINDF.BestEmpiricalAvailabilityCompilation(5, 5; nodenum=1)
ibnfs = loadmultidomaintestibnfs(compalg, nowtime)

avcon1 = MINDF.AvailabilityConstraint(0.999, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [avcon1])
intentuuid1, _ = addintent!(ibnfs[1], conintent1, NetworkOperator(); offsettime = nowtime)

_, nowtime = compileintent!(ibnfs[1], intentuuid1; offsettime = nowtime)
_, nowtime = installintent!(ibnfs[1], intentuuid1; offsettime = nowtime)
nowtime1 = nowtime 

idn1 = MINDF.getidagnode(getidag(ibnfs[1]), intentuuid1)
logstates1 = MINDF.getlogstate(idn1)

nowtime += Dates.Month(7) # some uptime
nowtime2 = nowtime 

updowntimesndt1 = MINDF.getupdowntimes(MINDF.getlogstate(idn1))
@test length(MINDF.getdatetimestamps(updowntimesndt1)) == 1
@test length(MINDF.getuptimes(updowntimesndt1)) == 0
@test length(MINDF.getdowntimes(updowntimesndt1)) == 0

updowntimesndt2 = MINDF.getupdowntimes(MINDF.getlogstate(idn1), nowtime)
# updating dt1 should be the same
MINDF.updateupdowntimes!(updowntimesndt1, logstates1, nowtime)

time2test = nowtime - nowtime1
for updndt in [updowntimesndt1, updowntimesndt2]
    @test length(MINDF.getdatetimestamps(updndt)) == 1
    @test length(MINDF.getuptimes(updndt)) == 1
    @test length(MINDF.getdowntimes(updndt)) == 0
    @test time2test - Dates.Second(5) < sum(MINDF.getuptimes(updndt)) < time2test + Dates.Second(5)
end
MINDF.updateupdowntimes!(updowntimesndt1, logstates1, nowtime) #shouldn't change anything
let updndt = updowntimesndt1
    @test length(MINDF.getdatetimestamps(updndt)) == 1
    @test length(MINDF.getuptimes(updndt)) == 1
    @test length(MINDF.getdowntimes(updndt)) == 0
    @test time2test - Dates.Second(5) < sum(MINDF.getuptimes(updndt)) < time2test + Dates.Second(5)
end


nowtime += Dates.Month(10) # before first break
nowtime3 = nowtime

rct, nowtime3 = MINDF.setlinkstate!(ibnfs[1], Edge(15=>20), false; offsettime = nowtime)

nowtime += Dates.Month(2) # some downtime
nowtime4 = nowtime 

updowntimesndt2 = MINDF.getupdowntimes(MINDF.getlogstate(idn1), nowtime)
MINDF.updateupdowntimes!(updowntimesndt1, logstates1, nowtime)

for updndt in [updowntimesndt1, updowntimesndt2]
    @test length(MINDF.getdatetimestamps(updndt)) == 2
    @test length(MINDF.getuptimes(updndt)) == 1
    @test length(MINDF.getdowntimes(updndt)) == 1
    @test nowtime3 - nowtime1 - Dates.Second(5) < sum(MINDF.getuptimes(updndt)) < nowtime3 - nowtime1 + Dates.Second(5)
    @test nowtime4 - nowtime3 - Dates.Second(5) < sum(MINDF.getdowntimes(updndt)) < nowtime4 - nowtime3 + Dates.Second(5)
end


nowtime += Dates.Month(2) # some downtime
nowtime5 = nowtime 

updowntimesndt2 = MINDF.getupdowntimes(MINDF.getlogstate(idn1), nowtime)
MINDF.updateupdowntimes!(updowntimesndt1, logstates1, nowtime)
for updndt in [updowntimesndt1, updowntimesndt2]
    @test length(MINDF.getdatetimestamps(updndt)) == 2
    @test length(MINDF.getuptimes(updndt)) == 1
    @test length(MINDF.getdowntimes(updndt)) == 1
    @test nowtime3 - nowtime1 - Dates.Second(5) < sum(MINDF.getuptimes(updndt)) < nowtime3 - nowtime1 + Dates.Second(5)
    @test nowtime5 - nowtime3 - Dates.Second(5) < sum(MINDF.getdowntimes(updndt)) < nowtime5 - nowtime3 + Dates.Second(5)
end

nowtime += Dates.Month(1) # some more downtime
nowtime6 = nowtime 

MINDF.setlinkstate!(ibnfs[1], Edge(14=>15), false; offsettime = nowtime) 

nowtime += Dates.Month(2)
nowtime7 = nowtime 

MINDF.setlinkstate!(ibnfs[1], Edge(15=>20), true; offsettime = nowtime)

nowtime += Dates.Month(1)
nowtime8 = nowtime 

MINDF.setlinkstate!(ibnfs[1], Edge(14=>15), true; offsettime = nowtime)

nowtime += Dates.Month(1)
nowtime9 = nowtime 

updowntimesndt2 = MINDF.getupdowntimes(MINDF.getlogstate(idn1), nowtime)
MINDF.updateupdowntimes!(updowntimesndt1, logstates1, nowtime)
uptime1 = nowtime9 - nowtime8 + nowtime3 - nowtime1
downtime1 = nowtime8 - nowtime3
for updndt in [updowntimesndt1, updowntimesndt2]
    @test length(MINDF.getdatetimestamps(updndt)) == 3
    @test length(MINDF.getuptimes(updndt)) == 2
    @test length(MINDF.getdowntimes(updndt)) == 1
    @test uptime1 - Dates.Second(5) < sum(MINDF.getuptimes(updndt)) < uptime1 + Dates.Second(5)
    @test downtime1 - Dates.Second(5) < sum(MINDF.getdowntimes(updndt)) < downtime1 + Dates.Second(5)
end

# down again
MINDF.setlinkstate!(ibnfs[1], Edge(15=>20), false; offsettime = nowtime)
nowtime += Dates.Month(2)
nowtime10 = nowtime 

updowntimesndt2 = MINDF.getupdowntimes(MINDF.getlogstate(idn1), nowtime)
MINDF.updateupdowntimes!(updowntimesndt1, logstates1, nowtime)
downtime1 += nowtime10 - nowtime9
for updndt in [updowntimesndt1, updowntimesndt2]
    @test length(MINDF.getdatetimestamps(updndt)) == 4
    @test length(MINDF.getuptimes(updndt)) == 2
    @test length(MINDF.getdowntimes(updndt)) == 2
    @test uptime1 - Dates.Second(5) < sum(MINDF.getuptimes(updndt)) < uptime1 + Dates.Second(5)
    @test downtime1 - Dates.Second(5) < sum(MINDF.getdowntimes(updndt)) < downtime1 + Dates.Second(5)
end


# up again
MINDF.setlinkstate!(ibnfs[1], Edge(15=>20), true; offsettime = nowtime)
nowtime += Dates.Month(2)
nowtime11 = nowtime 

updowntimesndt2 = MINDF.getupdowntimes(MINDF.getlogstate(idn1), nowtime)
MINDF.updateupdowntimes!(updowntimesndt1, logstates1, nowtime)
uptime1 +=  nowtime11 - nowtime10
for updndt in [updowntimesndt1, updowntimesndt2]
    @test length(MINDF.getdatetimestamps(updndt)) == 5
    @test length(MINDF.getuptimes(updndt)) == 3
    @test length(MINDF.getdowntimes(updndt)) == 2
    @test uptime1 - Dates.Second(5) < sum(MINDF.getuptimes(updndt)) < uptime1 + Dates.Second(5)
    @test downtime1 - Dates.Second(5) < sum(MINDF.getdowntimes(updndt)) < downtime1 + Dates.Second(5)
end

end
