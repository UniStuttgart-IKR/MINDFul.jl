function main(configpath)
    # Checking for arguments
    #=if length(ARGS) < 1
        error("Usage: julia MINDFul.main <config.yaml>")
    end

    configpath = ARGS[1]
    if !isfile(config_path)
        error("Configuration file not found: $configpath")
    end=#

    #domainnumber = parse(Int, ARGS[2])
    
    config = YAML.load_file(configpath)
    domainfile = config["domainfile"]
    localip = config["local"][1]["ip"]
    localport = config["local"][2]["port"]
    localid = config["local"][3]["id"]
 
    neighbourips = config["neighbours"][1]["ips"]
    neighbourports = config["neighbours"][2]["ports"]
    neighbourids = config["neighbours"][3]["ids"]
   
    domains_name_graph = first(JLD2.load(domainfile))[2]
    #ENV["JULIA_SSL_NO_VERIFY_HOSTS"] = "127.0.0.1, localhost, 0.0.0.0"
    #ENV["JULIA_SSL_NO_VERIFY_HOSTS"] = ips[1]*", "*ips[2]*", "*ips[3]

    hdlr=Vector{MINDFul.RemoteHTTPHandler}()
    temp=Vector{MINDFul.RemoteHTTPHandler}()

    ibnfs = [
        let
            ag = name_graph[2]
            ibnag = MINDFul.default_IBNAttributeGraph(ag)
            ibnf = MINDFul.IBNFramework(ibnag, Vector{MINDFul.RemoteHTTPHandler}())
        end for name_graph in domains_name_graph
    ]

    localURI = HTTP.URI(; scheme="https", host=localip, port=string(localport))
    localURIstring = string(localURI)
    push!(temp, MINDFul.RemoteHTTPHandler(UUID(localid), localURIstring))
    for i in eachindex(neighbourips)
        URI = HTTP.URI(; scheme="https", host=neighbourips[i], port=string(neighbourports[i]))
        URIstring=string(URI)
        push!(temp, MINDFul.RemoteHTTPHandler(UUID(neighbourids[i]), URIstring))
    end

    for i in eachindex(ibnfs)
        for j in eachindex(ibnfs)
            if temp[j].ibnfid == UUID(i)
                push!(hdlr, temp[j])
            end
        end
    end

    for i in eachindex(ibnfs)
        push!(MINDFul.getibnfhandlers(ibnfs[i]), hdlr[i])
        for j in eachindex(ibnfs)
            i == j && continue
            push!(MINDFul.getibnfhandlers(ibnfs[i]), hdlr[j])
        end
    end
    

    MINDFul.startibnserver!(ibnfs[localid])

    if localport == 8081
        conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(1), 4), MINDFul.GlobalNode(UUID(3), 25), u"100.0Gbps")
        intentuuid_bordernode = MINDFul.addintent!(ibnfs[1], conintent_bordernode, MINDFul.NetworkOperator())

        @show MINDFul.compileintent!(ibnfs[1], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10))
        
        # install
        MINDFul.installintent!(ibnfs[1], intentuuid_bordernode; verbose=true)

        # uninstall
        MINDFul.uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
    
        # uncompile
        MINDFul.uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
    end

    #wait()
end

#main()
