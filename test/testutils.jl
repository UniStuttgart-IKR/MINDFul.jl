function testintentdeployment_nosatisfy(conint, ibn)
    intidx = addintent!(ibn, conint)
    IBNFramework.deploy!(ibn, intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.shortestavailpath!; time=nexttime());
    @test getroot(ibn.intents[intidx]).state == uncompiled
    IBNFramework.deploy!(myibns[1],intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!; time=nexttime())
    @test getroot(ibn.intents[intidx]).state == uncompiled
end

function testintentdeployment(conint, ibn)
    intidx = addintent!(ibn, conint);
    IBNFramework.deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.shortestavailpath!; time=nexttime());
    @test getroot(ibn.intents[intidx]).state == compiled
    IBNFramework.deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!; time=nexttime());
    @test getroot(ibn.intents[intidx]).state == installed
    @test issatisfied(ibn, intidx)
end

function intentdeployandfault(conint, ibns, ibnidx, edgecontained)
    ibn = ibns[ibnidx]
#    ibnedge = Edge(edgecontained.src[2], edgecontained.dst[2])
    # let's take source (randomly)
    ibnofedge = ibns[edgecontained.src[1]]
    ibnedge = IBNF.localedge(ibnofedge, edgecontained, subnetwork_view=false)
    linktofail = get_prop(ibnofedge.ngr, ibnedge.src, ibnedge.dst, :link)

    intidx = addintent!(ibn, conint);
    let time=nexttime()
        deploy!(ibn,intidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), IBNFramework.shortestavailpath!; time);
        deploy!(ibn,intidx, IBNFramework.doinstall, IBNFramework.SimpleIBNModus(), IBNFramework.directinstall!; time);
    end

    @test getroot(ibn.intents[intidx]).state == IBNF.installed

    glbs, _ = IBNF.logicalorderedintents(ibn, intidx, true);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa IBNF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test contains_edg

    set_operation_status!(ibnofedge, linktofail, false; time=nexttime())
    @test getroot(ibn.intents[intidx]).state == IBNF.failure

    let time=nexttime()
        deploy!(ibn, intidx, IBNF.douninstall, IBNF.SimpleIBNModus(), IBNFramework.directuninstall!; time);
        @test getroot(ibn.intents[intidx]).state == IBNF.compiled

        deploy!(ibn, intidx, IBNF.douncompile, IBNF.SimpleIBNModus(); time);
        @test getroot(ibn.intents[intidx]).state == IBNF.uncompiled

        deploy!(ibn, intidx, IBNF.docompile, IBNF.SimpleIBNModus(), IBNF.shortestavailpath!; time)
        @test getroot(ibn.intents[intidx]).state == IBNF.compiled

        deploy!(ibn, intidx, IBNF.doinstall, IBNF.SimpleIBNModus(), IBNF.directinstall!; time)
        @test getroot(ibn.intents[intidx]).state == IBNF.installed
    end

    glbs, _ = IBNF.logicalorderedintents(ibn, intidx, true);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa IBNF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test !contains_edg

    set_operation_status!(ibnofedge, linktofail, true; time=nexttime())
end

nexttime() = IBNF.COUNTER("time")u"hr"
emptyf() = nothing