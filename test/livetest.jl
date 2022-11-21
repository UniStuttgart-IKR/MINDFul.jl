using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using MINDFul
using NestedGraphs
using TestSetExtensions
using Logging, Unitful

using MINDFul: uncompiled, compiled, installed

MINDF = MINDFul

testdir =  dirname(@__FILE__)
globalnet = loadgraph(open(joinpath(testdir,"..", "data","4nets.graphml")), GraphMLFormat(), NestedGraphs.NestedGraphFormat())
globalnet = MINDFul.simgraph(globalnet)
myibns = MINDFul.nestedGraph2IBNs!(globalnet)

conint = ConnectivityIntent((myibns[1].id, 1), (myibns[1].id, 5), [CapacityConstraint(5)]);

ibn=myibns[1]
intidx = addintent!(ibn, conint);
MINDFul.deploy!(ibn,intidx, MINDFul.docompile, MINDFul.SimpleIBNModus(), MINDFul.shortestavailpath!;
    time= nexttime());
@test getroot(ibn.intents[intidx]).state == compiled

@at nexttime() MINDFul.deploy!(ibn,intidx, MINDFul.doinstall, MINDFul.SimpleIBNModus(), MINDFul.directinstall!;
    time = nexttime());

@test getroot(ibn.intents[intidx]).state == installed
@test issatisfied(ibn, intidx)