# @testset ExtendedTestSet "interface.jl"  begin


domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]


# TODO MA1069 : initialize with RemoteIBNFHandler, not this dummy

ibnfs = [
    let
        ag = name_graph[2]
        ibnag = MINDF.default_IBNAttributeGraph(ag)
        ibnf = IBNFramework(ibnag)
    end for name_graph in domains_name_graph
]


# add ibnf handlers

for i in eachindex(ibnfs)
    for j in eachindex(ibnfs)
        i == j && continue
        push!(getibnfhandlers(ibnfs[i]), ibnfs[j] )
    end
end


# do some random allocations
rng = MersenneTwister(0)
# for counter in 1:100
for counter in 1:100
    srcibnf = rand(rng, ibnfs)
    srcnglobalnode = rand(rng, MINDF.getglobalnode.(MINDF.getproperties.(MINDF.getintranodeviews(getibnag(srcibnf)))) )
    dstibnf = rand(rng, ibnfs)
    dstglobalnode = rand(rng, MINDF.getglobalnode.(MINDF.getproperties.(MINDF.getintranodeviews(getibnag(dstibnf)))) )
    while dstglobalnode == srcnglobalnode
        dstglobalnode = rand(rng, MINDF.getglobalnode.(MINDF.getproperties.(MINDF.getintranodeviews(getibnag(dstibnf)))) )
    end

    rate = GBPSf(rand(rng)*100) 

    conintent = ConnectivityIntent(srcnglobalnode, dstglobalnode, rate)
    conintentid = addintent!(srcibnf, conintent, NetworkOperator())
    @test compileintent!(srcibnf, conintentid, KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS
    @test installintent!(srcibnf, conintentid; verbose=false) == ReturnCodes.SUCCESS
    @test issatisfied(srcibnf, conintentid)
end

# check ibnfs generally
for ibnf in ibnfs
    TM.testoxcllistateconsistency(ibnf)
    TM.testedgeoxclogs(ibnf)
end

function getibnfwithid(ibnfs::Vector{<:IBNFramework}, ibnfid::UUID)
    for ibnf in ibnfs
        if getibnfid(ibnf) == ibnfid
            return ibnf
        end
    end
end

# check ALL requests with the real counterpart
for ibnf in ibnfs
    firstenter = true
    for ibnfhandler in getibnfhandlers(ibnf)
        if !(ibnfhandler isa IBNFramework) && firstenter
            firstenter = false
            continue
        end
        ibnfhandlerframework = getibnfwithid(ibnfs, getibnfid(ibnfhandler))

        networkoperatoridagnodes = MINDF.getnetworkoperatoridagnodes(getidag(ibnfhandlerframework))
        rps = randperm(length(networkoperatoridagnodes))
        someidagnodes = first(networkoperatoridagnodes[rps], 10)


        allglobaledges = [GlobalEdge(getglobalnode(getibnag(ibnf), src(ed)), getglobalnode(getibnag(ibnf), dst(ed))) for ed in edges(getibnag(ibnf))] 

        aglobaledge = getfirst(allglobaledges) do ge
            getibnfid(src(ge)) == getibnfid(ibnf) && getibnfid(dst(ge)) == getibnfid(ibnfhandler) && return true
            getibnfid(dst(ge)) == getibnfid(ibnf) && getibnfid(src(ge)) == getibnfid(ibnfhandler) && return true
            return false
        end
        @test !isnothing(aglobaledge)
        # here all the requests
        @test MINDF.requestspectrumavailability(ibnf, ibnfhandler, aglobaledge) == MINDF.requestspectrumavailability(ibnf, ibnfhandlerframework, aglobaledge)
        @test MINDF.requestcurrentlinkstate_init(ibnf, ibnfhandler, aglobaledge) == MINDF.requestcurrentlinkstate_init(ibnf, ibnfhandlerframework, aglobaledge)
        @test MINDF.requestlinkstates_init(ibnf, ibnfhandler, aglobaledge) == MINDF.requestlinkstates_init(ibnf, ibnfhandlerframework, aglobaledge)
        MINDF.requestsetlinkstate_init!(ibnf, ibnfhandler, aglobaledge, false)
        @test MINDF.requestcurrentlinkstate_init(ibnf, ibnfhandler, aglobaledge) == MINDF.requestcurrentlinkstate_init(ibnf, ibnfhandlerframework, aglobaledge) == false

        @test MINDF.requestibnattributegraph(ibnf, ibnfhandler) == MINDF.requestibnattributegraph(ibnf, ibnfhandlerframework)
        @test MINDF.requestidag_init(ibnf, ibnfhandler) == MINDF.requestidag_init(ibnf, ibnfhandlerframework)
        @test MINDF.requestibnfhandlers_term(ibnf, ibnfhandler) == MINDF.requestibnfhandlers_term(ibnf, ibnfhandlerframework)

        for idagnode in someidagnodes
            @test MINDF.requestlogicallliorder_init(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestlogicallliorder_init(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 
            @test MINDF.requestintentglobalpath_init(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestintentglobalpath_init(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 
            @test MINDF.requestglobalnodeelectricalpresence_init(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestglobalnodeelectricalpresence_init(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 
            @test MINDF.requestintentgloballightpaths_init(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestintentgloballightpaths_init(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 
            @test MINDF.requestissatisfied(ibnf, ibnfhandler, getidagnodeid(idagnode)) == MINDF.requestissatisfied(ibnf, ibnfhandlerframework, getidagnodeid(idagnode)) 

        end
    end
end


# end
