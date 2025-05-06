@testset ExtendedTestSet "multidomain_1069.jl"  begin

domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]

handlers=Vector{MINDFul.RemoteIBNFHandler}()
hdlr=Vector{MINDFul.RemoteIBNFHandler}()
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


ibnfs = [
    let
        ag = name_graph[2]
        ibnag = MINDF.default_IBNAttributeGraph(ag)
        ibnf = IBNFramework(ibnag, handlers)
    end for name_graph in domains_name_graph
]

for i in eachindex(ibnfs)
    @show ibnfs[i]
    println(" ")
end

# add ibnf handlers
for i in eachindex(ibnfs)
    port = 8080 + i
    URI = HTTP.URI(; scheme="http", host="127.0.0.1", port=string(port))
    URI_s=string(URI)
    push!(handlers, MINDF.RemoteIBNFHandler(UUID(i), URI_s))
end
@show handlers

for i in eachindex(ibnfs)
    push!(ibnfs[i].ibnfhandlers, handlers[i] )
    for j in eachindex(ibnfs)
        i == j && continue
        push!(ibnfs[i].ibnfhandlers, handlers[j] )
    end
    
    #ibnfs[i].ibnfhandlers = hdlr
end

#=try
    MINDF.start_ibn_server(ibnf1) #server1
    #Service.serve(port=port2, async=true, context=ibnf2, serialize=false, swagger=true) 
catch e
    if isa(e, Base.IOError)
        println("Server2 is already running")
    else
        rethrow(e)  
    end
end=#

for i in eachindex(ibnfs)
    @show ibnfs[i]
    println(" ")
end


@test MINDF.requestavailablecompilationalgorithms_init!(ibnfs[1], ibnfs[1].ibnfhandlers[2]) == "kspff"

end
