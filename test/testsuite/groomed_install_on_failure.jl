@testset ExtendedTestSet "groomed_install_on_failure.jl"  begin

# Intent A is installed on lightpath L. Intent B is compiled by grooming onto L, so L is shared by A and B.
# A link of L fails while B is only compiled. Then:
# - installing B must leave A and B Failed (reserved on the failed L), and both recover on repair;
# - uninstalling/removing A must leave the leaves of L staged for B.

nowtime = DateTime("2026-01-01")
compalg = MINDF.KShorestPathFirstFitCompilation(10; nodenum=1)

st(ibnf, id) = getidagnodestate(getidag(ibnf), id)
ninstalledlightpaths(ibnf) = length(getinstalledlightpaths(getidaginfo(getidag(ibnf))))
"all reserved LLIs over the transmission modules, router ports and OXCs of all intra-domain nodes"
reservedllis(ibnf) = Set(lli for nodeview in MINDF.getintranodeviews(getibnag(ibnf))
    for view in (nodeview, getrouterview(nodeview), getoxcview(nodeview)) for lli in values(getreservations(view)))
"all staged LLIs over the transmission modules, router ports and OXCs of all intra-domain nodes"
stagedllis(ibnf) = Set(lli for nodeview in MINDF.getintranodeviews(getibnag(ibnf))
    for view in (nodeview, getrouterview(nodeview), getoxcview(nodeview)) for lli in getstaged(view))
leafllis(ibnf, id) = Set(getintent(idn) for idn in MINDF.getidagnodeleafs(getidag(ibnf), id))
"the spectrum of every OXC LLI of `id` is marked as used on all its links"
function spectrumblocked(ibnf, id)
    return all(leafllis(ibnf, id)) do lli
        lli isa OXCAddDropBypassSpectrumLLI || return true
        oxcview = getoxcview(getnodeview(getibnag(ibnf), getlocalnode(lli)))
        all(ed -> !any(getlinkspectrumavailabilities(oxcview)[ed][getspectrumslotsrange(lli)]), MINDF.getoxclliedges(lli))
    end
end

"A = 4 -> 8 installed on L = 4-3-14-15-20-8. B = same endpoints, compiled by grooming onto L, and installed if `installB`."
function setupgroomed(compalg, nowtime; installB::Bool)
    ibnf = loadmultidomaintestibnfs(compalg, nowtime)[1]
    conintent = ConnectivityIntent(GlobalNode(getibnfid(ibnf), 4), GlobalNode(getibnfid(ibnf), 8), u"30.0Gbps")
    A, nowtime = addintent!(ibnf, conintent, NetworkOperator(); offsettime = nowtime)
    _, nowtime = compileintent!(ibnf, A; offsettime = nowtime)
    _, nowtime = installintent!(ibnf, A; offsettime = nowtime)
    B, nowtime = addintent!(ibnf, conintent, NetworkOperator(); offsettime = nowtime)
    _, nowtime = compileintent!(ibnf, B; offsettime = nowtime)
    installB && ((_, nowtime) = installintent!(ibnf, B; offsettime = nowtime))
    @test MINDF.logicalordergetpath(getlogicallliorder(ibnf, A)) == [4, 3, 14, 15, 20, 8]
    @test MINDF.issubdaggrooming(getidag(ibnf), B)
    @test leafllis(ibnf, B) == leafllis(ibnf, A)
    @test length(reservedllis(ibnf)) == 10
    return ibnf, A, B, nowtime
end

# install B while L is failed. installB = false is the case that used to turn A and L into Compiled while reserved.
# installB = true (B reinstalled after failing) is the reference.
for installB in (false, true)
    ibnf, A, B, nowtime = setupgroomed(compalg, nowtime; installB)
    nowtime += Dates.Hour(1)
    _, nowtime = setlinkstate!(ibnf, Edge(20, 8), false; offsettime = nowtime)
    @test st(ibnf, A) == IntentState.Failed

    nowtime += Dates.Hour(1)
    rc, nowtime = installintent!(ibnf, B; offsettime = nowtime)
    @test rc == ReturnCodes.FAIL
    @test st(ibnf, A) == IntentState.Failed
    @test st(ibnf, B) == IntentState.Failed
    @test reservedllis(ibnf) == leafllis(ibnf, A)
    @test isempty(stagedllis(ibnf))
    @test ninstalledlightpaths(ibnf) == 1
    testoxcllistateconsistency(ibnf)

    nowtime += Dates.Hour(1)
    _, nowtime = setlinkstate!(ibnf, Edge(20, 8), true; offsettime = nowtime)
    @test st(ibnf, A) == IntentState.Installed
    @test st(ibnf, B) == IntentState.Installed
    @test issatisfied(ibnf, A)
    @test issatisfied(ibnf, B)

    for (f, id) in ((uninstallintent!, B), (uninstallintent!, A), (uncompileintent!, B), (uncompileintent!, A), (removeintent!, B), (removeintent!, A))
        nowtime += Dates.Second(1)
        rc, nowtime = f(ibnf, id; offsettime = nowtime)
        @test rc == ReturnCodes.SUCCESS
    end
    nothingisallocated(ibnf)
    testzerostaged(ibnf)
    @test isempty(getidagnodes(getidag(ibnf)))
    testoxcfiberallocationconsistency(ibnf)
    @test TM.testallstatelogascendingtime(ibnf)
end

# B only compiled; (optionally) a link of L fails; A is uninstalled, uncompiled and removed.
# L stays in the DAG for B, so its leaves must go from reserved to staged and keep their spectrum blocked.
for linkfails in (false, true)
    ibnf, A, B, nowtime = setupgroomed(compalg, nowtime; installB = false)
    if linkfails
        nowtime += Dates.Hour(1)
        _, nowtime = setlinkstate!(ibnf, Edge(20, 8), false; offsettime = nowtime)
        @test st(ibnf, A) == IntentState.Failed
    end

    for f in (uninstallintent!, uncompileintent!, removeintent!)
        nowtime += Dates.Hour(1)
        rc, nowtime = f(ibnf, A; offsettime = nowtime)
        @test rc == ReturnCodes.SUCCESS
        @test st(ibnf, B) == IntentState.Compiled
        @test all(idn -> getidagnodestate(idn) == IntentState.Compiled, MINDF.getidagnodeleafs(getidag(ibnf), B))
        @test isempty(reservedllis(ibnf))
        @test stagedllis(ibnf) == leafllis(ibnf, B)
        @test length(stagedllis(ibnf)) == 10
        @test spectrumblocked(ibnf, B)
        @test ninstalledlightpaths(ibnf) == 0
        testoxcfiberallocationconsistency(ibnf)
    end
    @test length(getidagnodes(getidag(ibnf))) == 12

    if linkfails
        nowtime += Dates.Hour(1)
        _, nowtime = setlinkstate!(ibnf, Edge(20, 8), true; offsettime = nowtime)
    end
    nowtime += Dates.Hour(1)
    rc, nowtime = installintent!(ibnf, B; offsettime = nowtime)
    @test rc == ReturnCodes.SUCCESS
    @test st(ibnf, B) == IntentState.Installed
    @test reservedllis(ibnf) == leafllis(ibnf, B)
    testzerostaged(ibnf)
    @test spectrumblocked(ibnf, B)

    for f in (uninstallintent!, uncompileintent!, removeintent!)
        nowtime += Dates.Second(1)
        rc, nowtime = f(ibnf, B; offsettime = nowtime)
        @test rc == ReturnCodes.SUCCESS
    end
    nothingisallocated(ibnf)
    testzerostaged(ibnf)
    @test isempty(getidagnodes(getidag(ibnf)))
    testoxcfiberallocationconsistency(ibnf)
    testoxcllistateconsistency(ibnf)
    @test TM.testallstatelogascendingtime(ibnf)
end

end
