@testset ExtendedTestSet "consecutive_link_failure.jl"  begin

# An OXC LLI that bypasses a node uses two links. If both fail and only one is repaired,
# the LLI (and the lightpath and intent above it) must stay Failed.

nowtime = DateTime("2026-01-01")
compalg = MINDF.KShorestPathFirstFitCompilation(10; nodenum=1)
ibnf = loadmultidomaintestibnfs(compalg, nowtime)[1]

oxcllinodes(ibnf) = [idn for idn in MINDF.getidagnodes(getidag(ibnf)) if getintent(idn) isa OXCAddDropBypassSpectrumLLI]

conintent = ConnectivityIntent(GlobalNode(getibnfid(ibnf), 4), GlobalNode(getibnfid(ibnf), 8), u"30.0Gbps")
intentuuid, nowtime = addintent!(ibnf, conintent, NetworkOperator(); offsettime = nowtime)
_, nowtime = compileintent!(ibnf, intentuuid; offsettime = nowtime)
_, nowtime = installintent!(ibnf, intentuuid; offsettime = nowtime)
@test MINDF.logicalordergetpath(getlogicallliorder(ibnf, intentuuid)) == [4, 3, 14, 15, 20, 8]

# fail three consecutive links of the path
for ed in (Edge(3, 14), Edge(14, 15), Edge(15, 20))
    nowtime += Dates.Hour(1)
    _, nowtime = setlinkstate!(ibnf, ed, false; offsettime = nowtime)
end
@test getidagnodestate(getidag(ibnf), intentuuid) == IntentState.Failed
testoxcllistateconsistency(ibnf)

# repair the two outer links: the OXC LLIs at nodes 14 and 15 still use the failed link 14->15
for ed in (Edge(3, 14), Edge(15, 20))
    nowtime += Dates.Hour(1)
    _, nowtime = setlinkstate!(ibnf, ed, true; offsettime = nowtime)
end
for idn in oxcllinodes(ibnf)
    @test (getidagnodestate(idn) == IntentState.Failed) == MINDF.isoxcllifail(ibnf, getintent(idn))
end
@test getidagnodestate(getidag(ibnf), intentuuid) == IntentState.Failed
@test !issatisfied(ibnf, intentuuid)
testoxcllistateconsistency(ibnf)

# repair the last link: everything is installed again
nowtime += Dates.Hour(1)
_, nowtime = setlinkstate!(ibnf, Edge(14, 15), true; offsettime = nowtime)
@test all(idn -> getidagnodestate(idn) == IntentState.Installed, oxcllinodes(ibnf))
@test getidagnodestate(getidag(ibnf), intentuuid) == IntentState.Installed
@test issatisfied(ibnf, intentuuid)
testoxcllistateconsistency(ibnf)
@test TM.testallstatelogascendingtime(ibnf)

# Cross-domain: intent d1:4 -> d2:5 uses the border link d1 Edge(1, 27) == d2 Edge(59, 21).
# Each domain owns the OXC at its own end: d1 LLI (1, 4, 0, 27) and d2 LLI (21, 59, 0, 25).
oxcllistate(ibnf, localnode) = getidagnodestate(only(idn for idn in oxcllinodes(ibnf) if MINDF.getlocalnode(getintent(idn)) == localnode))

function installcrossdomainintent(compalg, nowtime)
    ibnfs = loadmultidomaintestibnfs(compalg, nowtime)
    conintent = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[2]), 5), u"30.0Gbps")
    intentuuid, nowtime = addintent!(ibnfs[1], conintent, NetworkOperator(); offsettime = nowtime)
    _, nowtime = compileintent!(ibnfs[1], intentuuid; offsettime = nowtime)
    _, nowtime = installintent!(ibnfs[1], intentuuid; offsettime = nowtime)
    @test getintent(only(idn for idn in oxcllinodes(ibnfs[1]) if MINDF.getlocalnode(getintent(idn)) == 1)) == OXCAddDropBypassSpectrumLLI(1, 4, 0, 27, 1:4)
    @test getintent(only(idn for idn in oxcllinodes(ibnfs[2]) if MINDF.getlocalnode(getintent(idn)) == 21)) == OXCAddDropBypassSpectrumLLI(21, 59, 0, 25, 1:4)
    return ibnfs[1], ibnfs[2], intentuuid, nowtime
end

# border link and d2-internal 21->25 fail, only the border link is repaired: the d2 LLI at 21 still uses 21->25
d1, d2, intentuuid, nowtime = installcrossdomainintent(compalg, nowtime)
nowtime += Dates.Hour(1)
_, nowtime = setlinkstate!(d1, Edge(1, 27), false; offsettime = nowtime)
nowtime += Dates.Hour(1)
_, nowtime = setlinkstate!(d2, Edge(21, 25), false; offsettime = nowtime)
nowtime += Dates.Hour(1)
_, nowtime = setlinkstate!(d1, Edge(1, 27), true; offsettime = nowtime)
@test oxcllistate(d1, 1) == IntentState.Installed
@test oxcllistate(d2, 21) == IntentState.Failed
@test getidagnodestate(getidag(d1), intentuuid) == IntentState.Failed
testoxcllistateconsistency(d1)
testoxcllistateconsistency(d2)
nowtime += Dates.Hour(1)
_, nowtime = setlinkstate!(d2, Edge(21, 25), true; offsettime = nowtime)
@test getidagnodestate(getidag(d1), intentuuid) == IntentState.Installed
testoxcllistateconsistency(d1)
testoxcllistateconsistency(d2)
@test TM.testallstatelogascendingtime(d1)
@test TM.testallstatelogascendingtime(d2)

# d1-internal 4->1 and border link fail, only the border link is repaired (reported by d2): the d1 LLI at 1 still uses 4->1
d1, d2, intentuuid, nowtime = installcrossdomainintent(compalg, nowtime)
nowtime += Dates.Hour(1)
_, nowtime = setlinkstate!(d1, Edge(4, 1), false; offsettime = nowtime)
nowtime += Dates.Hour(1)
_, nowtime = setlinkstate!(d2, Edge(59, 21), false; offsettime = nowtime)
nowtime += Dates.Hour(1)
_, nowtime = setlinkstate!(d2, Edge(59, 21), true; offsettime = nowtime)
@test oxcllistate(d2, 21) == IntentState.Installed
@test oxcllistate(d1, 1) == IntentState.Failed
@test getidagnodestate(getidag(d1), intentuuid) == IntentState.Failed
testoxcllistateconsistency(d1)
testoxcllistateconsistency(d2)
nowtime += Dates.Hour(1)
_, nowtime = setlinkstate!(d1, Edge(4, 1), true; offsettime = nowtime)
@test getidagnodestate(getidag(d1), intentuuid) == IntentState.Installed
testoxcllistateconsistency(d1)
testoxcllistateconsistency(d2)
@test TM.testallstatelogascendingtime(d1)
@test TM.testallstatelogascendingtime(d2)

end
