function testintentdeployment_nosatisfy(conint, ibn)
    intidx = addintent!(ibn, conint)
    MINDFul.deploy!(ibn, intidx, MINDFul.docompile, MINDFul.SimpleIBNModus(), MINDFul.shortestavailpath!; time=nexttime());
    @test getroot(ibn.intents[intidx]).state == uncompiled
    MINDFul.deploy!(myibns[1],intidx, MINDFul.doinstall, MINDFul.SimpleIBNModus(), MINDFul.directinstall!; time=nexttime())
    @test getroot(ibn.intents[intidx]).state == uncompiled
end

function testintentdeployment(conint, ibn)
    intidx = addintent!(ibn, conint);
    MINDFul.deploy!(ibn,intidx, MINDFul.docompile, MINDFul.SimpleIBNModus(), MINDFul.shortestavailpath!; time=nexttime());
    @test getroot(ibn.intents[intidx]).state == compiled
    MINDFul.deploy!(ibn,intidx, MINDFul.doinstall, MINDFul.SimpleIBNModus(), MINDFul.directinstall!; time=nexttime());
    @test getroot(ibn.intents[intidx]).state == installed
    @test issatisfied(ibn, intidx)
end

function intentdeployandfault(conint, ibns, ibnidx, edgecontained)
    ibn = ibns[ibnidx]
#    ibnedge = Edge(edgecontained.src[2], edgecontained.dst[2])
    # let's take source (randomly)
    ibnofedge = ibns[edgecontained.src[1]]
    ibnedge = MINDF.localedge(ibnofedge, edgecontained, subnetwork_view=false)
    linktofail = get_prop(ibnofedge.ngr, ibnedge.src, ibnedge.dst, :link)

    intidx = addintent!(ibn, conint);
    let time=nexttime()
        deploy!(ibn,intidx, MINDFul.docompile, MINDFul.SimpleIBNModus(), MINDFul.shortestavailpath!; time);
        deploy!(ibn,intidx, MINDFul.doinstall, MINDFul.SimpleIBNModus(), MINDFul.directinstall!; time);
    end

    @test getroot(ibn.intents[intidx]).state == MINDF.installed

    glbs, _ = MINDF.logicalorderedintents(ibn, intidx, true);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa MINDF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test contains_edg

    set_operation_status!(ibnofedge, linktofail, false; time=nexttime())
    @test getroot(ibn.intents[intidx]).state == MINDF.failure

    let time=nexttime()
        deploy!(ibn, intidx, MINDF.douninstall, MINDF.SimpleIBNModus(), MINDFul.directuninstall!; time);
        @test getroot(ibn.intents[intidx]).state == MINDF.compiled

        deploy!(ibn, intidx, MINDF.douncompile, MINDF.SimpleIBNModus(); time);
        @test getroot(ibn.intents[intidx]).state == MINDF.uncompiled

        deploy!(ibn, intidx, MINDF.docompile, MINDF.SimpleIBNModus(), MINDF.shortestavailpath!; time)
        @test getroot(ibn.intents[intidx]).state == MINDF.compiled

        deploy!(ibn, intidx, MINDF.doinstall, MINDF.SimpleIBNModus(), MINDF.directinstall!; time)
        @test getroot(ibn.intents[intidx]).state == MINDF.installed
    end

    glbs, _ = MINDF.logicalorderedintents(ibn, intidx, true);
    contains_edg = edgecontained in 
        getfield.(filter(x -> x isa MINDF.NodeSpectrumIntent, getfield.(glbs, :lli)), :edge)
    @test !contains_edg

    set_operation_status!(ibnofedge, linktofail, true; time=nexttime())
end

nexttime() = MINDF.COUNTER("time")u"hr"
emptyf() = nothing