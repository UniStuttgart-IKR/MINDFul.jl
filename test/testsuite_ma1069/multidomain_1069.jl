@testset ExtendedTestSet "multidomain_1069.jl"  begin

domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]

handlers=Vector{MINDFul.RemoteIBNFHandler}()
hdlr=Vector{MINDFul.RemoteIBNFHandler}()
ibnfs=Vector{MINDFul.IBNFramework}()
#=counter = 0
for name_graph in domains_name_graph
    counter = counter + 1
    port = 8080 + c
    URI = HTTP.URI(; scheme="http", host="127.0.0.1", port=string(port))
    URI_s=string(URI)
    handlers[counter]=MINDF.RemoteIBNFHandler(UUID(j),URI_s)
end 


# add ibnf handlers
c=1
for name_graph in domains_name_graph
    ag = name_graph[2]
    ibnag = MINDF.default_IBNAttributeGraph(ag)
    
    for j in counter
        c == j && continue
        
        
    end
    ibnfs[c]=IBNFramework(ibnag, handlers)
    c=c+1
end
=#


ibnfs_temp = [
    let
        ag = name_graph[2]
        ibnag = MINDF.default_IBNAttributeGraph(ag)
        ibnf_temp = IBNFramework(ibnag, handlers)
    end for name_graph in domains_name_graph
]

#=for i in eachindex(ibnfs_temp)
    @show ibnfs_temp[i].ibnfhandlers
    println(" ")
end=#
#@show eachindex(ibnfs_temp)



# add ibnf handlers
for i in eachindex(ibnfs_temp)
    port = 8080 + i
    URI = HTTP.URI(; scheme="http", host="127.0.0.1", port=string(port))
    URI_s=string(URI)
    push!(hdlr, MINDF.RemoteIBNFHandler(UUID(i), URI_s))
end

#=for i in eachindex(ibnfs_temp)
    @show hdlr[i]
    println(" ")
end=#

for i in eachindex(ibnfs_temp)
    temp = Vector{MINDFul.AbstractIBNFHandler}()
    push!(temp, hdlr[i])
    
    println(" ")
    for j in eachindex(ibnfs_temp)
        i == j && continue
        #if !(hdlr[j] in ibnfs[i].ibnfhandlers)
        push!(temp, hdlr[j])
        #end
        
    end
    #@show temp
    ibnf = IBNFramework(ibnfs_temp[i].ibnag, temp)
    push!(ibnfs,ibnf)    
end



#=for i in eachindex(ibnfs)
    println(" ")
    @show ibnfs[i].ibnfhandlers
end=#

ibnfs_dict = Dict{Int, IBNFramework}()
for ibnf in ibnfs 
    sel_handler = ibnf.ibnfhandlers[1]
    base_url = sel_handler.base_url
    uri = HTTP.URI(base_url)
    port = parse(Int, uri.port)
    push!(ibnfs_dict, port => ibnf)
end
#@show ibnfs_dict

MINDF.start_ibn_servers(ibnfs, ibnfs_dict)





# Requesting complilation algorithms
#@test MINDF.requestavailablecompilationalgorithms_init!(ibnfs[1], ibnfs[1].ibnfhandlers[2]) == ["kspff"]


# Requesting spectrum availability 
#= src_node = MINDF.getglobalnode(ibnfs[1].ibnag, 1) 
dst_node = MINDF.getglobalnode(ibnfs[1].ibnag, 6) 
ge = MINDF.GlobalEdge(src_node, dst_node)

src_domain = ibnfs[1]
remotehandler=src_domain.ibnfhandlers[2]

@test MINDF.requestspectrumavailability_init!(src_domain, remotehandler, ge) == ReturnCodes.SUCCESS
=#

# Compiling a connectivity intent
#=gnode1=GlobalNode(UUID(1), 4)
gnode2=GlobalNode(UUID(3), 25)
conintent_bordernode = ConnectivityIntent(gnode1, gnode2, u"100.0Gbps")
intentuuid_bordernode = addintent!(ibnfs[1], conintent_bordernode, NetworkOperator())
#@show intentuuid_bordernode
COMPILE = compileintent!(ibnfs[1], intentuuid_bordernode, KShorestPathFirstFitCompilation(10))
@show COMPILE 
TM.testcompilation(ibnfs[1], intentuuid_bordernode; withremote=true)
#@show getidagnodestate(getidag(ibnfs[1]), intentuuid_bordernode)=#

# INSTALL
#=INSTALL = installintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
@show INSTALL
TM.testinstallation(ibnfs[1], intentuuid_bordernode; withremote=true)=#

# UNINSTALL
#=UNINSTALL = uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
@show UNINSTALL
TM.testuninstallation(ibnfs[1], intentuuid_bordernode; withremote=true)=#


# UNCOMPILE
#=UNCOMPILE = uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose=true) 
@show UNCOMPILE
TM.testuncompilation(ibnfs[1], intentuuid_bordernode)
@show nv(getidag(ibnfs[1]))
@show nv(getidag(ibnfs[3]))=#






conintent_bordernode = ConnectivityIntent(GlobalNode(UUID(1), 4), GlobalNode(UUID(3), 25), u"100.0Gbps")
intentuuid_bordernode = addintent!(ibnfs[1], conintent_bordernode, NetworkOperator())

@test compileintent!(ibnfs[1], intentuuid_bordernode, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
TM.testcompilation(ibnfs[1], intentuuid_bordernode; withremote=true)
 
# install
@test installintent!(ibnfs[1], intentuuid_bordernode; verbose=true) == ReturnCodes.SUCCESS
TM.testinstallation(ibnfs[1], intentuuid_bordernode; withremote=true)

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


end
