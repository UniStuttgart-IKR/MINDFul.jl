"""
$(TYPEDSIGNATURES)
main() function to initialize the MINDFul IBN framework.
It expects the path to read the configuration from a TOML file, set up the IBNFrameworks for each domain,
and start the HTTP server for communication between domains.
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

    ibnfsdict = Dict{Int, IBNFramework}()
    ibnf = nothing
    for name_graph in domains_name_graph
        ag = name_graph[2]
        ibnag = default_IBNAttributeGraph(ag)
        if getibnfid(ibnag) == UUID(localid)
            ibnf = IBNFramework(ibnag, hdlr, encryption, neighbourips, ibnfsdict; verbose)
            break
        end
    end

    if ibnf === nothing
        error("No matching ibnf found for ibnfid $localid")
    end
end
