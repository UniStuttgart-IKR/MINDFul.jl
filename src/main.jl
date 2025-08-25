"""
$(TYPEDSIGNATURES)
Function to check if a given file path is absolute or relative.
If it is relative, it will be joined with the given directory name.
"""
function checkfilepath(directoryname::String, filepath::String)
    if startswith(filepath, "/")
        return filepath
    else
        return joinpath(directoryname, filepath)
    end
end

"""
$(TYPEDSIGNATURES)
Function to check if openSSL is installed on the system.
It runs the `openssl version` command and checks if it succeeds.
If it fails, it prints an error message and exits.
"""
function checkifopensslinstalled()
    try
        run(pipeline(`openssl version`, stdout = devnull, stderr = devnull))
        return true
    catch e
        println("OpenSSL is not installed. Please install OpenSSL to generate keys and certificates.")
        return false
    end
end

"""
$(TYPEDSIGNATURES)
Function to generate a self-signed TLS certificate and corresponding private key.
"""
function generateTLScertificate()
    if !checkifopensslinstalled()
        exit(1)
    end

    return if !isfile("selfsignedTLS.key") || !isfile("selfsignedTLS.cert")
        cmd = `openssl req -x509 -nodes -newkey rsa:2048 -keyout selfsignedTLS.key -out selfsignedTLS.cert -subj "/CN=localhost"`
        run(pipeline(cmd, stdout = devnull, stderr = devnull))
    end
end

"""
$(TYPEDSIGNATURES)
Function to generate RSA keys (only used for testing).
In real scenarios, private keys must be previously generated and public keys must be shared accordingly.
"""
function generateRSAkeys(configdir::String)
    if !checkifopensslinstalled()
        exit(1)
    end

    currentdir = pwd()
    cd(configdir)

    if !isfile("rsa_priv1.pem") || !isfile("rsa_pub1.pem") || !isfile("rsa_priv2.pem") || !isfile("rsa_pub2.pem") || !isfile("rsa_priv3.pem") || !isfile("rsa_pub3.pem")
        cmds = [
            `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:3 -out rsa_priv1.pem`,
            `openssl pkey -in rsa_priv1.pem -out rsa_pub1.pem -pubout`,
            `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:3 -out rsa_priv2.pem`,
            `openssl pkey -in rsa_priv2.pem -out rsa_pub2.pem -pubout`,
            `openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -pkeyopt rsa_keygen_pubexp:3 -out rsa_priv3.pem`,
            `openssl pkey -in rsa_priv3.pem -out rsa_pub3.pem -pubout`,
        ]

        # Run openssl comands silencing stderr for genpkey output
        for cmd in cmds
            if occursin("genpkey", string(cmd))
                run(pipeline(cmd, stderr = devnull))
            else
                run(cmd)
            end
        end
    end

    return cd(currentdir)
end

"""
$(TYPEDSIGNATURES)
Function to read a base64 encoded key from a PEM file.
"""
function readb64keys(finalkeyfile::String)
    lines = readlines(finalkeyfile)
    return join(filter(line -> !startswith(line, "-----"), lines))
end

"""
$(TYPEDSIGNATURES)
Function to convert a base64 encoded key to PEM format.
The `typeofkey` parameter should be either "PUBLIC KEY" or "PRIVATE KEY".
"""
function convertb64keytopem(keyb64::String, typeofkey::String)
    return """
    -----BEGIN $typeofkey-----
    $keyb64
    -----END $typeofkey-----
    """
end

"""
$(TYPEDSIGNATURES)
Function to perform RSA encryption on a secret using the public key of the remote IBNF.
"""
function rsaauthentication_encrypt(remoteibnfhandler::RemoteHTTPHandler, unencryptedsecret::String)
    remotepublickeyb64 = getibnfhandlerrsapublickey(remoteibnfhandler)
    remotepublickeypem = convertb64keytopem(remotepublickeyb64, HTTPMessages.KEY_TYPEOFPUBLICKEY)

    pk_ctx = MbedTLS.PKContext()
    MbedTLS.parse_public_key!(pk_ctx, remotepublickeypem)

    secretbytes = Vector{UInt8}(codeunits(unencryptedsecret))

    rng = MbedTLS.CtrDrbg()
    entropy = MbedTLS.Entropy()
    MbedTLS.seed!(rng, entropy, Vector{UInt8}("RSAAuth"))

    encrypted = zeros(UInt8, 256)
    MbedTLS.encrypt!(pk_ctx, secretbytes, encrypted, rng)
    return base64encode(encrypted)
end

"""
$(TYPEDSIGNATURES)
main() function to initialize the MINDFul IBN framework.
It expects the path of the configuration file in TOML format, in order to set up the IBNFrameworks for each domain
and start the HTTP server that enables communication between domains.
The path can be absolute or relative to the current working directory.
The paths of the files referenced in the configuration file can be absolute or relative to the directory of the configuration file.
"""
function main()
    verbose = false
    MAINDIR = pwd()
    if length(ARGS) < 1
        error("Usage: julia MINDFul.main() <configX.toml>")
    end

    configpath = ARGS[1]
    finalconfigpath = checkfilepath(MAINDIR, configpath)
    CONFIGDIR = dirname(finalconfigpath)
    config = TOML.parsefile(finalconfigpath)

    domainfile = config["domainfile"]
    finaldomainfile = checkfilepath(CONFIGDIR, domainfile)
    domains_name_graph = first(JLD2.load(finaldomainfile))[2]

    encryption = config["encryption"]
    if encryption
        urischeme = "https"
        generateTLScertificate()
    else
        urischeme = "http"
    end

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


    hdlr = Vector{RemoteHTTPHandler}()
    localURI = HTTP.URI(; scheme = urischeme, host = localip, port = string(localport))
    localURIstring = string(localURI)
    push!(hdlr, RemoteHTTPHandler(UUID(localid), localURIstring, "full", localprivatekey, "", "", ""))
    for i in eachindex(neighbourips)
        URI = HTTP.URI(; scheme = urischeme, host = neighbourips[i], port = string(neighbourports[i]))
        URIstring = string(URI)
        push!(hdlr, RemoteHTTPHandler(UUID(neighbourids[i]), URIstring, neigbhbourpermissions[i], neighbourpublickeys[i], "", "", ""))
    end

    ibnfsdict = Dict{Int, IBNFramework}()
    ibnf = nothing
    for name_graph in domains_name_graph
        ag = name_graph[2]
        ibnag = default_IBNAttributeGraph(ag)
        if getibnfid(ibnag) == UUID(localid)
            ibnf = IBNFramework(ibnag, hdlr, encryption, neighbourips, SDNdummy(), ibnfsdict; verbose)
            break
        end
    end

    return if ibnf === nothing
        error("No matching ibnf found for ibnfid $localid")
    end
end
