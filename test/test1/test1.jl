using MINDFul
using HTTP, JSON
using Test
using JLD2, UUIDs
using Graphs
using AttributeGraphs

const MINDF = MINDFul

const port1 = 8081
const port2 = 8082

const URI1 = HTTP.URI(; scheme="http", host="127.0.0.1", port=string(port1))
const URI2 = HTTP.URI(; scheme="http", host="127.0.0.1", port=string(port2)) 

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
ibnf1 = MINDF.IBNFramework(ibnag1, [handler2])
ibnf2 = MINDF.IBNFramework(ibnag2, [handler1])

# Starting the servers in diferent ports
server1 = MINDF.start_ibn_server(ibnf1, port1)
server2 = MINDF.start_ibn_server(ibnf2, port2)



# Test requesting topology information
# @testset "Interdomain Topology Request" begin
    # Request topology information from ibnf2 to ibnf1
   # status, response = requestibnattributegraph(ibnf2, handler1)
    
    #@test status == 200
   # @test response == serialize_attributegraph(getibnag(ibnf1))  # Verify the response matches ibnf1's topology
#end

#status, response = MINDF.requestibnattributegraph(ibnf2, handler1)
#@show status
#@show response == MINDF.serialize_attributegraph(MINDF.getibnag(ibnf1))



src_node = MINDF.getglobalnode(ibnag1, 1) 
dst_node = MINDF.getglobalnode(ibnag2, 1) 
ge = MINDF.GlobalEdge(src_node, dst_node)

#globaledge = GlobalEdge(getglobalnode(ibnag, src(edge)), getglobalnode(ibnag, dst(edge)))

response = MINDF.requestspectrumavailability(ibnf1,handler2,ge)
@show response

close(server1)
println("Server 1 closed")
close(server2)
println("Server 2 closed")
