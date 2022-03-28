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

globalnet = loadgraph(open("../data/networksnest.graphml"), GraphMLFormat(), CompositeGraphs.CompositeGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.compositeGraph2IBNs!(globalnet)

# intra SDN, intra IBN intent
conint1 = ConnectivityIntent((myibns[1].id,1), (myibns[1].id,3), [CapacityConstraint(25)]);
intidx1 = addintent(myibns[1], conint1);
IBNFramework.deploy!(myibns[1],intidx1, IBNFramework.docompile, IBNFramework.SimpleIBNModus());
IBNFramework.deploy!(myibns[1],intidx1, IBNFramework.doinstall, IBNFramework.SimpleIBNModus());

# inter SDN, intra IBN intent
conint2 = ConnectivityIntent((myibns[1].id,2), (myibns[1].id,7), [CapacityConstraint(15)]);
intidx2 = addintent(myibns[1], conint2);
IBNFramework.deploy!(myibns[1],intidx2, IBNFramework.docompile, IBNFramework.SimpleIBNModus());
IBNFramework.deploy!(myibns[1],intidx2, IBNFramework.doinstall, IBNFramework.SimpleIBNModus());

# inter SDN, inter IBN intent
conint3 = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,3), [CapacityConstraint(15)])
intidx3 = addintent(myibns[1], conint3)
IBNFramework.deploy!(myibns[1],intidx3, IBNFramework.docompile, IBNFramework.SimpleIBNModus())
IBNFramework.deploy!(myibns[1],intidx3, IBNFramework.doinstall, IBNFramework.SimpleIBNModus())

#elem_1 = [LineElement(color = RGB(0.78,0.129,0.867), linestyle = nothing)]
#elem_2 = [LineElement(color = RGB(0.82,0.29,0.0), linestyle = nothing)]
#fi,ai,pi = IBNFramework.ibnplot(myibns[1], layout=IBNFramework.coordlayout, show_routers=true, show_links=true, curve_distance=0.3, color_paths=[[1,2,3],[2,4,8,7]])
#Legend(fi[1,1], [elem_1, elem_2], ["Intent1", "Intent2"], tellheight = false, tellwidth = false, margin=(10,10,10,10),halign = :right)
