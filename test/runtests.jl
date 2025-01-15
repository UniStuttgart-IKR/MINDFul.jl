using MINDFul, Test
using Graphs, AttributeGraphs
using JLD2, UUIDs

const MINDF = MINDFul

## single domain 

# load data
ag4nets = JLD2.load("./data/attributegraphs4nets.jld2")
ag1 = MINDF.default_IBNAttributeGraph(ag4nets["ags"][1])
# get the node view of a single random vertex
nodeview1 = vertex_attr(ag1)[1]
dagnodeid1 = UUID(1)

# try out transmissionmodule reservation
transmissionmodulereservationentry1 = MINDF.TransmissionModuleReservationEntry(1, 1, 1, 1)

@test MINDF.canreserve(nodeview1, transmissionmodulereservationentry1)
MINDF.reserve!(nodeview1, dagnodeid1, transmissionmodulereservationentry1)
@test !MINDF.canreserve(nodeview1, transmissionmodulereservationentry1)
# test transmission module resetvations
let
    transmodreservations = MINDF.gettransmissionmodulereservations(nodeview1)
    @test length(transmodreservations) == 1
    @test first(transmodreservations) == (dagnodeid1 => transmissionmodulereservationentry1)
end
# test router reservations
let 
    routerreservations = MINDF.getreservations(MINDF.getrouterview(nodeview1))
    @test length(routerreservations) == 1
    @test first(routerreservations) == (dagnodeid1 => 1)
end
# test oxc reservations
let
    oxcreservations = MINDF.getreservations(MINDF.getoxcview(nodeview1))
    @test length(oxcreservations) == 1
    @test first(oxcreservations) == (dagnodeid1 => MINDF.OXCSwitchEntry(0,1,0,0:0))
end

MINDF.unreserve!(nodeview1, dagnodeid1)
@test MINDF.canreserve(nodeview1, transmissionmodulereservationentry1)
# test all reservations are empty
@test isempty(MINDF.gettransmissionmodulereservations(nodeview1))
@test isempty(MINDF.getreservations(MINDF.getrouterview(nodeview1)))
@test isempty(MINDF.getreservations(MINDF.getoxcview(nodeview1)))


# try out 
