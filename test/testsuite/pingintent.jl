# @testset ExtendedTestSet "pingintent.jl"  begin


nowtime = starttime = DateTime("2026-01-01")

compalg = MINDF.BestEmpiricalAvailabilityCompilation(5, 5; nodenum=1)
ibnfs = loadmultidomaintestibnfs(compalg, nowtime)

avcon1 = MINDF.AvailabilityConstraint(0.999, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[1]), 8), u"5.0Gbps", [avcon1])
intentuuid1, _ = addintent!(ibnfs[1], conintent1, NetworkOperator(); offsettime = nowtime)

_, nowtime = compileintent!(ibnfs[1], intentuuid1; offsettime = nowtime)
_, nowtime = installintent!(ibnfs[1], intentuuid1; offsettime = nowtime)

MINDF.pingdistanceconnectivityintent(ibnfs[1], intentuuid1)

conintent2 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[1]), 4), GlobalNode(getibnfid(ibnfs[2]), 8), u"5.0Gbps", [avcon1])
intentuuid2, _ = addintent!(ibnfs[1], conintent2, NetworkOperator(); offsettime = nowtime)

_, nowtime = compileintent!(ibnfs[1], intentuuid2; offsettime = nowtime)
_, nowtime = installintent!(ibnfs[1], intentuuid2; offsettime = nowtime)

MINDF.pingdistanceconnectivityintent(ibnfs[1], intentuuid2)

# end

nothing
