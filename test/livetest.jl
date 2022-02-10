using Revise, Chain, Parameters
using Graphs, MetaGraphs, NetworkLayout
using IBNFramework
using CompositeGraphs
using GraphMakieUtils
using GLMakie

gr1 = complete_graph(3) |> MetaDiGraph
gr2 = complete_graph(3) |> MetaDiGraph
randomsimgraph!(gr1)
randomsimgraph!(gr2)

graphplot_opts = @with_kw (layout = Spring(seed=10), nlabels = repr.(vertices(gr1)), elabels = [repr(get_prop(gr1, l, :link)) for l in edges(gr1)])
f, ax, g = draw_network(gr1; graphplot_opts()...)

sdnd1 = SDNdummy(1, gr1)
sdnd2 = SDNdummy(2, gr2)

ee = [CompositeEdge((1,1),(2,1))]
ibn = IBNFramework.IBN!(1,[sdnd1, sdnd2], ee)

conint = ConnectivityIntent((1,3), (1,5), [CapacityConstraint(15)])
addintent(ibn, conint)
s = IBNFramework.step(ibn,1, IBNFramework.InstallIntent(), IBNFramework.SimpleIBNModus())

@test ibn.states[1] == IBNFramework.InstalledIntent()
@test ibn.intimps[1] isa IBNFramework.ConnectivityIntentCompilation
