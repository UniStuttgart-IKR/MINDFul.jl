#@testset ExtendedTestSet "multidomain_1069.jl"  begin

domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]

handlers=Vector{MINDFul.AbstractIBNFHandler}()
hdlr=Vector{MINDFul.AbstractIBNFHandler}()
ibnfs=Vector{MINDFul.IBNFramework}()


ibnfs = [
    let
        ag = name_graph[2]
        ibnag = MINDF.default_IBNAttributeGraph(ag)
        ibnf = IBNFramework(ibnag, handlers)
    end for name_graph in domains_name_graph
]

#=for i in eachindex(ibnfs_temp)
    @show ibnfs_temp[i].ibnfhandlers
    println(" ")
end=#
#@show eachindex(ibnfs_temp)

for i in eachindex(ibnfs)
    port = 8080 + i
    URI = HTTP.URI(; scheme="http", host="127.0.0.1", port=string(port))
    URI_s=string(URI)
    push!(hdlr, MINDF.RemoteIBNFHandler(UUID(i), URI_s))
end
@show hdlr

#=for i in eachindex(ibnfs_temp)
    @show hdlr[i]
    println(" ")
end=#

for i in eachindex(ibnfs)
    
    push!(getibnfhandlers(ibnfs[i]), hdlr[i])
    
    println(" ")
    #@show ibnfs[i].ibnfhandlers

    #=for j in eachindex(ibnfs)
        i == j && continue
        #if !(hdlr[j] in ibnfs[i].ibnfhandlers)
            push!(getibnfhandlers(ibnfs[i]), hdlr[j])
        #end
        
    end=#
end



for i in eachindex(ibnfs)
    println(" ")
    @show ibnfs[i].ibnfhandlers
end

#=ibnfs_dict = Dict{Int, IBNFramework}()
for ibnf in ibnfs 
    sel_handler = ibnf.ibnfhandlers[1]
    base_url = sel_handler.base_url
    uri = HTTP.URI(base_url)
    port = parse(Int, uri.port)
    push!(ibnfs_dict, port => ibnf)
end
@show ibnfs_dict=#

#MINDF.start_ibn_servers(ibnfs, ibnfs_dict)





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

#= Compiling a connectivity intent
gnode1=GlobalNode(UUID(1), 4)
gnode2=GlobalNode(UUID(3), 25)
conintent_bordernode = ConnectivityIntent(gnode1, gnode2, u"100.0Gbps")
intentuuid_bordernode = addintent!(ibnfs[1], conintent_bordernode, NetworkOperator())
@show intentuuid_bordernode
respon = compileintent!(ibnfs[1], intentuuid_bordernode, KShorestPathFirstFitCompilation(10))
@show respon 
#@test compileintent!(ibnfs[1], intentuuid_bordernode, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS=#







#end
