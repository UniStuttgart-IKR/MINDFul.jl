using MINDFul: getoxcview
using MINDFul, Test
using Graphs 
import AttributeGraphs as AG
using JLD2, UUIDs

const MINDF = MINDFul

## single domain 

# load data
domains_name_graph = first(JLD2.load("data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]

ag1 = first(domains_name_graph)[2]

ibnag1 = MINDF.default_IBNAttributeGraph(ag1)

# get the node view of a single random vertex
nodeview1 = AG.vertex_attr(ibnag1)[1]
routerview1 = MINDF.getrouterview(nodeview1)
oxcview1 = MINDF.getoxcview(nodeview1)
dagnodeid1 = UUID(1)

rplli1 = MINDF.RouterPortLLI(1, 2)
tmlli1 = MINDF.TransmissionModuleLLI(1, 1, 1);
oxclli1 = MINDF.OXCAddDropBypassSpectrumLLI(1, 2, 0, 4, 2:4)
for (reservableresource, lli) in zip([nodeview1, routerview1, oxcview1], [tmlli1, rplli1, oxclli1] )
    @test MINDF.canreserve(reservableresource, lli)
    @test MINDF.reserve!(reservableresource, lli, dagnodeid1; verbose=true)
    @test !MINDF.canreserve(reservableresource, lli)
    let 
        reservations = MINDF.getreservations(reservableresource)
        @test length(reservations) == 1
        @test first(reservations) == (dagnodeid1 => lli)
    end
    @test MINDF.unreserve!(reservableresource, dagnodeid1)
    @test MINDF.canreserve(reservableresource, lli)
    @test length(MINDF.getreservations(reservableresource)) == 0
end

@test MINDF.reserve!(oxcview1, oxclli1, dagnodeid1; checkfirst=true)
@test !MINDF.reserve!(oxcview1, MINDF.OXCAddDropBypassSpectrumLLI(1, 2, 0, 4, 5:6), dagnodeid1; checkfirst=true)
@test MINDF.reserve!(oxcview1, MINDF.OXCAddDropBypassSpectrumLLI(1, 2, 0, 4, 5:6), UUID(2); checkfirst=true)

# now test the intent workflow
# reinitialize domain

nothing
