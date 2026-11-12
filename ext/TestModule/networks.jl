# Test networks as text (TOML) files and the cache of their calculated paths

"The test networks shipped with MINDFul"
const TESTDATADIR = joinpath(pkgdir(MINDF), "test", "data")
"2 domains; the single-domain tests use the first one"
const SINGLEDOMAINTESTFILE = joinpath(TESTDATADIR, "itz_IowaStatewideFiberMap-itz_Missouri__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21).toml")
"3 domains"
const MULTIDOMAINTESTFILE = joinpath(TESTDATADIR, "itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).toml")

"The file caching the calculated paths of the test networks, see [`setcachedresults!`](@ref)"
const CACHEDRESULTSFILE = Ref{Union{Nothing, String}}(nothing)

"""
$(TYPEDSIGNATURES)

Cache the calculated paths (`CachedResults`) of the test networks in `file`, so that they are calculated once and reused
by all following loads, also in later sessions.
With `reuse = false`, an existing cache is deleted, so that the paths are calculated anew (and cached again).
With `file = nothing` (the default), nothing is cached.
"""
function setcachedresults!(file::Union{Nothing, String}; reuse::Bool = true)
    if !isnothing(file)
        !reuse && rm(file; force = true)
        mkpath(dirname(file))
    end
    CACHEDRESULTSFILE[] = file
    return file
end

"""
$(TYPEDSIGNATURES)

`true` unless the julia arguments contain `--nojet`.
"""
runjet() = !any(==("--nojet"), ARGS)

"""
$(TYPEDSIGNATURES)

Build the algorithm of a domain from the template `compalg` with `typeof(compalg)(compalg, cachedresults)`.
The cached results (calculated paths) are read from and stored in `cachedresultspath` (default: see [`setcachedresults!`](@ref)),
under a key made of the content of `networkfile`, the domain id and the number of candidate paths.
With `cachedresultspath = nothing` they are calculated.
"""
function buildintcompalg(compalg::MINDF.IntentCompilationAlgorithm, ibnag::MINDF.IBNAttributeGraph, networkfile::AbstractString; cachedresultspath::Union{Nothing, String} = CACHEDRESULTSFILE[])
    candidatepathsnum = MINDF.getcandidatepathsnum(compalg)
    cachedresults = if isnothing(cachedresultspath)
        CachedResults(ibnag, candidatepathsnum)
    else
        cachekey = (hash(read(networkfile, String)), AG.graph_attr(ibnag), candidatepathsnum)
        deserializeorcalculatecachedresults(ibnag, candidatepathsnum; serializedcachedresultsdictpath = cachedresultspath, cachekey)
    end
    return typeof(compalg)(compalg, cachedresults)
end

"""
$(TYPEDSIGNATURES)

Load the 3-domain test network, every domain with the algorithm `compalg` (see [`buildintcompalg`](@ref)).
Every domain gets the other domains as handlers.
"""
function loadmultidomaintestibnfs(compalg::MINDF.IntentCompilationAlgorithm, offsettime = now(); useshortreachtransmissionmodules::Bool = false, cachedresultspath::Union{Nothing, String} = CACHEDRESULTSFILE[])
    domains_name_graph = loadnetworkfile(MULTIDOMAINTESTFILE)

    ibnfs = [
        let
                ag = name_graph[2]
                ibnag = MINDF.default_IBNAttributeGraph(ag, 25, 25; offsettime, useshortreachtransmissionmodules)
                IBNFramework(ibnag, buildintcompalg(compalg, ibnag, MULTIDOMAINTESTFILE; cachedresultspath))
        end for name_graph in domains_name_graph
    ]

    # add ibnf handlers
    for i in eachindex(ibnfs)
        for j in eachindex(ibnfs)
            i == j && continue
            push!(getibnfhandlers(ibnfs[i]), ibnfs[j])
        end
    end

    return ibnfs
end

"""
$(TYPEDSIGNATURES)

The graph of the first domain of the 2-domain test network, used as a single domain.
"""
function loadsingledomaintestibnag(offsettime = now())
    return MINDF.default_IBNAttributeGraph(first(loadnetworkfile(SINGLEDOMAINTESTFILE))[2], 25, 25; offsettime)
end

"""
$(TYPEDSIGNATURES)

The first domain of the 2-domain test network as a single domain with the algorithm `compalg` (see [`buildintcompalg`](@ref)).
"""
function loadsingledomaintestibnf(compalg::MINDF.IntentCompilationAlgorithm, offsettime = now(); cachedresultspath::Union{Nothing, String} = CACHEDRESULTSFILE[])
    ibnag = loadsingledomaintestibnag(offsettime)
    return IBNFramework(ibnag, buildintcompalg(compalg, ibnag, SINGLEDOMAINTESTFILE; cachedresultspath))
end

"""
$(TYPEDSIGNATURES)

Load the 3-domain test network with HTTP handlers, configured by `test/data/config.toml`.
"""
function loadmultidomaintestidistributedbnfs(compalg::MINDF.IntentCompilationAlgorithm, offsettime=now(); cachedresultspath::Union{Nothing, String} = CACHEDRESULTSFILE[])
    configfilepath = joinpath(TESTDATADIR, "config.toml")
    config = TOML.parsefile(configfilepath)
    CONFIGDIR = dirname(configfilepath)

    # the topology is the 3-domain test network (`config["domainfile"]` is the same network as .jld2, for `MINDFul.main`)
    domains_name_graph = loadnetworkfile(MULTIDOMAINTESTFILE)

    MINDF.generateRSAkeys(CONFIGDIR)

    domainsconfig = config["domains"]["config"]
    ips = [n["ip"] for n in domainsconfig]
    ports = [n["port"] for n in domainsconfig]
    ibnfids = [n["ibnfid"] for n in domainsconfig]
    permissions = [perm for n in domainsconfig for perm in n["permissions"]]
    privatekeysfiles = [n["rsaprivatekey"] for n in domainsconfig]
    privatekeys = [MINDF.readb64keys(MINDF.checkfilepath(CONFIGDIR, pkfile)) for pkfile in privatekeysfiles]
    publickeysfiles = [n["rsapublickey"] for n in domainsconfig]
    publickeys = [MINDF.readb64keys(MINDF.checkfilepath(CONFIGDIR, pkfile)) for pkfile in publickeysfiles]

    encryption = config["encryption"]
    if encryption
        urischeme = "https"
        MINDF.generateTLScertificate()
    else
        urischeme = "http"
    end

    ibnfsdict = Dict{Int, IBNFramework}()
    index = 1
    ibnfs = [
        let
                hdlr = Vector{MINDF.RemoteHTTPHandler}()
                localURI = HTTP.URI(; scheme = urischeme, host = ips[i], port = ports[i])
                localURIstring = string(localURI)
                push!(hdlr, MINDF.RemoteHTTPHandler(UUID(ibnfids[i]), localURIstring, "full", privatekeys[i], "", "", ""))
                for j in eachindex(ibnfids)
                    i == j && continue
                    URI = HTTP.URI(; scheme = urischeme, host = ips[j], port = ports[j])
                    URIstring = string(URI)
                    push!(hdlr, MINDF.RemoteHTTPHandler(UUID(ibnfids[j]), URIstring, permissions[index], publickeys[j], "", "", ""))
                    index += 1
            end

                ag = name_graph[2]
                ibnag = MINDF.default_IBNAttributeGraph(ag, 25, 25; offsettime)
                intcompalg = buildintcompalg(compalg, ibnag, MULTIDOMAINTESTFILE; cachedresultspath)
                ibnf = MINDF.IBNFramework(ibnag, hdlr, encryption, ips, MINDF.SDNdummy(), intcompalg, ibnfsdict; verbose = false)
        end for (i, name_graph) in enumerate(domains_name_graph)
    ]


    return ibnfs
end

"""
$(TYPEDSIGNATURES)

Load the 3-domain test network with HTTP handlers and mixed permissions, configured by `test/data/config.toml`.
"""
function loadpermissionedbnfs(compalg::MINDF.IntentCompilationAlgorithm; cachedresultspath::Union{Nothing, String} = CACHEDRESULTSFILE[])
    configfilepath = joinpath(TESTDATADIR, "config.toml")
    config = TOML.parsefile(configfilepath)
    CONFIGDIR = dirname(configfilepath)

    # the topology is the 3-domain test network (`config["domainfile"]` is the same network as .jld2, for `MINDFul.main`)
    domains_name_graph = loadnetworkfile(MULTIDOMAINTESTFILE)

    MINDF.generateRSAkeys(CONFIGDIR)

    domainsconfig = config["domains"]["config"]
    ips = [n["ip"] for n in domainsconfig]
    ports = [n["port"] for n in domainsconfig]
    ibnfids = [n["ibnfid"] for n in domainsconfig]
    permissions = ["limited", "limited", "full", "none", "full", "full"]
    privatekeysfiles = [n["rsaprivatekey"] for n in domainsconfig]
    privatekeys = [MINDF.readb64keys(MINDF.checkfilepath(CONFIGDIR, pkfile)) for pkfile in privatekeysfiles]
    publickeysfiles = [n["rsapublickey"] for n in domainsconfig]
    publickeys = [MINDF.readb64keys(MINDF.checkfilepath(CONFIGDIR, pkfile)) for pkfile in publickeysfiles]

    encryption = config["encryption"]
    if encryption
        urischeme = "https"
        MINDF.generateTLScertificate()
    else
        urischeme = "http"
    end

    ibnfsdict = Dict{Int, IBNFramework}()
    index = 1
    ibnfs = [
        let
                hdlr = Vector{MINDF.RemoteHTTPHandler}()
                localURI = HTTP.URI(; scheme = urischeme, host = ips[i], port = ports[i])
                localURIstring = string(localURI)
                push!(hdlr, MINDF.RemoteHTTPHandler(UUID(ibnfids[i]), localURIstring, "full", privatekeys[i], "", "", ""))
                for j in eachindex(ibnfids)
                    i == j && continue
                    URI = HTTP.URI(; scheme = urischeme, host = ips[j], port = ports[j])
                    URIstring = string(URI)
                    push!(hdlr, MINDF.RemoteHTTPHandler(UUID(ibnfids[j]), URIstring, permissions[index], publickeys[j], "", "", ""))
                    index += 1
            end

                ag = name_graph[2]
                ibnag = MINDF.default_IBNAttributeGraph(ag, 25, 25)
                intcompalg = buildintcompalg(compalg, ibnag, MULTIDOMAINTESTFILE; cachedresultspath)
                ibnf = MINDF.IBNFramework(ibnag, hdlr, encryption, ips, MINDF.SDNdummy(), intcompalg, ibnfsdict; verbose = false)
        end for (i, name_graph) in enumerate(domains_name_graph)
    ]

    return ibnfs
end
