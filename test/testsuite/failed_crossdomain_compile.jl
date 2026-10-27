@testset ExtendedTestSet "failed_crossdomain_compile.jl"  begin

# A failed compilation must leave the intent as it was: Uncompiled, no descendants, nothing staged, in any domain.
# The intra-domain branch already does so; the cross-domain branch must undo each failed attempt the same way.

nowtime = DateTime("2026-01-01")
compalg = MINDF.KShorestPathFirstFitCompilation(10; nodenum=1)

st(ibnf, id) = getidagnodestate(getidag(ibnf), id)
ndagnodes(ibnf) = length(getidagnodes(getidag(ibnf)))
nchildren(ibnf, id) = length(getidagnodechildren(getidag(ibnf), id))
oxcslots(ibnf, id) = unique(getspectrumslotsrange(getintent(x)) for x in MINDF.getidagnodeleafs(getidag(ibnf), id) if getintent(x) isa OXCAddDropBypassSpectrumLLI)
isolate47edges = (Edge(46, 47), Edge(47, 46), Edge(48, 47), Edge(47, 48))

"nothing is left in any domain: no DAG nodes except `keep` in domain 1, nothing reserved or staged"
function testclean(ibnfs; keep = 0)
    @test ndagnodes(ibnfs[1]) == keep
    @test all(ibnf -> ndagnodes(ibnf) == 0, ibnfs[2:end])
    foreach(nothingisallocated, ibnfs)
    foreach(testzerostaged, ibnfs)
    foreach(testoxcfiberallocationconsistency, ibnfs)
end

# cross-domain intent whose remote part fails: d1:4 -> d3:47 with all links of d3:47 down
ibnfs = loadmultidomaintestibnfs(compalg, nowtime)
d1, d3 = ibnfs[1], ibnfs[3]
for ed in isolate47edges
    _, nowtime = setlinkstate!(d3, ed, false; offsettime = nowtime)
end
A, nowtime = addintent!(d1, ConnectivityIntent(GlobalNode(getibnfid(d1), 4), GlobalNode(getibnfid(d3), 47), u"100.0Gbps"), NetworkOperator(); offsettime = nowtime)
for _ in 1:2 # a retry must behave the same
    rc, nowtime = compileintent!(d1, A; offsettime = nowtime)
    @test !issuccess(rc)
    @test st(d1, A) == IntentState.Uncompiled
    @test nchildren(d1, A) == 0
    testclean(ibnfs; keep = 1)
end

# the failed intent doesn't block resources for another intent: C gets the first-fit slots, as on a fresh network
C, nowtime = addintent!(d1, ConnectivityIntent(GlobalNode(getibnfid(d1), 4), GlobalNode(getibnfid(d3), 12), u"100.0Gbps"), NetworkOperator(); offsettime = nowtime)
rc, nowtime = compileintent!(d1, C; offsettime = nowtime)
@test rc == ReturnCodes.SUCCESS
@test oxcslots(d1, C) == [1:4]
rc, nowtime = uncompileintent!(d1, C; offsettime = nowtime)
@test rc == ReturnCodes.SUCCESS
rc, nowtime = removeintent!(d1, C; offsettime = nowtime)
@test rc == ReturnCodes.SUCCESS

# after the repair, A compiles, installs and tears down normally
for ed in isolate47edges
    nowtime += Dates.Hour(1)
    _, nowtime = setlinkstate!(d3, ed, true; offsettime = nowtime)
end
rc, nowtime = compileintent!(d1, A; offsettime = nowtime)
@test rc == ReturnCodes.SUCCESS
rc, nowtime = installintent!(d1, A; offsettime = nowtime)
@test rc == ReturnCodes.SUCCESS
@test st(d1, A) == IntentState.Installed
@test issatisfied(d1, A)
for f in (uninstallintent!, uncompileintent!, removeintent!)
    rc, nowtime = f(d1, A; offsettime = nowtime)
    @test rc == ReturnCodes.SUCCESS
end
testclean(ibnfs)
foreach(ibnf -> @test(TM.testallstatelogascendingtime(ibnf)), ibnfs)

# intent to a border node that fails: d1:4 -> d3:25 (border node of d1) at 5000 Gbps. Retries must not stack children.
ibnfs = loadmultidomaintestibnfs(compalg, nowtime)
d1, d3 = ibnfs[1], ibnfs[3]
@test MINDF.isbordernode(d1, GlobalNode(getibnfid(d3), 25))
A, nowtime = addintent!(d1, ConnectivityIntent(GlobalNode(getibnfid(d1), 4), GlobalNode(getibnfid(d3), 25), u"5000.0Gbps"), NetworkOperator(); offsettime = nowtime)
for _ in 1:3
    rc, nowtime = compileintent!(d1, A; offsettime = nowtime)
    @test !issuccess(rc)
    @test st(d1, A) == IntentState.Uncompiled
    @test nchildren(d1, A) == 0
    testclean(ibnfs; keep = 1)
end
rc, nowtime = removeintent!(d1, A; offsettime = nowtime)
@test rc == ReturnCodes.SUCCESS
testclean(ibnfs)

# reference: an intra-domain intent that fails leaves nothing behind
ibnfs = loadmultidomaintestibnfs(compalg, nowtime)
d1 = ibnfs[1]
A, nowtime = addintent!(d1, ConnectivityIntent(GlobalNode(getibnfid(d1), 4), GlobalNode(getibnfid(d1), 8), u"5000.0Gbps"), NetworkOperator(); offsettime = nowtime)
rc, nowtime = compileintent!(d1, A; offsettime = nowtime)
@test !issuccess(rc)
@test st(d1, A) == IntentState.Uncompiled
@test nchildren(d1, A) == 0
testclean(ibnfs; keep = 1)
rc, nowtime = removeintent!(d1, A; offsettime = nowtime)
@test rc == ReturnCodes.SUCCESS
testclean(ibnfs)

end
