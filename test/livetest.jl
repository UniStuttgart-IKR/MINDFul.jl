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
using UUIDs
using Unitful

import MetaGraphsNext: label_for

using Logging
testlogger = ConsoleLogger(stderr, Logging.Error)

globalnet = loadgraph(open("../data/networksnest2.graphml"), GraphMLFormat(), CompositeGraphs.CompositeGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.compositeGraph2IBNs!(globalnet)

        # across the same node. must be false
#conint = ConnectivityIntent((myibns[1].id,4), (myibns[1].id,4), [CapacityConstraint(5)])
#intidx = addintent!(myibns[1], conint)
#IBNFramework.deploy!(myibns[1], intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
#IBNFramework.deploy!(myibns[1], intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization!)
#
        # intra SDN, intra IBN intent
#conint = ConnectivityIntent((myibns[1].id,1), (myibns[1].id,3), [CapacityConstraint(15), DelayConstraint(5.0u"ms")])
#intidx = addintent!(myibns[1], conint)
#IBNFramework.deploy!(myibns[1], intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath_opt!)
#IBNFramework.deploy!(myibns[1], intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization!)

## inter SDN, intra IBN intent
#conint = ConnectivityIntent((myibns[1].id,2), (myibns[1].id,7), [CapacityConstraint(5)]);
#intidx = addintent!(myibns[1], conint);
#IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath_opt!);
#IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization!);

# inter IBN Intent: src the IBN, destination edge node known
conint = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,1), [CapacityConstraint(5)])
intidx = addintent!(myibns[1], conint)
IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath_opt!)
IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization!)
