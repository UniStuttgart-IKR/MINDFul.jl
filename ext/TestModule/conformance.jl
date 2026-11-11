# Core test suite for any intent compilation algorithm (also for algorithms implemented in other packages)

"""
$(TYPEDSIGNATURES)

A failed compilation must leave the intent as it was: Uncompiled, no descendants, nothing reserved or staged, in any domain.
This holds for intra-domain, cross-domain and border-node intents, also when retried.
"""
function testsuitefailedcompilation!(compalg::MINDF.IntentCompilationAlgorithm, nowtime = DateTime("2026-01-01"); cachedresultspath::Union{Nothing, String} = CACHEDRESULTSFILE[])
    st(ibnf, id) = getidagnodestate(getidag(ibnf), id)
    ndagnodes(ibnf) = length(getidagnodes(getidag(ibnf)))
    nchildren(ibnf, id) = length(getidagnodechildren(getidag(ibnf), id))
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
    ibnfs = loadmultidomaintestibnfs(compalg, nowtime; cachedresultspath)
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

    # the failed intent doesn't block resources for another intent
    C, nowtime = addintent!(d1, ConnectivityIntent(GlobalNode(getibnfid(d1), 4), GlobalNode(getibnfid(d3), 12), u"100.0Gbps"), NetworkOperator(); offsettime = nowtime)
    for f in (compileintent!, uncompileintent!, removeintent!)
        rc, nowtime = f(d1, C; offsettime = nowtime)
        @test rc == ReturnCodes.SUCCESS
    end

    # after the repair, A compiles, installs and tears down normally
    for ed in isolate47edges
        nowtime += Hour(1)
        _, nowtime = setlinkstate!(d3, ed, true; offsettime = nowtime)
    end
    for f in (compileintent!, installintent!)
        rc, nowtime = f(d1, A; offsettime = nowtime)
        @test rc == ReturnCodes.SUCCESS
    end
    @test st(d1, A) == IntentState.Installed
    @test issatisfied(d1, A)
    for f in (uninstallintent!, uncompileintent!, removeintent!)
        rc, nowtime = f(d1, A; offsettime = nowtime)
        @test rc == ReturnCodes.SUCCESS
    end
    testclean(ibnfs)

    # intent to a border node that fails: d1:4 -> d3:25 (border node of d1) at 5000 Gbps. Retries must not stack children.
    ibnfs = loadmultidomaintestibnfs(compalg, nowtime; cachedresultspath)
    d1, d3 = ibnfs[1], ibnfs[3]
    @test isbordernode(d1, GlobalNode(getibnfid(d3), 25))
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

    # an intra-domain intent that fails leaves nothing behind
    A, nowtime = addintent!(d1, ConnectivityIntent(GlobalNode(getibnfid(d1), 4), GlobalNode(getibnfid(d1), 8), u"5000.0Gbps"), NetworkOperator(); offsettime = nowtime)
    rc, nowtime = compileintent!(d1, A; offsettime = nowtime)
    @test !issuccess(rc)
    @test st(d1, A) == IntentState.Uncompiled
    @test nchildren(d1, A) == 0
    testclean(ibnfs; keep = 1)
    rc, nowtime = removeintent!(d1, A; offsettime = nowtime)
    @test rc == ReturnCodes.SUCCESS
    testclean(ibnfs)
    return
end

"""
$(TYPEDSIGNATURES)

The core tests that any intent compilation algorithm must pass, also one implemented in another package.
They check behaviour that doesn't depend on the algorithm's choices (paths, spectrum, ports): the intent lifecycle in a
single domain and across domains, 100 random intents, clean failed compilations, and ascending state logs.

`compalg` is a template: every test network builds its own algorithm with `typeof(compalg)(compalg, cachedresults)`.
The algorithm must
- have that constructor and support `MINDFul.getcandidatepathsnum`, like [`MINDFul.KShorestPathFirstFitCompilation`](@ref),
- implement `compileintent!` for `ConnectivityIntent`s (no `AvailabilityConstraint` is used).

`runjet` also runs the JET checks of the single-domain lifecycle.
`cachedresultspath` is the file caching the calculated paths of the test networks (default: see [`setcachedresults!`](@ref)); `nothing` calculates them.
"""
function testsuitecompilationalgorithm(compalg::MINDF.IntentCompilationAlgorithm; runjet::Bool = false, cachedresultspath::Union{Nothing, String} = CACHEDRESULTSFILE[])
    withmemory = compalg isa MINDF.IntentCompilationAlgorithmWithMemory
    @testset "MINDFul core: $(nameof(typeof(compalg)))" begin
        @testset "single-domain lifecycle" begin
            ibnf = loadsingledomaintestibnf(compalg; cachedresultspath)
            testsuitebasicintent!(ibnf, runjet)
            withmemory && @test testallstatelogascendingtime(ibnf)
        end
        @testset "multi-domain lifecycle" begin
            ibnfs = loadmultidomaintestibnfs(compalg; cachedresultspath)
            testsuitemultidomain!(ibnfs)
            withmemory && foreach(ibnf -> @test(testallstatelogascendingtime(ibnf)), ibnfs)
        end
        @testset "random intents" begin
            ibnfs = loadmultidomaintestibnfs(compalg; cachedresultspath)
            testsuiteinterface!(ibnfs)
            withmemory && foreach(ibnf -> @test(testallstatelogascendingtime(ibnf)), ibnfs)
        end
        @testset "failed compilation leaves no trace" begin
            testsuitefailedcompilation!(compalg; cachedresultspath)
        end
    end
    return
end
