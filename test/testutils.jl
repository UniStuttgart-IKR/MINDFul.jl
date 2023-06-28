function initialize4nets()
    globalnet = open(joinpath(testdir,"data","4nets.graphml")) do io
        loadgraph(io, "global-network", GraphIO.GraphML.GraphMLFormat(), NestedGraphs.NestedGraphFormat())
    end

    simgraph = MINDF.simgraph(globalnet; 
                                distance_method = MINDF.euclidean_dist,
                                router_lcpool=defaultlinecards(), 
                                router_lccpool=defaultlinecardchassis(), 
                                router_lcccap=3,
                                transponderset=defaulttransmissionmodules())

    MINDF.nestedGraph2IBNs!(simgraph)
end

function just_capacity(myibns, ibn1idx, ibn1node, ibn2idx, ibn2node, ibnIssueidx)
    conint = ConnectivityIntent((myibns[ibn1idx].id, ibn1node), 
                                (myibns[ibn2idx].id, ibn2node), 5.0);
    testintentdeployment(conint, myibns[ibnIssueidx])
end

function testintentdeployment_nosatisfy(conint, ibn)
    intid = addintent!(ibn, conint)
    MINDF.deploy!(ibn, intid, MINDF.docompile, MINDF.SimpleIBNModus(), MINDF.shortestavailpath!; time=nexttime());
    @test getstate(getintentnode(ibn, intid)) == uncompiled
    MINDF.deploy!(ibn,intid, MINDF.doinstall, MINDF.SimpleIBNModus(), MINDF.directinstall!; time=nexttime())
    @test getstate(getintentnode(ibn, intid)) == uncompiled
end

function testintentdeployment(conint, ibn)
    intid = addintent!(ibn, conint);
    MINDF.deploy!(ibn, intid, MINDF.docompile, MINDF.SimpleIBNModus(), MINDF.shortestavailpath!; time=nexttime());
    @test getstate(getintentnode(ibn, intid)) == compiled
    MINDF.deploy!(ibn, intid, MINDF.doinstall, MINDF.SimpleIBNModus(), MINDF.directinstall!; time=nexttime());
    @test getstate(getintentnode(ibn, intid)) == installed
    @test issatisfied(ibn, intid)
end

function intentdeployandfault(conint, ibns, ibnidx, edgecontained)
    ibn = ibns[ibnidx]
#    ibnedge = Edge(edgecontained.src[2], edgecontained.dst[2])
    # let's take source (randomly)
    ibnofedge = ibns[edgecontained.src[1]]
    ibnedge = MINDF.localedge(ibnofedge, edgecontained, subnetwork_view=false)
    linktofail = get_prop(ibnofedge.ngr, ibnedge.src, ibnedge.dst, :link)

    intid = addintent!(ibn, conint);
    let time=nexttime()
        deploy!(ibn,intid, MINDF.docompile, MINDF.SimpleIBNModus(), MINDF.shortestavailpath!; time);
        deploy!(ibn,intid, MINDF.doinstall, MINDF.SimpleIBNModus(), MINDF.directinstall!; time);
    end

    @test getstate(getintentnode(ibn, intid)) == MINDF.installed

    glbs, _ = MINDF.logicalorderedintents(ibn, intid, true);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa MINDF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test contains_edg

    set_operation_status!(ibnofedge, linktofail, false; time=nexttime())
    @test getstate(getintentnode(ibn, intid)) == MINDF.failure

    let time=nexttime()
        deploy!(ibn, intid, MINDF.douninstall, MINDF.SimpleIBNModus(), MINDF.directuninstall!; time);
        @test getstate(getintentnode(ibn, intid)) == MINDF.compiled

        deploy!(ibn, intid, MINDF.douncompile, MINDF.SimpleIBNModus(); time);
        @test getstate(getintentnode(ibn, intid)) == MINDF.uncompiled

        deploy!(ibn, intid, MINDF.docompile, MINDF.SimpleIBNModus(), MINDF.shortestavailpath!; time)
        @test getstate(getintentnode(ibn, intid)) == MINDF.compiled

        deploy!(ibn, intid, MINDF.doinstall, MINDF.SimpleIBNModus(), MINDF.directinstall!; time)
        @test getstate(getintentnode(ibn, intid)) == MINDF.installed
    end

    glbs, _ = MINDF.logicalorderedintents(ibn, intid, true);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa MINDF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test !contains_edg

    set_operation_status!(ibnofedge, linktofail, true; time=nexttime())
end

nexttime() = MINDF.COUNTER("time")u"hr"
emptyf() = nothing

defaultlinecards() = [MINDF.LineCardDummy(10, 100, 26.72), MINDF.LineCardDummy(2, 400, 29.36), MINDF.LineCardDummy(1, 1000, 31.99)]
defaultlinecardchassis() = [MINDF.LineCardChassisDummy(Vector{MINDF.LineCardDummy}(), 4.7, 16)]

defaulttransmissionmodules() = [MINDF.TransmissionModuleView("DummyFlexibleTransponder",
            MINDF.TransmissionModuleDummy([MINDF.TransmissionProps(5080.0u"km", 300, 8),
            MINDF.TransmissionProps(4400.0u"km", 400, 8),
            MINDF.TransmissionProps(2800.0u"km", 500, 8),
            MINDF.TransmissionProps(1200.0u"km", 600, 8),
            MINDF.TransmissionProps(700.0u"km", 700, 10),
            MINDF.TransmissionProps(400.0u"km", 800, 10)],0,20)),
                                            MINDF.TransmissionModuleView("DummyFlexiblePluggables",
            MINDF.TransmissionModuleDummy([MINDF.TransmissionProps(5840.0u"km", 100, 4),
            MINDF.TransmissionProps(2880.0u"km", 200, 6),
            MINDF.TransmissionProps(1600.0u"km", 300, 6),
            MINDF.TransmissionProps(480.0u"km", 400, 6)],0,8))
           ]

