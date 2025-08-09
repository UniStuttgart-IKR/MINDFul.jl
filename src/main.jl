function checkfilepath(directoryname::String, filepath::String)
    if startswith(filepath, "/") 
        return filepath
    else
        return joinpath(directoryname, filepath)
    end
end

function readb64keys(finalkeyfile::String)
    lines = readlines(finalkeyfile)
    return join(filter(line -> !startswith(line, "-----"), lines))
end

"""
$(TYPEDSIGNATURES)
main() function to initialize the MINDFul IBN framework.
It expects the path to read the configuration from a TOML file, set up the IBNFrameworks for each domain,
and start the HTTP server that enables communication between domains.
"""
function main()
    verbose=false
    MAINDIR = dirname(@__DIR__)
    #Checking for arguments
    if length(ARGS) < 1
        error("Usage: julia MINDFul.main() <configX.toml>")
    end

    configpath = ARGS[1]
    finalconfigpath = checkfilepath(MAINDIR, configpath)
    CONFIGDIR = dirname(finalconfigpath)
    config = TOML.parsefile(finalconfigpath)

    domainfile = config["domainfile"]
    finaldomainfile = checkfilepath(CONFIGDIR, domainfile)

    encryption = config["encryption"]

    localip = config["local"]["ip"]
    localport = config["local"]["port"]
    localid = config["local"]["ibnfid"]
    localprivatekeyfile = config["local"]["rsaprivatekey"]
    finallocalprivatekeyfile = checkfilepath(CONFIGDIR, localprivatekeyfile)
    localprivatekey = readb64keys(finallocalprivatekeyfile)
    
    neighboursconfig = config["remote"]["neighbours"]
    neighbourips = [n["ip"] for n in neighboursconfig]
    neighbourports = [n["port"] for n in neighboursconfig]
    neighbourids = [n["ibnfid"] for n in neighboursconfig]
    neigbhbourpermissions = [n["permission"] for n in neighboursconfig]
    neighbourpublickeyfiles = [n["rsapublickey"] for n in neighboursconfig]
    neighbourpublickeys = [readb64keys(checkfilepath(CONFIGDIR, pkfile)) for pkfile in neighbourpublickeyfiles]

    domains_name_graph = first(JLD2.load(finaldomainfile))[2]

    if encryption
        urischeme = "https"
        run(`$(MAINDIR)/scripts/generatecerts.sh`)
    else
        urischeme = "http"
    end

    hdlr = Vector{RemoteHTTPHandler}()

    localURI = HTTP.URI(; scheme=urischeme, host=localip, port=string(localport))
    localURIstring = string(localURI)
    push!(hdlr, RemoteHTTPHandler(UUID(localid), localURIstring, "full", localprivatekey, "", "", ""))
    for i in eachindex(neighbourips)
        URI = HTTP.URI(; scheme=urischeme, host=neighbourips[i], port=string(neighbourports[i]))
        URIstring=string(URI)
        push!(hdlr, RemoteHTTPHandler(UUID(neighbourids[i]), URIstring, neigbhbourpermissions[i], neighbourpublickeys[i], "", "", ""))
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
