using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework
using CompositeGraphs
using TestSetExtensions
using Logging

using IBNFramework: uncompiled, compiled, installed
IBNF = IBNFramework

function testintentdeployment_nodeploy(conint, ibn)
    intidx = addintent!(ibn, conint)
    IBNFramework.deploy!(ibn, intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath_opt!)
    @test getroot(ibn.intents[intidx]).state == uncompiled
    IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!)
    @test getroot(ibn.intents[intidx]).state == uncompiled
end

function testintentdeployment(conint, ibn)
    intidx = addintent!(ibn, conint);
    IBNFramework.deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.kshortestpath_opt!);
    @test getroot(ibn.intents[intidx]).state == compiled
    IBNFramework.deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!);
    @test getroot(ibn.intents[intidx]).state == installed
    @test issatisfied(ibn, intidx)
end

testlogger = ConsoleLogger(stderr, Logging.Error)

globalnet = loadgraph(open("../data/networksnest2.graphml"), GraphMLFormat(), CompositeGraphs.CompositeGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.compositeGraph2IBNs!(globalnet)

@testset "connectivityIntentsKshortestPath.jl" begin
    with_logger(testlogger) do
        # across the same node. must be false
        conint = ConnectivityIntent((myibns[1].id,4), (myibns[1].id,4), [CapacityConstraint(5)])
        testintentdeployment_nodeploy(conint, myibns[1])

        # intra SDN, intra IBN intent
        conint = ConnectivityIntent((myibns[1].id,1), (myibns[1].id,3), [CapacityConstraint(5)]);
        testintentdeployment(conint, myibns[1])

        # inter SDN, intra IBN intent
        conint = ConnectivityIntent((myibns[1].id,2), (myibns[1].id,7), [CapacityConstraint(5)]);
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src the IBN, destination edge node known
        conint = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,1), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src the IBN, destination known
        conint = ConnectivityIntent((myibns[1].id,2), (myibns[2].id,3), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src the IBN, destination unknown
        conint = ConnectivityIntent((myibns[1].id,1), (myibns[3].id,1), [CapacityConstraint(5)]);#
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src known, destination the IBN
        conint = ConnectivityIntent((myibns[2].id,3), (myibns[1].id,1), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src known, destination edge node known
        conint = ConnectivityIntent((myibns[2].id,3), (myibns[3].id,7), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src known, destination edge node known (my)
        conint = ConnectivityIntent((myibns[2].id,6), (myibns[1].id,6), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src known, destination known (not passing through)
        conint = ConnectivityIntent((myibns[2].id,3), (myibns[3].id,1), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src known, destination known (passing through)
        conint = ConnectivityIntent((myibns[1].id,3), (myibns[3].id,1), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[2])
        
        # inter IBN Intent: src known, destination unknown
        conint = ConnectivityIntent((myibns[2].id,3), (myibns[3].id,1), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])
        
        # inter IBN Intent: src unknown, destination the IBN
        conint = ConnectivityIntent((myibns[3].id,6), (myibns[1].id,1), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src unknown, destination known 
        conint = ConnectivityIntent((myibns[3].id,1), (myibns[2].id,3), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])

        # inter IBN Intent: src unknown, destination unknown 
        conint = ConnectivityIntent((myibns[3].id,1), (myibns[3].id,6), [CapacityConstraint(5)])
        testintentdeployment(conint, myibns[1])
        
        # uninstall all intents
        for ibn in myibns
            for (i,iss) in enumerate(ibn.intentissuers)
                if iss isa IBNFramework.NetworkProvider
                    deploy!(ibn, i, IBNFramework.douninstall, IBNFramework.SimpleIBNModus(), IBNFramework.directuninstall!)
                end
            end
        end

        for ibn in myibns
            @test !anyreservations(ibn)

            allstates = vcat([getfield.(IBNF.get_vertices(ibn.intents[i]), :state) 
                              for i in 1:length(ibn.intents)]...)
            @test !any(==(IBNF.installed), allstates)
        end

        for ibn in myibns
            while true
                i = findfirst(x -> x[2] isa IBNFramework.NetworkProvider 
                              && getroot(ibn.intents[x[1]]).state != IBNFramework.uncompiled,
                              collect(enumerate(ibn.intentissuers)))
                i === nothing && break
                intentid = IBNF.getid(ibn.intents[i])
                deploy!(ibn, intentid, IBNFramework.douncompile, IBNFramework.SimpleIBNModus(), () -> nothing)
            end
        end
        # now test result
        for ibn in myibns
            @test length(ibn.intents) == length(ibn.intentissuers)
            @test all(x -> x isa IBNF.NetworkProvider, ibn.intentissuers)
            @test all(x -> length(x) == 1 , ibn.intents)
        end

        # now remove all intents
        for ibn in myibns
            while true
                length(ibn.intents) == 0 && break
                idx = IBNF.getid(ibn.intents[1])
                IBNF.remintent!(ibn, idx)
            end
        end
        # and test the results
        for ibn in myibns
            @test length(ibn.intents) == length(ibn.intentissuers) == 0
        end
    end
end
