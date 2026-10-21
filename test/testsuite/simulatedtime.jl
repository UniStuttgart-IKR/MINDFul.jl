@testset ExtendedTestSet "simulatedtime.jl"  begin

nowtime = DateTime("2026-01-01")
compalg = MINDF.BestEmpiricalAvailabilityCompilation(5, 5; nodenum=1)
ibnfs = loadmultidomaintestibnfs(compalg, nowtime)

# a link state cannot be registered before the edge's last registered state
nowtime += Dates.Month(1)
_, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(3=>14), false; offsettime = nowtime)
@test_throws MINDF.SimulatedTimeError MINDF.setlinkstate!(ibnfs[1], Edge(3=>14), true; offsettime = nowtime - Dates.Hour(1))
_, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(3=>14), true; offsettime = nowtime)

# an intent state cannot be registered before the time its up/down times are already accounted until
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[3]), 24), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [MINDF.AvailabilityConstraint(0.999, 0.9)])
intentuuid1, nowtime = addintent!(ibnfs[3], conintent1, NetworkOperator(); offsettime = nowtime)
_, nowtime = compileintent!(ibnfs[3], intentuuid1; offsettime = nowtime)
_, nowtime = installintent!(ibnfs[3], intentuuid1; offsettime = nowtime)
remidagnode = getfirst(x -> getintent(x) isa RemoteIntent{<:ConnectivityIntent}, MINDF.getidagnodedescendants(MINDF.getidag(ibnfs[3]), intentuuid1))

nowtime += Dates.Month(1)
_, nowtime = MINDF.updatelogintentcomp!(ibnfs[3]; offsettime = nowtime)
accountedtime = MINDF.getdatetime(MINDF.getloginterupdowntimesperintent(ibnfs[3], getidagnodeid(remidagnode))[1])
# a link failure that reaches the remote intent with an `offsettime` older than the accounted time (what reusing an `offsettime` can cause)
@test_throws MINDF.SimulatedTimeError MINDF.setlinkstate!(ibnfs[1], Edge(15=>20), false; offsettime = accountedtime - Dates.Second(1))

end
