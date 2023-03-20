@testset "connectivityIntentsKshortestPath.jl" begin
    with_logger(testlogger) do
        myibns = initialize4nets()

        # across the same node. must be false
        conint = ConnectivityIntent((myibns[1].id,4), (myibns[1].id,4), 5.0)
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
#        (2, 3, 3, 7, 1),
        # inter IBN Intent: src known, destination edge node known (my)
        (2, 6, 1, 6, 1),
        # inter IBN Intent: src known, destination known (not passing through)
#        (2, 3, 3, 1, 1),
        # inter IBN Intent: src known, destination known (passing through)
#        (1, 3, 3, 1, 2),
        # inter IBN Intent: src known, destination unknown
#        (2, 3, 3, 1, 1),
        # inter IBN Intent: src unknown, destination the IBN
        (3, 6, 1, 1, 1),
        # inter IBN Intent: src unknown, destination known 
#        (3, 1, 2, 3, 1),
        # inter IBN Intent: src unknown, destination unknown 
#        (3, 1, 3, 6, 1)
        ]

        for intenttuple in intenttuples
            just_capacity(myibns, intenttuple...) 
        end
        
        freezetime = nexttime()

        # uninstall all
        for ibn in myibns
            for idn in getallintentnodes(ibn)
                if MINDF.getissuer(idn) isa MINDF.NetworkProvider
                    deploy!(ibn, getid(idn), MINDF.douninstall, MINDF.SimpleIBNModus(), MINDF.directuninstall!; time=freezetime)
                end
            end
        end

        for ibn in myibns
            @test !anyreservations(ibn)

            allstates = getstate.(getallintentnodes(ibn))
            @test !any(==(MINDF.installed), allstates)
        end

        # uncompile al intents
        for ibn in myibns
            for idn in getallintentnodes(ibn)
                if MINDF.getissuer(idn) isa MINDF.NetworkProvider && MINDF.getstate(idn) != MINDF.uncompiled
                    deploy!(ibn, getid(idn), MINDF.douncompile, MINDF.SimpleIBNModus(); time = freezetime)
                end
            end
        end

        # now test result
        for ibn in myibns
            @test all(x -> x isa MINDF.NetworkProvider, MINDF.getissuer.(getallintentnodes(ibn)))
        end

        # now remove all intents
        for ibn in myibns
            for idn in getallintentnodes(ibn)
                MINDF.remintent!(ibn, getid(idn))
            end
        end
        # and test the results
        for ibn in myibns
            @test nv(ibn.intents) == 0
        end
    end
end
