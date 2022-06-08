using Revise
using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework, DrawIBNFramework
using CompositeGraphs
using TestSetExtensions
using GraphMakie
using GLMakie
using UUIDs
using Unitful

import MetaGraphsNext: label_for

using Logging
testlogger = ConsoleLogger(stderr, Logging.Error)

globalnet = loadgraph(open("../data/networksnest2.graphml"), GraphMLFormat(), CompositeGraphs.CompositeGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.compositeGraph2IBNs!(globalnet)

function intentdeploy(conint, ibn)
    intidx = addintent!(ibn, conint);
    IBNFramework.deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath_opt!);
    IBNFramework.deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!);
end

# inter SDN, intra IBN intent
conint = ConnectivityIntent((myibns[1].id,2), (myibns[1].id,7), [CapacityConstraint(5)]);
intentdeploy(conint, myibns[1])
