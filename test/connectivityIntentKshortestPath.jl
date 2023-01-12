globalnet = open(joinpath(testdir,"..", "data","4nets.graphml")) do io
    loadgraph(io, "global-network", GraphMLFormat(), NestedGraphs.NestedGraphFormat())
end
globalnet2 = MINDFul.simgraph(globalnet)

myibns = MINDFul.nestedGraph2IBNs!(globalnet2)

# useless
ibnenv = IBNEnv(myibns, globalnet2)

function just_capacity(myibns, ibn1idx, ibn1node, ibn2idx, ibn2node, ibnIssueidx)
    conint = ConnectivityIntent((myibns[ibn1idx].id, ibn1node), 
                                (myibns[ibn2idx].id, ibn2node), [CapacityConstraint(5)]);
    testintentdeployment(conint, myibns[ibnIssueidx])
end


@testset "connectivityIntentsKshortestPath.jl" begin
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
        
        freezetime = nexttime()
        # uninstall all intents
        for ibn in myibns
            for (i,iss) in enumerate(ibn.intentissuers)
                if iss isa MINDFul.NetworkProvider
                    deploy!(ibn, i, MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time=freezetime)
                end
            end
        end

        for ibn in myibns
            @test !anyreservations(ibn)

            allstates = vcat([getfield.(MINDF.get_vertices(ibn.intents[i]), :state) 
                              for i in 1:length(ibn.intents)]...)
            @test !any(==(MINDF.installed), allstates)
        end

        # uncompile al intents
        for ibn in myibns
            while true
                i = findfirst(x -> x[2] isa MINDFul.NetworkProvider 
                              && getroot(ibn.intents[x[1]]).state != MINDFul.uncompiled,
                              collect(enumerate(ibn.intentissuers)))
                i === nothing && break
                intentid = MINDF.getid(ibn.intents[i])
                deploy!(ibn, intentid, MINDFul.douncompile, MINDFul.SimpleIBNModus(); time = freezetime)
            end
        end
        # now test result
        for ibn in myibns
            @test length(ibn.intents) == length(ibn.intentissuers)
            @test all(x -> x isa MINDF.NetworkProvider, ibn.intentissuers)
            @test all(x -> length(x) == 1 , ibn.intents)
        end

        # now remove all intents
        for ibn in myibns
            while true
                length(ibn.intents) == 0 && break
                idx = MINDF.getid(ibn.intents[1])
                MINDF.remintent!(ibn, idx)
            end
        end
        # and test the results
        for ibn in myibns
            @test length(ibn.intents) == length(ibn.intentissuers) == 0
        end
    end
end
