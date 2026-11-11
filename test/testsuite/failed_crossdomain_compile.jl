@testset ExtendedTestSet "failed_crossdomain_compile.jl"  begin

# A failed compilation must leave the intent as it was. The algorithm-independent checks are in the core test suite
# (`TM.testsuitefailedcompilation!`, run by testsuite/conformance.jl); here only the first-fit consequence:
# after a failed cross-domain compile, another intent gets the first-fit slots, as on a fresh network.

nowtime = DateTime("2026-01-01")
compalg = MINDF.KShorestPathFirstFitCompilation(10; nodenum=1)
oxcslots(ibnf, id) = unique(getspectrumslotsrange(getintent(x)) for x in MINDF.getidagnodeleafs(getidag(ibnf), id) if getintent(x) isa OXCAddDropBypassSpectrumLLI)

# d1:4 -> d3:47 fails with all links of d3:47 down
ibnfs = loadmultidomaintestibnfs(compalg, nowtime)
d1, d3 = ibnfs[1], ibnfs[3]
for ed in (Edge(46, 47), Edge(47, 46), Edge(48, 47), Edge(47, 48))
    _, nowtime = setlinkstate!(d3, ed, false; offsettime = nowtime)
end
A, nowtime = addintent!(d1, ConnectivityIntent(GlobalNode(getibnfid(d1), 4), GlobalNode(getibnfid(d3), 47), u"100.0Gbps"), NetworkOperator(); offsettime = nowtime)
rc, nowtime = compileintent!(d1, A; offsettime = nowtime)
@test !issuccess(rc)

C, nowtime = addintent!(d1, ConnectivityIntent(GlobalNode(getibnfid(d1), 4), GlobalNode(getibnfid(d3), 12), u"100.0Gbps"), NetworkOperator(); offsettime = nowtime)
rc, nowtime = compileintent!(d1, C; offsettime = nowtime)
@test rc == ReturnCodes.SUCCESS
@test oxcslots(d1, C) == [1:4]

end
