using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework
using CompositeGraphs
using TestSetExtensions
using Logging

testlogger = ConsoleLogger(stderr, Logging.Error)

globalnet = loadgraph(open("../data/networksnest.graphml"), GraphMLFormat(), CompositeGraphs.CompositeGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.compositeGraph2IBNs!(globalnet)
nothing
# intra SDN, intra IBN intent
@testset "connectivityIntentsKshortestPath.jl" begin
    with_logger(testlogger) do
        # intra SDN, intra IBN intent
        @test let
            conint = ConnectivityIntent((myibns[1].id,1), (myibns[1].id,3), [CapacityConstraint(5)]);
            intidx = addintent(myibns[1], conint);
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!);
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization);
        end
        # inter SDN, intra IBN intent
        @test let
            conint = ConnectivityIntent((myibns[1].id,2), (myibns[1].id,7), [CapacityConstraint(5)]);
            intidx = addintent(myibns[1], conint);
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!);
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization);
        end
        # inter IBN Intent: src the IBN, destination edge node known
        @test let
            conint = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,1), [CapacityConstraint(5)])
            intidx = addintent(myibns[1], conint)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
        end
        # inter IBN Intent: src the IBN, destination known
        @test let
            conint = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,3), [CapacityConstraint(5)])
            intidx = addintent(myibns[1], conint)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
        end
        # inter IBN Intent: src the IBN, destination unknown
        @test let
            conint = ConnectivityIntent((myibns[1].id,1), (myibns[3].id,1), [CapacityConstraint(5)]);#
            intidx = addintent(myibns[1], conint);
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!);
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization);
        end
        # inter IBN Intent: src known, destination the IBN
        @test let
            conint = ConnectivityIntent((myibns[2].id,3), (myibns[1].id,1), [CapacityConstraint(5)])
            intidx = addintent(myibns[1], conint)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
        end
        # inter IBN Intent: src known, destination known (not passing through)
        @test let
            conint = ConnectivityIntent((myibns[2].id,3), (myibns[3].id,1), [CapacityConstraint(5)])
            intidx = addintent(myibns[1], conint)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
        end
        # inter IBN Intent: src known, destination known (passing through)
        @test let
            conint = ConnectivityIntent((myibns[1].id,3), (myibns[3].id,1), [CapacityConstraint(5)])
            intidx = addintent(myibns[2], conint)
            IBNFramework.deploy!(myibns[2],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
            IBNFramework.deploy!(myibns[2],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
        end
        # inter IBN Intent: src known, destination unknown
        @test let
            conint = ConnectivityIntent((myibns[2].id,3), (myibns[3].id,1), [CapacityConstraint(5)])
            intidx = addintent(myibns[1], conint)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
        end
        # inter IBN Intent: src unknown, destination the IBN
        @test let
            conint = ConnectivityIntent((myibns[3].id,6), (myibns[1].id,1), [CapacityConstraint(5)])
            intidx = addintent(myibns[1], conint)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
        end
        # inter IBN Intent: src unknown, destination known 
        @test let
            conint = ConnectivityIntent((myibns[3].id,1), (myibns[2].id,3), [CapacityConstraint(5)])
            intidx = addintent(myibns[1], conint)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
        end
        # inter IBN Intent: src unknown, destination unknown 
        @test let
            conint = ConnectivityIntent((myibns[3].id,1), (myibns[3].id,6), [CapacityConstraint(5)])
            intidx = addintent(myibns[1], conint)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath!)
            IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directrealization)
        end
    end
end

