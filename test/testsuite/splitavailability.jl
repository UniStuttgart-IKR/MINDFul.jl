@testset ExtendedTestSet "splitavailability.jl"  begin

# When an intent with an AvailabilityConstraint is split in two halves, both halves must hold for the intent to hold:
# the compliance targets of the halves must compose to at least the master's (ct1 * ct2 >= ct), and so must the
# availability requirements (r1 * r2 >= r). Checked for the 3 ways a split happens.

avcon = MINDF.AvailabilityConstraint(0.94, 0.9)
getavcon(intent) = getfirst(x -> x isa AvailabilityConstraint, getconstraints(intent))
"the AvailabilityConstraints of the two halves (ConnectivityIntent children) of intent `id`"
halves(ibnf, id) = [getavcon(getintent(c)) for c in getidagnodechildren(getidag(ibnf), id) if getintent(c) isa ConnectivityIntent]
# a product of two sqrt(x) can be one ulp below x
atleast(x, y) = x >= y || x ≈ y

# `checkrequirement`: the planner of BestEmpiricalAvailabilityCompilation sets the first half's requirement from its
# estimate, so the requirements compose too. The generic planner (point estimates, e.g. BestAverageEmpiricalAvailabilityCompilation)
# always gives the first half sqrt(r), while the second half is revised from the first half's estimate.
function testsplit(ibnfs, srcdomain, srcnode, dstdomain, dstnode, nowtime; checkrequirement = true)
    ibnf = ibnfs[srcdomain]
    A, nowtime = addintent!(ibnf, ConnectivityIntent(GlobalNode(getibnfid(ibnf), srcnode), GlobalNode(getibnfid(ibnfs[dstdomain]), dstnode), u"5.0Gbps", [avcon]), NetworkOperator(); offsettime = nowtime)
    rc, nowtime = compileintent!(ibnf, A; offsettime = nowtime)
    @test rc == ReturnCodes.SUCCESS
    acs = halves(ibnf, A)
    @test length(acs) == 2
    @test all(!isnothing, acs)
    @test atleast(prod(MINDF.getcompliancetarget, acs), MINDF.getcompliancetarget(avcon))
    checkrequirement && @test atleast(prod(MINDF.getavailabilityrequirement, acs), MINDF.getavailabilityrequirement(avcon))
    rc, nowtime = installintent!(ibnf, A; offsettime = nowtime)
    @test rc == ReturnCodes.SUCCESS
    for f in (uninstallintent!, uncompileintent!, removeintent!)
        rc, nowtime = f(ibnf, A; offsettime = nowtime)
        @test rc == ReturnCodes.SUCCESS
    end
    return nowtime
end

for compalg in (MINDF.BestEmpiricalAvailabilityCompilation(10, 5; nodenum = 1), MINDF.BestAverageEmpiricalAvailabilityCompilation(10, 5; nodenum = 1))
    checkrequirement = compalg isa MINDF.BestEmpiricalAvailabilityCompilation
    # intra-domain split: too long for one lightpath with short-reach transmission modules
    nowtime = DateTime("2026-01-01")
    ibnfs = loadmultidomaintestibnfs(compalg, nowtime; useshortreachtransmissionmodules = true)
    nowtime = testsplit(ibnfs, 3, 21, 3, 51, nowtime; checkrequirement)

    # cross-domain split at a chosen border node
    nowtime = DateTime("2026-01-01")
    ibnfs = loadmultidomaintestibnfs(compalg, nowtime)
    nowtime = testsplit(ibnfs, 1, 4, 3, 12, nowtime; checkrequirement)

    # destination is a border node of the source domain
    @test MINDF.isbordernode(ibnfs[1], GlobalNode(getibnfid(ibnfs[3]), 25))
    nowtime = testsplit(ibnfs, 1, 4, 3, 25, nowtime; checkrequirement)

    foreach(nothingisallocated, ibnfs)
end

end
