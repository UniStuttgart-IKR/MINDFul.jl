function main()
    #Checking for arguments
    if length(ARGS) < 1
        error("Usage: julia MINDFul.main <config.toml>")
    end

    configpath = ARGS[1]
    if !isfile(configpath)
        error("Configuration file not found: $configpath")
    end

    #domainnumber = parse(Int, ARGS[2])
    
    config = TOML.parsefile(configpath)
    domainfile = config["domainfile"]
    encryption = config["encryption"]

    localip = config["local"]["ip"]
    localport = config["local"]["port"]
    localid = config["local"]["ibnfid"]
 
    # neighbourips = config["neighbours"][1]["ips"]
    # neighbourports = config["neighbours"][2]["ports"]
    # neighbourids = config["neighbours"][3]["ids"]

    neighbourips = String[]
    neighbourports = Int[]
    neighbourids = Any[]  
    neigbhbourpermissions = String[]

    for n in config["remote"]["neighbours"]
        push!(neighbourips, n["ip"])
        push!(neighbourports, n["port"])
        push!(neighbourids, n["ibnfid"])
        push!(neigbhbourpermissions, n["permission"])
    end
   
    domains_name_graph = first(JLD2.load(domainfile))[2]
    #ENV["JULIA_SSL_NO_VERIFY_HOSTS"] = "127.0.0.1, localhost, 0.0.0.0"
    #ENV["JULIA_SSL_NO_VERIFY_HOSTS"] = ips[1]*", "*ips[2]*", "*ips[3]

    hdlr=Vector{MINDFul.RemoteHTTPHandler}()
    #temp=Vector{MINDFul.RemoteHTTPHandler}()

    ibnfs = [
        let
            ag = name_graph[2]
            ibnag = MINDFul.default_IBNAttributeGraph(ag)
            ibnf = MINDFul.IBNFramework(ibnag, Vector{MINDFul.RemoteHTTPHandler}())
        end for name_graph in domains_name_graph
    ]

    if encryption
        urischeme = "https"
        run(`./src/generatecerts.sh`)
    else
        urischeme = "http"
    end

    localURI = HTTP.URI(; scheme=urischeme, host=localip, port=string(localport))
    localURIstring = string(localURI)
    push!(hdlr, MINDFul.RemoteHTTPHandler(UUID(localid), localURIstring, "full", Vector{String}(), Vector{String}()))
    for i in eachindex(neighbourips)
        URI = HTTP.URI(; scheme=urischeme, host=neighbourips[i], port=string(neighbourports[i]))
        URIstring=string(URI)
        push!(hdlr, MINDFul.RemoteHTTPHandler(UUID(neighbourids[i]), URIstring, neigbhbourpermissions[i], Vector{String}(), Vector{String}()))
    end

    # for i in eachindex(ibnfs)
    #     for j in eachindex(ibnfs)
    #         if temp[j].ibnfid == UUID(i)
    #             push!(hdlr, temp[j])
    #         end
    #     end
    # end

    # for i in eachindex(ibnfs)
    #     push!(MINDFul.getibnfhandlers(ibnfs[i]), hdlr[i])
    #     for j in eachindex(ibnfs)
    #         i == j && continue
    #         push!(MINDFul.getibnfhandlers(ibnfs[i]), hdlr[j])
    #     end
    # end

    for i in eachindex(ibnfs)
        push!(MINDFul.getibnfhandlers(ibnfs[localid]), hdlr[i])
    end
    

    httpserver = MINDFul.startibnserver!(ibnfs[localid], encryption, neighbourips)   
    
    # for i in eachindex(neighbourips)
    #     initiatoribnfid = string(getibnfid(ibnfs[localid]))
    #     token = "mindfull"
    #     resp = sendrequest(temp[i+1], HTTPMessages.URI_HANDSHAKE, Dict(HTTPMessages.KEY_INITIATORIBNFID => initiatoribnfid))
    # end
    
    #@show resp
    

    if localport == 8081
        #@show ibnfs[1].ibnfhandlers
        conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(1), 4), MINDFul.GlobalNode(UUID(3), 25), u"100.0Gbps")
        intentuuid_bordernode = MINDFul.addintent!(ibnfs[1], conintent_bordernode, MINDFul.NetworkOperator())

        @show MINDFul.compileintent!(ibnfs[1], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10))
        
        # install
        MINDFul.installintent!(ibnfs[1], intentuuid_bordernode; verbose=true)

        # uninstall
        MINDFul.uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
    
        # uncompile
        MINDFul.uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose=true)

        println("\n\n")
        #@show getibnfhandlers(ibnfs[1])
    end

    # if localport == 8083
    #     conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(3), 25), MINDFul.GlobalNode(UUID(1), 4), u"100.0Gbps")
    #     intentuuid_bordernode = MINDFul.addintent!(ibnfs[3], conintent_bordernode, MINDFul.NetworkOperator())

    #     @show MINDFul.compileintent!(ibnfs[3], intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10))
        
    #     # install
    #     MINDFul.installintent!(ibnfs[3], intentuuid_bordernode; verbose=true)

    #     # uninstall
    #     MINDFul.uninstallintent!(ibnfs[3], intentuuid_bordernode; verbose=true)
    
    #     # uncompile
    #     MINDFul.uncompileintent!(ibnfs[3], intentuuid_bordernode; verbose=true)

    #     println("\n\n")
    #     @show getibnfhandlers(ibnfs[3])
    # end
    #return httpserver
end
