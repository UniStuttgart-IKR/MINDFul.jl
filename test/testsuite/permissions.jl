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
    permissions = ["limited", "full", "full", "full", "full", "full"]

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
        @show ibnf.ibnfcomm.ibnfhandlers
        push!(ibnfs, ibnf)
        i += 1
    end

    return ibnfs
end


function testsuitepermissions!(ibnfs)
    conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(1), 4), MINDFul.GlobalNode(UUID(3), 25), u"100.0Gbps")
    intentuuid_bordernode = MINDFul.addintent!(ibnfs[1], conintent_bordernode, MINDFul.NetworkOperator())
    @test MINDFul.compileintent!(ibnfs[1], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10)) == ReturnCodes.SUCCESS

    conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(3), 25), MINDFul.GlobalNode(UUID(1), 4), u"100.0Gbps")
    intentuuid_bordernode = MINDFul.addintent!(ibnfs[3], conintent_bordernode, MINDFul.NetworkOperator())
    @test MINDFul.compileintent!(ibnfs[3], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10)) == ReturnCodes.FAIL_NO_PERMISSION
    
end

@testset ExtendedTestSet "permissions.jl"  begin

ibnfs = loadpermissionedbnfs()
testsuitepermissions!(ibnfs)
MINDF.closeibnfserver(ibnfs)

end