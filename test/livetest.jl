using Revise
using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework
using CompositeGraphs
using TestSetExtensions
using GraphMakie
using GLMakie

using Logging
testlogger = ConsoleLogger(stderr, Logging.Error)

globalnet = loadgraph(open("../data/networksnest2.graphml"), GraphMLFormat(), CompositeGraphs.CompositeGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.compositeGraph2IBNs!(globalnet)
nothing


#elem_1 = [LineElement(color = RGB(0.78,0.129,0.867), linestyle = nothing)]
#elem_2 = [LineElement(color = RGB(0.82,0.29,0.0), linestyle = nothing)]
#fi,ai,pi = IBNFramework.ibnplot(myibns[1], layout=IBNFramework.coordlayout, show_routers=true, show_links=true, curve_distance=0.3, color_paths=[[1,2,3],[2,4,8,7]])
#Legend(fi[1,1], [elem_1, elem_2], ["Intent1", "Intent2"], tellheight = false, tellwidth = false, margin=(10,10,10,10),halign = :right)
#
#Legend(f[1,1], IBNFramework.getlegendplots(p), ["Intent5","Intent3"], tellheight=false, tellwidth=false, halign=:right)
