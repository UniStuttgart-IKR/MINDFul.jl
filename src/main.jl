"""
$(TYPEDSIGNATURES)

"""
function main()
    verbose=false
    MAINDIR = dirname(@__DIR__)
    #Checking for arguments
    if length(ARGS) < 1
        error("Usage: julia MINDFul.main() <configX.toml>")
    end

    configpath = ARGS[1]
    if startswith(configpath, "/") 
        finalconfigpath = configpath
    else
        finalconfigpath = MAINDIR * "/" * configpath
    end

    config = TOML.parsefile(finalconfigpath)

    domainfile = config["domainfile"]
    if startswith(domainfile, "/") 
        finaldomainfile = configpath
    else
        finaldomainfile = MAINDIR * "/" * domainfile
    end

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
   
    domains_name_graph = first(JLD2.load(finaldomainfile))[2]

    if encryption
        urischeme = "https"
        run(`$(MAINDIR)/test/data/generatecerts.sh`)
    else
        urischeme = "http"
    end

    hdlr = Vector{RemoteHTTPHandler}()

    localURI = HTTP.URI(; scheme=urischeme, host=localip, port=string(localport))
    localURIstring = string(localURI)
    push!(hdlr, RemoteHTTPHandler(UUID(localid), localURIstring, "full", "", ""))
    for i in eachindex(neighbourips)
        URI = HTTP.URI(; scheme=urischeme, host=neighbourips[i], port=string(neighbourports[i]))
        URIstring=string(URI)
        push!(hdlr, RemoteHTTPHandler(UUID(neighbourids[i]), URIstring, neigbhbourpermissions[i], "", ""))
    end

    # ibnfs = [
    #     let
    #         ag = name_graph[2]
    #         ibnag = default_IBNAttributeGraph(ag)
    #         ibnf = IBNFramework(ibnag, nothing, hdlr)
    #     end for name_graph in domains_name_graph 
    # ]

    
    ibnf = nothing
    for name_graph in domains_name_graph
        ag = name_graph[2]
        ibnag = default_IBNAttributeGraph(ag)
        if getibnfid(ibnag) == UUID(localid)
            ibnf = IBNFramework(ibnag, hdlr, encryption, neighbourips; verbose)
            break
        end
    end

    if ibnf === nothing
        error("No matching ibnf found for ibnfid $localid")
    end
    
    if localport == 8081
        #@show ibnfs[1].ibnfhandlers
        conintent_bordernode = MINDFul.ConnectivityIntent(MINDFul.GlobalNode(UUID(1), 4), MINDFul.GlobalNode(UUID(3), 25), u"100.0Gbps")
        intentuuid_bordernode = MINDFul.addintent!(ibnf, conintent_bordernode, MINDFul.NetworkOperator())

        MINDFul.compileintent!(ibnf, intentuuid_bordernode, MINDFul.KShorestPathFirstFitCompilation(10))
        
        # install
        MINDFul.installintent!(ibnf, intentuuid_bordernode; verbose)

        # uninstall
        MINDFul.uninstallintent!(ibnf, intentuuid_bordernode; verbose)
    
        # uncompile
        MINDFul.uncompileintent!(ibnf, intentuuid_bordernode; verbose)

        closeibnfserver(ibnf)
    end

    # if localport == 8083
    #     closeibnfserver(localibnf)
    # end

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
    # end
end
