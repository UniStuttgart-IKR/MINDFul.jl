using YAML, JLD2, HTTP, UUIDs, MINDFul, Unitful, UnitfulData
const MINDF = MINDFul

function main()
    # Check for arguments
    if length(ARGS) < 2
        error("Usage: julia main.jl <config.yaml> <domainnumber>")
    end

    config_path = ARGS[1]
    if !isfile(config_path)
        error("Configuration file not found: $config_path")
    end

    domainnumber = parse(Int, ARGS[2])
    
    # Load YAML configuration
    config = YAML.load_file(config_path)

    # Extract IPs and ports
    ips = config["ips"]
    ports = config["ports"]
    domainfile = config["domainfile"]
    

    domains_name_graph = first(JLD2.load(domainfile))[2]

    hdlr=Vector{MINDFul.RemoteHTTPHandler}()

    ibnfs = [
        let
            ag = name_graph[2]
            ibnag = MINDF.default_IBNAttributeGraph(ag)
            ibnf = MINDF.IBNFramework(ibnag, Vector{MINDF.RemoteHTTPHandler}())
        end for name_graph in domains_name_graph
    ]

    for i in eachindex(ibnfs)
        port = ports[i]
        URI = HTTP.URI(; scheme="http", host=ips[i], port=string(port))
        URIstring=string(URI)
        push!(hdlr, MINDF.RemoteHTTPHandler(UUID(i), URIstring))
    end

    for i in eachindex(ibnfs)
        push!(MINDF.getibnfhandlers(ibnfs[i]), hdlr[i])
        for j in eachindex(ibnfs)
            i == j && continue
            push!(MINDF.getibnfhandlers(ibnfs[i]), hdlr[j])
        end
    end

    MINDF.startibnserver!(ibnfs[domainnumber])

    if domainnumber == 1
        conintent_bordernode = MINDF.ConnectivityIntent(MINDF.GlobalNode(UUID(1), 4), MINDF.GlobalNode(UUID(3), 25), u"100.0Gbps")
        intentuuid_bordernode = MINDF.addintent!(ibnfs[1], conintent_bordernode, MINDF.NetworkOperator())

        @show MINDF.compileintent!(ibnfs[1], intentuuid_bordernode, MINDF.KShorestPathFirstFitCompilation(10))
        
        # install
        MINDF.installintent!(ibnfs[1], intentuuid_bordernode; verbose=true)

        # uninstall
        MINDF.uninstallintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
    
        # uncompile
        MINDF.uncompileintent!(ibnfs[1], intentuuid_bordernode; verbose=true)
    end

    wait()
end

main()