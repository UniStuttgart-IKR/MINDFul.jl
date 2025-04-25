using MINDFul
using HTTP, JSON
using Test
using JLD2, UUIDs
using Graphs
using AttributeGraphs

const MINDF = MINDFul

port1 = 8081
port2 = 8082

URI1 = HTTP.URI(; scheme="http", host="127.0.0.1", port=string(port1))
URI2 = HTTP.URI(; scheme="http", host="127.0.0.1", port=string(port2)) 

URI1_s=string(URI1)
URI2_s=string(URI2)

#@show URI1
#@show URI1_s

domains_name_graph = first(JLD2.load("../data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]

ag1 = first(domains_name_graph)[2]
ag2 = first(domains_name_graph)[2]


ibnag1 = MINDF.default_IBNAttributeGraph(ag1)
ibnag2 = MINDF.default_IBNAttributeGraph(ag2)


# Definition of RemoteIBNFHandlers for each instance
handler1 = MINDF.RemoteIBNFHandler(
    MINDF.HandlerProperties(UUIDs.uuid4(), URI1_s),
    MINDF.IBNFHTTP2Comm(URI1_s)
)

handler2 = MINDF. RemoteIBNFHandler(
    MINDF.HandlerProperties(UUIDs.uuid4(), URI2_s),
    MINDF.IBNFHTTP2Comm(URI2_s)
)

# Adding handlers to the IBNFrameworks
ibnf1 = MINDF.IBNFramework(ibnag1, [handler1, handler2])
ibnf2 = MINDF.IBNFramework(ibnag2, [handler2, handler1])

# Starting the servers in diferent ports
#server1 = MINDF.start_ibn_server(ibnf1)
#server2 = MINDF.start_ibn_server(ibnf2)

#=try
    MINDF.start_ibn_server(ibnf1) #server1
catch e
    if isa(e, Base.IOError)
        println("Server1 is already running on")
    else
        rethrow(e)  
    end
end=#

try
    MINDF.start_ibn_server(ibnf2) #server2
catch e
    if isa(e, Base.IOError)
        println("Server2 is already running")
    else
        rethrow(e)  
    end
end






#status, response = MINDF.requestibnattributegraph(ibnf2, handler1)
#@show status
#@show response == MINDF.serialize_attributegraph(MINDF.getibnag(ibnf1))



"""Requesting complilation algorithms"""
#=src_domain = ibnf1
remotehandler=src_domain.ibnfhandlers[2]
algorithms = MINDF.requestavailablecompilationalgorithms_init!(ibnf1, remotehandler)
@show algorithms=#



 """ Requesting spectrum availability """ 
src_node = MINDF.getglobalnode(ibnag1, 1) 
dst_node = MINDF.getglobalnode(ibnag2, 6) 
ge = MINDF.GlobalEdge(src_node, dst_node)
@show ge


src_domain = ibnf1
remotehandler=src_domain.ibnfhandlers[2]


response = MINDF.requestspectrumavailability_init!(ibnf1, remotehandler, ge)

#@show response

#edge_exists = haskey(MINDF.getlinkspectrumavailabilities(MINDF.getoxcview(MINDF.getnodeview(ibnag1, 1))), Edge(1, 6))
#@show edge_exists
#if edge_exists
    #response = MINDF.requestspectrumavailability_init!(src_domain, dst_domain, ge)
    #@show response
#else
#    println("Edge does not exist in the graph.")
#end

