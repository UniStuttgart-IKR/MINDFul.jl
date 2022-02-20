using Revise, Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using IBNFramework
using CompositeGraphs
using GraphMakieUtils
using GLMakie

gr1 = complete_graph(3) |> MetaDiGraph
gr2 = complete_graph(3) |> MetaDiGraph
randomsimgraph!(gr1)
randomsimgraph!(gr2)

cg1 = cycle_graph(4) |> MetaDiGraph
cg2 = cycle_graph(5) |> MetaDiGraph
randomsimgraph!(cg1)
randomsimgraph!(cg2)

#f, ax, g = draw_network(gr1; graphplot_opts()...)

sdnd11 = SDNdummy(gr1)
sdnd12 = SDNdummy(gr2)

sdnd21 = SDNdummy(cg1)
sdnd22 = SDNdummy(cg2)

ee1 = [CompositeEdge((1,1),(2,1))]
ee2 = [CompositeEdge((1,3),(2,5)), CompositeEdge((1,2), (2,2))]
netcounter = Counter()
ibn1 = IBNFramework.IBN!(netcounter,[sdnd11, sdnd12], ee1)
#ibn1 = IBNFramework.IBN!(netcounter,Vector{Union{SDNdummy, IBN}}([sdnd11, sdnd12]), ee1)
ibn2 = IBNFramework.IBN!(netcounter,[sdnd21, sdnd22], ee2)

conint1 = ConnectivityIntent((ibn1.id,3), (ibn1.id,5), [CapacityConstraint(15)])
intidx1 = addintent(ibn1, conint1)
s = IBNFramework.step!(ibn1,intidx1, IBNFramework.InstallIntent(), IBNFramework.SimpleIBNModus())

@test IBNFramework.state(ibn1.intents[1]) == IBNFramework.InstalledIntent()
@test IBNFramework.compilation(ibn1.intents[1]) isa IBNFramework.ConnectivityIntentCompilation


conint2 = ConnectivityIntent((ibn2.id,1), (ibn2.id,8), [CapacityConstraint(50)])
intidx2 = addintent(ibn2, conint2)
s = IBNFramework.step!(ibn2,intidx2, IBNFramework.InstallIntent(), IBNFramework.SimpleIBNModus())

cg = CompositeGraph([ibn1.cgr, ibn2.cgr], [CompositeEdge((1,2),(2,8)), CompositeEdge(1,4,2,7)])

@test [Edge(cg.vmap[e.src][2],cg.vmap[e.dst][2] ) for e in edges(cg) if cg.vmap[e.src][1] == 1 && cg.vmap[e.dst][1] == 1] == collect(edges(cg.grv[1]))
@test [Edge(cg.vmap[e.src][2],cg.vmap[e.dst][2] ) for e in edges(cg) if cg.vmap[e.src][1] == 2 && cg.vmap[e.dst][1] == 2] == collect(edges(cg.grv[2]))
# Draw network recipes
#
 "draw network w/ resources"
function draw_ibn(ibn::IBN)
    f=draw_network(ibn.cgr.flatgr, 
            nlabels = [string(v, ",", get_prop(ibn.cgr, v, :router).rezports, "/",get_prop(ibn.cgr, v, :router).nports) for v in vertices(ibn.cgr)], 
            elabels = [string(get_prop(ibn.cgr, l, :link).rezcapacity,"/",get_prop(ibn.cgr, l, :link).capacity) for l in edges(ibn.cgr)])
    f[1]
end

"draw network intent with resources"
function draw_ibn(ibn::IBN, paths::Vector{Vector{Int}})
    f=draw_network(ibn.cgr.flatgr, 
            nlabels = [string(v, ",", get_prop(ibn.cgr, v, :router).rezports, "/",get_prop(ibn.cgr, v, :router).nports) for v in vertices(ibn.cgr)], 
            elabels = [string(get_prop(ibn.cgr, l, :link).rezcapacity,"/",get_prop(ibn.cgr, l, :link).capacity) for l in edges(ibn.cgr)], 
            paths=[IBNFramework.compilation(ibn.intents[1]).path]);f
    f[1]
end

"with initial annotation"
function draw_ibn_2(ibn::IBN)
    f =draw_network(ibn.cgr.flatgr, 
           nlabels = [string(ibn.cgr.vmap[v], ",", get_prop(ibn.cgr, v, :router).rezports, "/",get_prop(ibn.cgr, v, :router).nports) for v in vertices(ibn.cgr)], 
           elabels = [string(get_prop(ibn.cgr, l, :link).rezcapacity,"/",get_prop(ibn.cgr, l, :link).capacity) for l in edges(ibn.cgr)])
    f[1]
end

function draw_ibn_2(cgr::CompositeGraph)
    f =draw_network(cgr.flatgr, 
           nlabels = [string(cgr.vmap[v], ",", get_prop(cgr, v, :router).rezports, "/",get_prop(cgr, v, :router).nports) for v in vertices(cgr)], 
           elabels = [string(get_prop(cgr, l, :link).rezcapacity,"/",get_prop(cgr, l, :link).capacity) for l in edges(cgr)])
    f[1]
end
