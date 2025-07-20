function loadpermissionedbnfs()
    config = TOML.parsefile(TESTDIR * "/" * "data/config.toml")
    domainfile = config["domainfile"]
    if startswith(domainfile, "/") 
        finaldomainfile = configpath
    else
        finaldomainfile = TESTDIR * "/" * domainfile
    end
    encryption = config["encryption"]

    ips = Vector{String}()
    ports = Vector{Int}()
    ibnfids = Vector{Int}()
    permissions = ["limited", "limited", "full", "none", "full", "full"]

    for n in config["domains"]["config"]
        push!(ips, n["ip"])
        push!(ports, n["port"])
        push!(ibnfids, n["ibnfid"])
    end

    domains_name_graph = first(JLD2.load(finaldomainfile))[2]
    if encryption
        urischeme = "https"
        run(`$(TESTDIR)/data/generatecerts.sh`)
    else
        urischeme = "http"
    end


    ibnfs = Vector{IBNFramework}()    
    ibnfsdict = Dict{Int, IBNFramework}()
    i=1
    index = 1
    for name_graph in domains_name_graph
        hdlr = Vector{MINDF.RemoteHTTPHandler}()
        localURI = HTTP.URI(; scheme=urischeme, host=ips[i], port=ports[i])
        localURIstring = string(localURI)
        push!(hdlr, MINDF.RemoteHTTPHandler(UUID(ibnfids[i]), localURIstring, "full", "", ""))
        for j in eachindex(ibnfids)
            i == j && continue
            URI = HTTP.URI(; scheme=urischeme, host=ips[j], port=ports[j])
            URIstring = string(URI)
            push!(hdlr, MINDF.RemoteHTTPHandler(UUID(ibnfids[j]), URIstring, permissions[index], "", ""))
            index += 1
        end

        ag = name_graph[2]
        ibnag = MINDFul.default_IBNAttributeGraph(ag)
        ibnf = MINDFul.IBNFramework(ibnag, hdlr, encryption, ips, ibnfsdict; verbose=false)
        push!(ibnfs, ibnf)
        i += 1
    end

    return ibnfs
end


function testsuitepermissions!(ibnfs)
    #Requesting compiling an intent (only possible with full permission)
    conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(1), 4), MINDFul.GlobalNode(UUID(3), 25), u"100.0Gbps")
    intentuuid_bordernode = MINDFul.addintent!(ibnfs[1], conintent_bordernode, MINDFul.NetworkOperator())
    @test MINDFul.compileintent!(ibnfs[1], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS #1 -> 3 (Full permission)

    conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(3), 25), MINDFul.GlobalNode(UUID(1), 4), u"100.0Gbps")
    intentuuid_bordernode = MINDFul.addintent!(ibnfs[3], conintent_bordernode, MINDFul.NetworkOperator())
    TM.@test_permissionsthrows MINDFul.compileintent!(ibnfs[3], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10)) #3 -> 1 (Limited permission)

    conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(3), 43), MINDFul.GlobalNode(UUID(2), 37), u"100.0Gbps")
    intentuuid_bordernode = MINDFul.addintent!(ibnfs[3], conintent_bordernode, MINDFul.NetworkOperator())
    TM.@test_permissionsthrows MINDFul.compileintent!(ibnfs[3], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10)) #3 -> 2 (None permission)

    #Requesting the IBNAttributeGraph (possible with full and limited permission)
    @test MINDF.isthesame(MINDFul.requestibnattributegraph_init(ibnfs[1], getibnfhandler(ibnfs[1], getibnfid(ibnfs[2]))), getibnag(ibnfs[2])) #1 -> 2 (Full permission)
    @test MINDF.isthesame(MINDFul.requestibnattributegraph_init(ibnfs[2], getibnfhandler(ibnfs[2], getibnfid(ibnfs[1]))), getibnag(ibnfs[1])) #2 -> 1 (Limited permission)
    TM.@test_permissionsthrows MINDFul.requestibnattributegraph_init(ibnfs[3], getibnfhandler(ibnfs[3], getibnfid(ibnfs[2]))) #3 -> 2 (None permission)
end

@testset ExtendedTestSet "permissions.jl"  begin

ibnfs = loadpermissionedbnfs()
testsuitepermissions!(ibnfs)
MINDF.closeibnfserver(ibnfs)

end