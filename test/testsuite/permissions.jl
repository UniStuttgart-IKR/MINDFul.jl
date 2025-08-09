function loadpermissionedbnfs()
    configfilepath = joinpath(TESTDIR, "data/config.toml")
    config = TOML.parsefile(configfilepath)
    CONFIGDIR = dirname(configfilepath)

    domainfile = config["domainfile"]
    finaldomainfile = MINDF.checkfilepath(CONFIGDIR, domainfile)
    
    generatekeysfilepath = joinpath(dirname(TESTDIR), "scripts/generatekeys.sh")
    run(`$generatekeysfilepath $CONFIGDIR`)

    domainsconfig = config["domains"]["config"]
    ips = [n["ip"] for n in domainsconfig]
    ports = [n["port"] for n in domainsconfig]
    ibnfids = [n["ibnfid"] for n in domainsconfig]
    permissions = ["limited", "limited", "full", "none", "full", "full"]
    privatekeysfiles = [n["rsaprivatekey"] for n in domainsconfig]
    privatekeys = [MINDF.readb64keys(MINDF.checkfilepath(CONFIGDIR, pkfile)) for pkfile in privatekeysfiles]
    publickeysfiles = [n["rsapublickey"] for n in domainsconfig]
    publickeys = [MINDF.readb64keys(MINDF.checkfilepath(CONFIGDIR, pkfile)) for pkfile in publickeysfiles]

    domains_name_graph = first(JLD2.load(finaldomainfile))[2]

    encryption = config["encryption"]
    if encryption
        urischeme = "https"
        generatecertsfilepath = joinpath(dirname(TESTDIR), "scripts/generatecerts.sh")
        run(`$generatecertsfilepath`)
    else
        urischeme = "http"
    end

    ibnfsdict = Dict{Int, IBNFramework}()
    index = 1
    ibnfs = [
        let
            hdlr = Vector{MINDF.RemoteHTTPHandler}()
            localURI = HTTP.URI(; scheme=urischeme, host=ips[i], port=ports[i])
            localURIstring = string(localURI)
            push!(hdlr, MINDF.RemoteHTTPHandler(UUID(ibnfids[i]), localURIstring, "full", privatekeys[i], "", "", ""))
            for j in eachindex(ibnfids)
                i == j && continue
                URI = HTTP.URI(; scheme=urischeme, host=ips[j], port=ports[j])
                URIstring = string(URI)
                push!(hdlr, MINDF.RemoteHTTPHandler(UUID(ibnfids[j]), URIstring, permissions[index], publickeys[j], "", "", ""))
                index += 1
            end

            ag = name_graph[2]
            ibnag = MINDF.default_IBNAttributeGraph(ag)
            ibnf = MINDF.IBNFramework(ibnag, hdlr, encryption, ips, ibnfsdict; verbose=false)
        end for (i, name_graph) in enumerate(domains_name_graph)
    ]

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