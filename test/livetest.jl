using MINDFul
using JLD2, AttributeGraphs, Graphs
using UUIDs

const AG = AttributeGraphs
const MINDF = MINDFul

ag4nets = JLD2.load("./data/attributegraphs4nets.jld2")

ag1 = MINDF.default_IBNAttributeGraph(ag4nets["ags"][1])

nodeview1 = vertex_attr(ag1)[1]

dagnodeid1 = UUID(1)

transmissionmodulereservationentry1 = MINDF.TransmissionModuleReservationEntry(1, 1, 1, 1)


@show MINDF.canreserve(nodeview1, transmissionmodulereservationentry1)

MINDF.reserve!(nodeview1, dagnodeid1, transmissionmodulereservationentry1)

@show !MINDF.canreserve(nodeview1, transmissionmodulereservationentry1)

MINDF.unreserve!(nodeview1, dagnodeid1)

@show MINDF.canreserve(nodeview1, transmissionmodulereservationentry1)

MINDF.reserve!(nodeview1, dagnodeid1, transmissionmodulereservationentry1)

# @show !MINDF.canreserve(nodeview1, transmissionmodulereservationentry1)
# @code_warntype MINDF.canreserve(nodeview1, transmissionmodulereservationentry1)

# create an IBNF
ibnf1 = MINDF.IBNFramework(UUID(1), MINDF.IntentDAG(), ag1, MINDF.IBNFrameworkHandler[], MINDF.SDNdummy())

nothing
