@testset ExtendedTestSet "increasingtimestamps.jl"  begin

# same actions as updowntimes_interdomain.jl: an inter-domain intent plus link failures and repairs
nowtime = DateTime("2026-01-01")
compalg = MINDF.BestEmpiricalAvailabilityCompilation(5, 5; nodenum=1)
ibnfs = loadmultidomaintestibnfs(compalg, nowtime)
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[3]), 24), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [MINDF.AvailabilityConstraint(0.999, 0.9)])
intentuuid1, _ = addintent!(ibnfs[3], conintent1, NetworkOperator(); offsettime = nowtime)
_, nowtime = compileintent!(ibnfs[3], intentuuid1; offsettime = nowtime)
_, nowtime = installintent!(ibnfs[3], intentuuid1; offsettime = nowtime)

updatelogs!() = MINDF.updatelogintentcomp!(ibnfs[3]; offsettime = nowtime)
setlinkstate1!(ed, state) = MINDF.setlinkstate!(ibnfs[1], ed, state; offsettime = nowtime)

nowtime += Dates.Month(7);  updatelogs!(); updatelogs!()
nowtime += Dates.Month(10); setlinkstate1!(Edge(15=>20), false)
nowtime += Dates.Month(2);  updatelogs!()
nowtime += Dates.Month(2);  updatelogs!()
nowtime += Dates.Month(1);  setlinkstate1!(Edge(14=>15), false)
nowtime += Dates.Month(2);  setlinkstate1!(Edge(15=>20), true)
nowtime += Dates.Month(1);  setlinkstate1!(Edge(14=>15), true)
nowtime += Dates.Month(1);  updatelogs!()
setlinkstate1!(Edge(15=>20), false)
nowtime += Dates.Month(2);  updatelogs!()
setlinkstate1!(Edge(15=>20), true)
nowtime += Dates.Month(2);  updatelogs!()

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
