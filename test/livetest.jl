using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework
using NestedGraphs
using TestSetExtensions
using Logging, Unitful

using IBNFramework: uncompiled, compiled, installed

IBNF = IBNFramework

testdir =  dirname(@__FILE__)
globalnet = loadgraph(open(joinpath(testdir,"..", "data","4nets.graphml")), GraphMLFormat(), NestedGraphs.NestedGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)
myibns = IBNFramework.nestedGraph2IBNs!(globalnet)

conint = ConnectivityIntent((myibns[1].id, 1), (myibns[1].id, 5), [CapacityConstraint(5)]);

ibn=myibns[1]
intidx = addintent!(ibn, conint);
IBNFramework.deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.shortestavailpath!;
    time= nexttime());
@test getroot(ibn.intents[intidx]).state == compiled

@at nexttime() IBNFramework.deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!;
    time = nexttime());

@test getroot(ibn.intents[intidx]).state == installed
@test issatisfied(ibn, intidx)