using MINDFul: IBNAttributeGraph, CachedResults
using MINDFul
using Test, TestSetExtensions
using Graphs
import AttributeGraphs as AG
using JLD2, UUIDs
using Unitful, UnitfulData
import Dates: now, Hour, DateTime, Second
import Dates
import Random: MersenneTwister, randperm
using HTTP, TOML, MbedTLS

import Serialization: serialize, deserialize

import MINDFul: ReturnCodes, IBNFramework, getibnfhandlers, GlobalNode, ConnectivityIntent, addintent!, NetworkOperator, compileintent!, KShorestPathFirstFitCompilation, installintent!, uninstallintent!, uncompileintent!, getidag, getrouterview, getoxcview, RouterPortLLI, TransmissionModuleLLI, OXCAddDropBypassSpectrumLLI, canreserve, reserve!, getlinkspectrumavailabilities, getreservations, unreserve!, getibnfid, getidagnodestate, IntentState, getidagnodechildren, getidagnode, OpticalTerminateConstraint, getlogicallliorder, issatisfied, getglobalnode, getibnag, getlocalnode, getspectrumslotsrange, gettransmissionmode, getname, gettransmissionmodule, TransmissionModuleCompatibility, getrate, getspectrumslotsneeded, OpticalInitiateConstraint, getnodeview, getnodeview, getsdncontroller, getrouterview, removeintent!, getlinkstates, getcurrentlinkstate, setlinkstate!, logicalordercontainsedge, logicalordergetpath, edgeify, getintent, RemoteIntent, getisinitiator, getidagnodeid, getibnfhandler, getidagnodes, @passtime, getlinkstates, issuccess, getstaged, getidaginfo, getinstalledlightpaths, LightpathRepresentation, GBPSf, getresidualbandwidth, getidagnodeidx, getidagnodedescendants, CrossLightpathIntent, GlobalEdge, getfirst, getintcompalg, getbasicalgmem, IntentCompilationAlgorithm, BestEmpiricalAvailabilityCompilation, getcandidatepathsnum, prioritizegrooming_default

const MINDF = MINDFul

import JET
import JET: @test_opt

TESTDIR = @__DIR__
SERIALIZEDCACHEDRESULTSDICTPATH = joinpath(TESTDIR, "tmp", "serializedcachedresultsdict.bin")

# if you don't want JET tests do `push!(ARGS, "--nojet")` before `include`ing
RUNJET = !any(==("--nojet"), ARGS)

# if you don't want to use serialized cached results do `push!(ARGS, "--nosercache")` before `include`ing
USESERIALCACHE = !any(==("--nosercache"), ARGS)

if !USESERIALCACHE
    if isfile(SERIALIZEDCACHEDRESULTSDICTPATH)
        rm(SERIALIZEDCACHEDRESULTSDICTPATH)
    end
end

# get the test module from MINDFul
TM = Base.get_extension(MINDFul, :TestModule)
@test !isnothing(TM)

begin 
    testexpectedfaileddag = TM.testexpectedfaileddag
    getfirstremoteintent = TM.getfirstremoteintent
    testuninstallation = TM.testuninstallation
    testuncompilation = TM.testuncompilation
    testedgeoxclogs = TM.testedgeoxclogs
    testoxcllistateconsistency = TM.testoxcllistateconsistency
    testcompilation = TM.testcompilation
    testinstallation = TM.testinstallation
    testzerostaged = TM.testzerostaged
    deserializeorcalculatecachedresults = TM.deserializeorcalculatecachedresults
    testoxcfiberallocationconsistency = TM.testoxcfiberallocationconsistency
    nothingisallocated = TM.nothingisallocated
end

function loadmultidomaintestibnfs(compalg::IntentCompilationAlgorithm, offsettime=now(); useshortreachtransmissionmodules::Bool=false)
    domains_name_graph = first(JLD2.load(TESTDIR * "/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]


    ibnfs = [
        let
                ag = name_graph[2]
                ibnag = MINDF.default_IBNAttributeGraph(ag, 25, 25; offsettime, useshortreachtransmissionmodules)
                cachedresults = deserializeorcalculatecachedresults(ibnag, getcandidatepathsnum(compalg); serializedcachedresultsdictpath = SERIALIZEDCACHEDRESULTSDICTPATH)
                intcompalg = typeof(compalg)(compalg, cachedresults)
                ibnf = IBNFramework(ibnag, intcompalg)
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

function loadmultidomaintestidistributedbnfs(compalg::IntentCompilationAlgorithm, offsettime=now()) 
    configfilepath = joinpath(TESTDIR, "data/config.toml")
    config = TOML.parsefile(configfilepath)
    CONFIGDIR = dirname(configfilepath)

    domainfile = config["domainfile"]
    finaldomainfile = MINDF.checkfilepath(CONFIGDIR, domainfile)
    domains_name_graph = first(JLD2.load(finaldomainfile))[2]

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
                cachedresults = deserializeorcalculatecachedresults(ibnag, getcandidatepathsnum(compalg); serializedcachedresultsdictpath = SERIALIZEDCACHEDRESULTSDICTPATH)
                intcompalg = typeof(compalg)(compalg, cachedresults)
                ibnf = MINDF.IBNFramework(ibnag, hdlr, encryption, ips, MINDF.SDNdummy(), intcompalg, ibnfsdict; verbose = false)
        end for (i, name_graph) in enumerate(domains_name_graph)
    ]


    return ibnfs
end

function loadpermissionedbnfs(compalg::IntentCompilationAlgorithm)
    configfilepath = joinpath(TESTDIR, "data/config.toml")
    config = TOML.parsefile(configfilepath)
    CONFIGDIR = dirname(configfilepath)

    domainfile = config["domainfile"]
    finaldomainfile = MINDF.checkfilepath(CONFIGDIR, domainfile)
    domains_name_graph = first(JLD2.load(finaldomainfile))[2]

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
                cachedresults = deserializeorcalculatecachedresults(ibnag, getcandidatepathsnum(compalg); serializedcachedresultsdictpath = SERIALIZEDCACHEDRESULTSDICTPATH)
                intcompalg = typeof(compalg)(compalg, cachedresults)
                ibnf = MINDF.IBNFramework(ibnag, hdlr, encryption, ips, MINDF.SDNdummy(), intcompalg, ibnfsdict; verbose = false)
        end for (i, name_graph) in enumerate(domains_name_graph)
    ]

    return ibnfs
end
