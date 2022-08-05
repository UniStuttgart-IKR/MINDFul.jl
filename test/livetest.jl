using Chain, Parameters
using Test
using Graphs, MetaGraphs, NetworkLayout
using EzXML, GraphIO
using IBNFramework
using NestedGraphs
using TestSetExtensions
using Logging

using IBNFramework: uncompiled, compiled, installed

IBNF = IBNFramework

resetIBNF!()
testlogger = ConsoleLogger(stderr, Logging.Error)

testdir =  dirname(@__FILE__)
globalnet = loadgraph(open(joinpath(testdir,"..", "data","4nets.graphml")), GraphMLFormat(), NestedGraphs.NestedGraphFormat())
globalnet = IBNFramework.simgraph(globalnet)

myibns = IBNFramework.nestedGraph2IBNs!(globalnet)

function just_capacity(myibns, ibn1idx, ibn1node, ibn2idx, ibn2node, ibnIssueidx)
    conint = ConnectivityIntent((myibns[ibn1idx].id, ibn1node), 
                                (myibns[ibn2idx].id, ibn2node), [CapacityConstraint(5)]);
    testintentdeployment(conint, myibns[ibnIssueidx])
end

function generalfunc()
    with_logger(testlogger) do
        # across the same node. must be false
        conint = ConnectivityIntent((myibns[1].id,4), (myibns[1].id,4), [CapacityConstraint(5)])
        testintentdeployment_nosatisfy(conint, myibns[1])

        intenttuples = [
        # intra SDN, intra IBN intent
        (1, 1, 1, 3, 1),
        # inter SDN, intra IBN intent
        (1, 2, 1, 7, 1),
        # inter IBN Intent: src the IBN, destination edge node known
        (1, 2, 2, 1, 1),
        # inter IBN Intent: src the IBN, destination known
        (1, 2, 2, 3, 1),
        # inter IBN Intent: src the IBN, destination unknown
        (1, 1, 3, 1, 1),
        # inter IBN Intent: src known, destination the IBN
        (2, 3, 1, 1, 1),
        # inter IBN Intent: src known, destination edge node known
        (2, 3, 3, 7, 1),
        # inter IBN Intent: src known, destination edge node known (my)
        (2, 6, 1, 6, 1),
        # inter IBN Intent: src known, destination known (not passing through)
        (2, 3, 3, 1, 1),
        # inter IBN Intent: src known, destination known (passing through)
        (1, 3, 3, 1, 2),
        # inter IBN Intent: src known, destination unknown
        (2, 3, 3, 1, 1),
        # inter IBN Intent: src unknown, destination the IBN
        (3, 6, 1, 1, 1),
        # inter IBN Intent: src unknown, destination known 
        (3, 1, 2, 3, 1),
        # inter IBN Intent: src unknown, destination unknown 
        (3, 1, 3, 6, 1)
        ]

        for intenttuple in intenttuples
            just_capacity(myibns, intenttuple...) 
        end
        
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

        # uncompile al intents
        for ibn in myibns
            while true
                i = findfirst(x -> x[2] isa IBNFramework.NetworkProvider 
                              && getroot(ibn.intents[x[1]]).state != IBNFramework.uncompiled,
                              collect(enumerate(ibn.intentissuers)))
                i === nothing && break
                intentid = IBNF.getid(ibn.intents[i])
                @bp
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