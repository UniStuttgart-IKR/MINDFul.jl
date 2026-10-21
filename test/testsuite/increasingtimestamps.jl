@testset ExtendedTestSet "increasingtimestamps.jl"  begin

# same actions as updowntimes_interdomain.jl: an inter-domain intent plus link failures and repairs
nowtime = DateTime("2026-01-01")
compalg = MINDF.BestEmpiricalAvailabilityCompilation(5, 5; nodenum=1)
ibnfs = loadmultidomaintestibnfs(compalg, nowtime)
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[3]), 24), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [MINDF.AvailabilityConstraint(0.999, 0.9)])
intentuuid1, nowtime = addintent!(ibnfs[3], conintent1, NetworkOperator(); offsettime = nowtime)
_, nowtime = compileintent!(ibnfs[3], intentuuid1; offsettime = nowtime)
_, nowtime = installintent!(ibnfs[3], intentuuid1; offsettime = nowtime)

nowtime += Dates.Month(7)
_, nowtime = MINDF.updatelogintentcomp!(ibnfs[3]; offsettime = nowtime)
_, nowtime = MINDF.updatelogintentcomp!(ibnfs[3]; offsettime = nowtime)
nowtime += Dates.Month(10)
_, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(15=>20), false; offsettime = nowtime)
nowtime += Dates.Month(2)
_, nowtime = MINDF.updatelogintentcomp!(ibnfs[3]; offsettime = nowtime)
nowtime += Dates.Month(2)
_, nowtime = MINDF.updatelogintentcomp!(ibnfs[3]; offsettime = nowtime)
nowtime += Dates.Month(1)
_, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(14=>15), false; offsettime = nowtime)
nowtime += Dates.Month(2)
_, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(15=>20), true; offsettime = nowtime)
nowtime += Dates.Month(1)
_, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(14=>15), true; offsettime = nowtime)
nowtime += Dates.Month(1)
_, nowtime = MINDF.updatelogintentcomp!(ibnfs[3]; offsettime = nowtime)
_, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(15=>20), false; offsettime = nowtime)
nowtime += Dates.Month(2)
_, nowtime = MINDF.updatelogintentcomp!(ibnfs[3]; offsettime = nowtime)
_, nowtime = MINDF.setlinkstate!(ibnfs[1], Edge(15=>20), true; offsettime = nowtime)
nowtime += Dates.Month(2)
_, nowtime = MINDF.updatelogintentcomp!(ibnfs[3]; offsettime = nowtime)

for ibnf in ibnfs
    # all logs are serially incremental timestamps
    @test TM.testlinklogsseriallyincrementaltimestamps(ibnf)

    # intent states serially incremental timestamps
    @test TM.testintentstateseriallyincreamentaltimestamps(ibnf)

    # no negatives in UpDownTimes
    for dictuuidconnectiondata in values(MINDF.getloginterupdowntimes(getintcompalg(ibnf))), connectiondata in values(dictuuidconnectiondata)
        updowntimesndatetime = MINDF.getupdowntimesndatetime(connectiondata)
        @test all(>=(Dates.Millisecond(0)), MINDF.getuptimes(updowntimesndatetime))
        @test all(>=(Dates.Millisecond(0)), MINDF.getdowntimes(updowntimesndatetime))
    end
end

end
