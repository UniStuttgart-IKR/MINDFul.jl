function testintentdeployment_nosatisfy(conint, ibn)
    intidx = addintent!(ibn, conint)
    @at nexttime() IBNFramework.deploy!(ibn, intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.shortestavailpath!);
    @test getroot(ibn.intents[intidx]).state == uncompiled
    @at nexttime() IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!)
    @test getroot(ibn.intents[intidx]).state == uncompiled
end

function testintentdeployment(conint, ibn)
    intidx = addintent!(ibn, conint);
    @at nexttime() IBNFramework.deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.shortestavailpath!);
    @test getroot(ibn.intents[intidx]).state == compiled
    @at nexttime() IBNFramework.deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!);
    @test getroot(ibn.intents[intidx]).state == installed
    @test issatisfied(ibn, intidx)
end

function intentdeployandfault(conint, ibns, ibnidx, edgecontained)
    ibn = ibns[ibnidx]
#    ibnedge = Edge(edgecontained.src[2], edgecontained.dst[2])
    # let's take source (randomly)
    ibnofedge = ibns[edgecontained.src[1]]
    ibnedge = IBNF.localedge(ibnofedge, edgecontained, subnetwork_view=false)
    linktofail = get_prop(ibnofedge.cgr, ibnedge.src, ibnedge.dst, :link)

    intidx = addintent!(ibn, conint);
    @at nexttime() deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.shortestavailpath!);
    deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!);

    @test getroot(ibn.intents[intidx]).state == IBNF.installed

    glbs, _ = IBNF.logicalorderedintents(ibn, intidx, true);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa IBNF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test contains_edg

    @at nexttime() set_operation_status!(ibnofedge, linktofail, false)
    @test getroot(ibn.intents[intidx]).state == IBNF.failure

    @at nexttime() deploy!(ibn, intidx, IBNF.douninstall, IBNF.SimpleIBNModus(), IBNFramework.directuninstall!);
    @test getroot(ibn.intents[intidx]).state == IBNF.compiled

    deploy!(ibn, intidx, IBNF.douncompile, IBNF.SimpleIBNModus(), () -> nothing)
    @test getroot(ibn.intents[intidx]).state == IBNF.uncompiled

    deploy!(ibn, intidx, IBNF.docompile, IBNF.SimpleIBNModus(), IBNF.shortestavailpath!)
    @test getroot(ibn.intents[intidx]).state == IBNF.compiled

    deploy!(ibn, intidx, IBNF.doinstall, IBNF.SimpleIBNModus(), IBNF.directinstall!)
    @test getroot(ibn.intents[intidx]).state == IBNF.installed

    glbs, _ = IBNF.logicalorderedintents(ibn, intidx, true);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa IBNF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test !contains_edg

    @at nexttime() set_operation_status!(ibnofedge, linktofail, true)
end

nexttime() = IBNF.COUNTER("time")u"hr"
