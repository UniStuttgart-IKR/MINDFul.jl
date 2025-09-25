@testset ExtendedTestSet "singledomain-splitavail.jl"  begin
nt = starttime = DateTime("2026-01-01")
compalg = MINDF.BestEmpiricalAvailabilityCompilation(5, 5; nodenum=1)

ibnfs = loadmultidomaintestibnfs(compalg, starttime;  useshortreachtransmissionmodules=true)

avcon1 = MINDF.AvailabilityConstraint(0.94, 0.9) 
conintent1 = ConnectivityIntent(GlobalNode(getibnfid(ibnfs[3]), 21), GlobalNode(getibnfid(ibnfs[3]), 51), u"5.0Gbps", [avcon1])
intentuuid1, nt = addintent!(ibnfs[3], conintent1, NetworkOperator())

rc, nt = compileintent!(ibnfs[3], intentuuid1; offsettime = nt, verbose=false)
@test rc == ReturnCodes.SUCCESS

idnchildren = getidagnodechildren(getidag(ibnfs[3]), intentuuid1)
@test length(idnchildren) == 2
@test all(x -> getintent(x) isa ConnectivityIntent, idnchildren)
getavcon1 = getfirst(x -> x isa AvailabilityConstraint, getconstraints(getintent(idnchildren[1])))
getavcon2 = getfirst(x -> x isa AvailabilityConstraint, getconstraints(getintent(idnchildren[2])))

@test MINDF.getavailabilityrequirement(getavcon1) * MINDF.getavailabilityrequirement(getavcon2) <= MINDF.getavailabilityrequirement(avcon1)
@test MINDF.getcompliancetarget(getavcon1) * MINDF.getcompliancetarget(getavcon2) <= MINDF.getcompliancetarget(avcon1)

rc, nt = installintent!(ibnfs[3], intentuuid1; offsettime = nt, verbose=false)
@test rc == ReturnCodes.SUCCESS
end
