function main()
    MAINDIR = dirname(@__DIR__)
    #Checking for arguments
    if length(ARGS) < 1
        error("Usage: julia MINDFul.main <config.toml>")
    end

    configpath = ARGS[1]
    if !isfile(MAINDIR * configpath)
        error("Configuration file not found: $configpath")
    end
    #@show MAINDIR * configpath
    config = TOML.parsefile(MAINDIR * configpath)
    domainfile = MAINDIR * config["domainfile"]
    encryption = config["encryption"]

    localip = config["local"]["ip"]
    localport = config["local"]["port"]
    localid = config["local"]["ibnfid"]

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

    ibnfs = [
        let
            ag = name_graph[2]
            ibnag = default_IBNAttributeGraph(ag)
            ibnf = IBNFramework(ibnag, Vector{RemoteHTTPHandler}())
        end for name_graph in domains_name_graph
    ]

    if encryption
        urischeme = "https"
        run(`$(MAINDIR)/test/data/generatecerts.sh`)
    else
        urischeme = "http"
    end

    localibnf = getibnfwithid(ibnfs, UUID(localid))

    localURI = HTTP.URI(; scheme=urischeme, host=localip, port=string(localport))
    localURIstring = string(localURI)
    push!(getibnfhandlers(localibnf), RemoteHTTPHandler(UUID(localid), localURIstring, "full", "", ""))
    for i in eachindex(neighbourips)
        URI = HTTP.URI(; scheme=urischeme, host=neighbourips[i], port=string(neighbourports[i]))
        URIstring=string(URI)
        push!(getibnfhandlers(localibnf), RemoteHTTPHandler(UUID(neighbourids[i]), URIstring, neigbhbourpermissions[i], "", ""))
    end

    httpserver = startibnserver!(localibnf, encryption, neighbourips) 
    

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

        #println("\n\n")
        #@show getibnfhandlers(ibnfs[1])
        closeservers()
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
