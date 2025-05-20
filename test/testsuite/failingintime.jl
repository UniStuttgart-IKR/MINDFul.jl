@testset ExtendedTestSet "failingtime.jl"  begin

domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]


ibnfs = [
    let
        ag = name_graph[2]
        ibnag = MINDF.default_IBNAttributeGraph(ag)
        ibnf = IBNFramework(ibnag)
    end for name_graph in domains_name_graph
]


# add ibnf handlers
for i in eachindex(ibnfs)
    for j in eachindex(ibnfs)
        i == j && continue
        push!(getibnfhandlers(ibnfs[i]), ibnfs[j] )
    end
end


internaledge = Edge(3,4)
getlinkstates(getoxcview(getnodeview(ibnfs[1], src(internaledge))))[internaledge]

offsettime = now()
entrytime = now()

conintent_internal = ConnectivityIntent(GlobalNode(UUID(1), 14), GlobalNode(UUID(1), 1), u"100.0Gbps")
intentuuid_internal_fail = addintent!(ibnfs[1], conintent_internal, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid_internal_fail, KShorestPathFirstFitCompilation(10); @passtime) == ReturnCodes.SUCCESS
@test installintent!(ibnfs[1], intentuuid_internal_fail; verbose=true, @passtime) == ReturnCodes.SUCCESS
let 
    logord = getlogicallliorder(ibnfs[1], intentuuid_internal_fail, onlyinstalled=false)
    @test internaledge ∈ edgeify(logicalordergetpath(logord))
end

offsettime += Hour(1)
@test setlinkstate!(ibnfs[1], internaledge, false; @passtime) == ReturnCodes.SUCCESS
# should make first intent fail
@test getidagnodestate(getidag(ibnfs[1]), intentuuid_internal_fail) == IntentState.Failed
TM.testexpectedfaileddag(ibnfs[1], intentuuid_internal_fail, internaledge, 2)

# second intent should avoud using the failed link
intentuuid_internal = addintent!(ibnfs[1], conintent_internal, NetworkOperator())

@test compileintent!(ibnfs[1], intentuuid_internal, KShorestPathFirstFitCompilation(10); @passtime) == ReturnCodes.SUCCESS

let 
    logord = getlogicallliorder(ibnfs[1], intentuuid_internal, onlyinstalled=false)
    @test internaledge ∉ edgeify(logicalordergetpath(logord))
end

@test installintent!(ibnfs[1], intentuuid_internal; verbose=true, @passtime) == ReturnCodes.SUCCESS
@test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_internal)])

# should make the intent installed again
offsettime += Hour(1)
@test setlinkstate!(ibnfs[1], internaledge, true; @passtime) == ReturnCodes.SUCCESS
@test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_internal_fail)])

internaledgelinkstates = getlinkstates(ibnfs[1], internaledge)
@test all(getindex.(internaledgelinkstates[2:end], 1) .- getindex.(internaledgelinkstates[1:end-1], 1) .>= Hour(1))
intentuuid_internal_fail_timelog =  getindex.(MINDF.getlogstate(MINDF.getidagnode(getidag(ibnfs[1]), intentuuid_internal_fail)), 1)
@test length(intentuuid_internal_fail_timelog) == 6
@test intentuuid_internal_fail_timelog[end] - intentuuid_internal_fail_timelog[1] >= Hour(2) 


# Border link is failing
# 29 is border node
offsettime = now()
entrytime = now()
borderedge = Edge(17,29)
foreach(ibnfs) do ibnf
    @test all([MINDF.getcurrentlinkstate(ibnf, ed) for ed in edges(getibnag(ibnf))])
end

conintent_border = ConnectivityIntent(GlobalNode(UUID(1), 18), GlobalNode(UUID(3), 23), u"100.0Gbps")
intentuuid_border_fail = addintent!(ibnfs[1], conintent_border, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid_border_fail, KShorestPathFirstFitCompilation(10); @passtime) == ReturnCodes.SUCCESS
remoteibnfid_border, remoteintentid_border = TM.getfirstremoteintent(ibnfs[1], intentuuid_border_fail)
remoteibnf_border = getibnfhandler(ibnfs[1], remoteibnfid_border)

@test installintent!(ibnfs[1], intentuuid_border_fail; verbose=true, @passtime) == ReturnCodes.SUCCESS

offsettime += Hour(1)
@test setlinkstate!(ibnfs[1], borderedge, false; @passtime) == ReturnCodes.SUCCESS
# should make first intent fail
@test getidagnodestate(getidag(ibnfs[1]), intentuuid_border_fail) == IntentState.Failed
TM.testexpectedfaileddag(ibnfs[1], intentuuid_border_fail, borderedge, 1)
TM.testexpectedfaileddag(remoteibnf_border, remoteintentid_border, Edge(58,25), 1)

intentuuid_border = addintent!(ibnfs[1], conintent_border, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid_border, KShorestPathFirstFitCompilation(10); @passtime) == ReturnCodes.SUCCESS
let 
    logord = getlogicallliorder(ibnfs[1], intentuuid_border, onlyinstalled=false)
    @test borderedge ∉ edgeify(logicalordergetpath(logord))
end
@test installintent!(ibnfs[1], intentuuid_border; verbose=true, @passtime) == ReturnCodes.SUCCESS
@test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_border)])


# should make the intent installed again
offsettime += Hour(1)
@test setlinkstate!(ibnfs[1], borderedge, true; @passtime) == ReturnCodes.SUCCESS
@test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_border_fail)])
@test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(remoteibnf_border), remoteintentid_border)])

borderedgelinkstates = getlinkstates(ibnfs[1], borderedge; checkfirst=true)
@test all(getindex.(borderedgelinkstates[2:end], 1) .- getindex.(borderedgelinkstates[1:end-1], 1) .>= Hour(1))
intentuuid_border_fail_timelog =  getindex.(MINDF.getlogstate(MINDF.getidagnode(getidag(ibnfs[1]), intentuuid_border_fail)), 1)
@test length(intentuuid_border_fail_timelog) == 8
@test intentuuid_border_fail_timelog[end] - intentuuid_border_fail_timelog[1] >= Hour(2) 
intentuuid_border_fail_timelog_remote =  getindex.(MINDF.getlogstate(MINDF.getidagnode(getidag(remoteibnf_border), remoteintentid_border)), 1)
@test length(intentuuid_border_fail_timelog_remote) == 6
@test intentuuid_border_fail_timelog_remote[end] - intentuuid_border_fail_timelog_remote[1] >= Hour(2) 

# uninstall, remove all
@test uninstallintent!(ibnfs[1], intentuuid_border_fail; verbose=true) == ReturnCodes.SUCCESS
TM.testuninstallation(ibnfs[1], intentuuid_border_fail; withremote=true)
@test uninstallintent!(ibnfs[1], intentuuid_border; verbose=true) == ReturnCodes.SUCCESS
TM.testuninstallation(ibnfs[1], intentuuid_border; withremote=true)

@test uncompileintent!(ibnfs[1], intentuuid_border_fail; verbose=true) == ReturnCodes.SUCCESS
TM.testuncompilation(ibnfs[1], intentuuid_border_fail)
@test uncompileintent!(ibnfs[1], intentuuid_border; verbose=true) == ReturnCodes.SUCCESS
TM.testuncompilation(ibnfs[1], intentuuid_border)

# External link is failing (ibnfs[3])
externaledge = Edge(23, 15)
conintent_external = ConnectivityIntent(GlobalNode(UUID(1), 14), GlobalNode(UUID(3), 12), u"100.0Gbps")
intentuuid_external_fail = addintent!(ibnfs[1], conintent_external, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid_external_fail, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
remoteibnfid_external_fail, remoteintentid_external_fail = TM.getfirstremoteintent(ibnfs[1], intentuuid_external_fail)
remoteibnf_external_fail = getibnfhandler(ibnfs[1], remoteibnfid_external_fail)
@test installintent!(ibnfs[1], intentuuid_external_fail; verbose=true) == ReturnCodes.SUCCESS

@test setlinkstate!(ibnfs[3], externaledge, false) == ReturnCodes.SUCCESS
TM.testexpectedfaileddag(remoteibnf_external_fail, remoteintentid_external_fail, externaledge, 2)
@test getidagnodestate(getidag(ibnfs[1]), intentuuid_external_fail) == IntentState.Failed
@test count(x -> getidagnodestate(x) == IntentState.Failed, getidagnodes(getidag(ibnfs[1]))) == 3

intentuuid_external = addintent!(ibnfs[1], conintent_external, NetworkOperator())
@test compileintent!(ibnfs[1], intentuuid_external, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
remoteibnfid_external, remoteintentid_external = TM.getfirstremoteintent(ibnfs[1], intentuuid_external)
remoteibnf_external = getibnfhandler(ibnfs[1], remoteibnfid_external)
@test installintent!(ibnfs[1], intentuuid_external; verbose=true) == ReturnCodes.SUCCESS
@test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(ibnfs[1]), intentuuid_external)])
@test all([MINDF.getidagnodestate(idagnode) == IntentState.Installed for idagnode in MINDF.getidagnodedescendants(getidag(remoteibnf_external), remoteintentid_external)])
let 
    logord = getlogicallliorder(remoteibnf_external, remoteintentid_external, onlyinstalled=false)
    @test externaledge ∉ edgeify(logicalordergetpath(logord))
end

# uninstall, remove all
@test uninstallintent!(ibnfs[1], intentuuid_external_fail; verbose=true) == ReturnCodes.SUCCESS
TM.testuninstallation(ibnfs[1], intentuuid_external_fail; withremote=true)
@test uninstallintent!(ibnfs[1], intentuuid_external; verbose=true) == ReturnCodes.SUCCESS
TM.testuninstallation(ibnfs[1], intentuuid_external; withremote=true)

@test uncompileintent!(ibnfs[1], intentuuid_external_fail; verbose=true) == ReturnCodes.SUCCESS
TM.testuncompilation(ibnfs[1], intentuuid_external_fail)
@test uncompileintent!(ibnfs[1], intentuuid_external; verbose=true) == ReturnCodes.SUCCESS
TM.testuncompilation(ibnfs[1], intentuuid_external)

# test bordernodes have the same logs

# get all link states, set them, and reget
for ibnf in ibnfs
    ibnag = getibnag(ibnf)
    for ed in edges(ibnag)
        ls1 = getcurrentlinkstate(ibnf, ed)
        setlinkstate!(ibnf, ed, !ls1)
        ls2 = getcurrentlinkstate(ibnf, ed)
        @test ls1 !== ls2
    end
end

for ibnf in ibnfs
    TM.testedgeoxclogs(ibnf)
    TM.testoxcllistateconsistency(ibnf)
end

nothing
end
