function capacity_N_gothrough(myibns, ibn1idx, ibn1node, ibn2idx, ibn2node, ibnIssueidx, gothroughnode)
    conint = ConnectivityIntent((myibns[ibn1idx].id, ibn1node), 
                                (myibns[ibn2idx].id, ibn2node), 
                                5 , [GoThroughConstraint(gothroughnode)]);
    testintentdeployment(conint, myibns[ibnIssueidx])
end

@testset "connectivityIntentsKshortestPath.jl" begin
    with_logger(testlogger) do
        myibns = initialize4nets()

        intenttuples = [
        # intra SDN, intra IBN intent
        (1, 1, 1, 3, 1, (1,2)),
        (1, 1, 1, 3, 1, (1,4)),
        (1, 1, 1, 3, 1, (1,8)),

        # inter SDN, intra IBN intent
        (1, 2, 1, 7, 1, (1,2)),
        (1, 2, 1, 7, 1, (1,3)),

        # inter IBN Intent: src the IBN, destination edge node known
        (1, 2, 2, 1, 1, (1,5)),
        (1, 2, 2, 1, 1, (1,8)),

        # inter IBN Intent: src the IBN, destination known
        (1, 2, 2, 3, 1, (1,5)),
        (1, 2, 2, 3, 1, (1,8)),
        # go through edge nodes
        (1, 2, 2, 3, 1, (2,1)),
        (1, 2, 2, 3, 1, (2,2)),

        # inter IBN Intent: src the IBN, destination unknown
        (1, 1, 3, 1, 1, (1,5)),
        (1, 1, 3, 1, 1, (1,8)),
        # go through edge nodes
        (1, 1, 3, 1, 1, (2,1)),
        (1, 1, 3, 1, 1, (2,2)),

        # inter IBN Intent: src known, destination the IBN
        (2, 3, 1, 1, 1, (1,5)),
        (2, 3, 1, 1, 1, (1,8)),
        # go through edge nodes
        (2, 3, 1, 1, 1, (2,1)),
        (2, 3, 1, 1, 1, (2,2)),

        # go through outside by ibn
        (2, 3, 1, 1, 1, (2,4)),
        ]

        for intenttuple in intenttuples
                capacity_N_gothrough(myibns, intenttuple...) 
        end

    end
end
