@testset ExtendedTestSet "multidomain_1069.jl"  begin

domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]

hdlr=Vector{MINDFul.RemoteIBNFHandler}()

ibnfs = [
    let
        ag = name_graph[2]
        ibnag = MINDF.default_IBNAttributeGraph(ag)
        ibnf = IBNFramework(ibnag, Vector{MINDFul.RemoteIBNFHandler}())
    end for name_graph in domains_name_graph
]

for i in eachindex(ibnfs)
    port = 8080 + i
    URI = HTTP.URI(; scheme="http", host="127.0.0.1", port=string(port))
    URI_s=string(URI)
    push!(hdlr, MINDF.RemoteIBNFHandler(UUID(i), URI_s))
end

for i in eachindex(ibnfs)
    push!(getibnfhandlers(ibnfs[i]), hdlr[i])
    for j in eachindex(ibnfs)
        i == j && continue
        push!(getibnfhandlers(ibnfs[i]), hdlr[j])
    end
end

MINDF.start_ibn_server(ibnfs)

# with border node
conintent_bordernode = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 25), u"100.0Gbps")
intentuuid_bordernode = addintent!(ibnfs[1], conintent_bordernode, NetworkOperator())

# compile
@test compileintent!(ibnfs[1], intentuuid_bordernode, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
TM.testcompilation(ibnfs[1], intentuuid_bordernode; withremote=true)
 
# install
@test installintent!(ibnfs[1], intentuuid_bordernode; verbose=true) == ReturnCodes.SUCCESS
TM.testinstallation(ibnfs[1], intentuuid_bordernode; withremote=true)
#=
# uninstall
@test uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose=true) == ReturnCodes.SUCCESS
TM.testuninstallation(ibnfs[1], intentuuid_bordernode; withremote=true)

# uncompile
@test uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose=true) == ReturnCodes.SUCCESS
TM.testuncompilation(ibnfs[1], intentuuid_bordernode)
@test nv(getidag(ibnfs[1])) == 1
@test nv(getidag(ibnfs[3])) == 0

# to neighboring domain
conintent_neigh = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 47), u"100.0Gbps")
intentuuid_neigh = addintent!(ibnfs[1], conintent_neigh, NetworkOperator())

@test compileintent!(ibnfs[1], intentuuid_neigh, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
TM.testcompilation(ibnfs[1], intentuuid_neigh; withremote=true)

@test installintent!(ibnfs[1], intentuuid_neigh; verbose=true) == ReturnCodes.SUCCESS
TM.testinstallation(ibnfs[1], intentuuid_neigh; withremote=true)

@test uninstallintent!(ibnfs[1], intentuuid_neigh; verbose=true) == ReturnCodes.SUCCESS
TM.testuninstallation(ibnfs[1], intentuuid_neigh; withremote=true)

@test uncompileintent!(ibnfs[1], intentuuid_neigh; verbose=true) == ReturnCodes.SUCCESS
TM.testuncompilation(ibnfs[1], intentuuid_neigh)
@test nv(getidag(ibnfs[1])) == 2
@test nv(getidag(ibnfs[3])) == 0
# to unknown domain
 
foreach(ibnfs) do ibnf
    #TM.testoxcfiberallocationconsistency(ibnf)
    TM.testzerostaged(ibnf)
end
=#

end
