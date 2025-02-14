using MINDFul: getoxcview
import MINDFulMakie as MINDFM
using MINDFul, Test
using Graphs
import AttributeGraphs as AG
using JLD2, UUIDs
using Unitful, UnitfulData

const MINDF = MINDFul

using GLMakie

## single domain

# load data
domains_name_graph = first(JLD2.load("data/itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).jld2"))[2]

ag1 = first(domains_name_graph)[2]

ibnag1 = MINDF.default_IBNAttributeGraph(ag1)

ibnf1 = MINDF.IBNFramework(ibnag1)

conintent1 = MINDF.ConnectivityIntent(MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 4), MINDF.GlobalNode(MINDF.getibnfid(ibnf1), 8), u"100Gbps")
MINDF.addintent!(ibnf1, conintent1, MINDF.NetworkOperator())

# plot
# MINDFM.ibngraphplot(ibnag1; layout = x -> MINDFM.coordlayout(ibnag1), nlabels=repr.(Graphs.vertices(ibnag1)))

MINDF.compileintent!(ibnf1, UUID(1), MINDF.KShorestPathFirstFitCompilation(10))

# nothing
