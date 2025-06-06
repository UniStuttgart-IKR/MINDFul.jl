using MINDFul
using Test, TestSetExtensions
using Graphs
import AttributeGraphs as AG
using JLD2, UUIDs
using Unitful, UnitfulData
import Dates: now, Hour
import Random: MersenneTwister, randperm

import MINDFul: ReturnCodes, IBNFramework, getibnfhandlers, GlobalNode, ConnectivityIntent, addintent!, NetworkOperator, compileintent!, KShorestPathFirstFitCompilation, installintent!, uninstallintent!, uncompileintent!, getidag, getrouterview, getoxcview, RouterPortLLI, TransmissionModuleLLI, OXCAddDropBypassSpectrumLLI, canreserve, reserve!, getlinkspectrumavailabilities, getreservations, unreserve!, getibnfid, getidagnodestate, IntentState, getidagnodechildren, getidagnode, OpticalTerminateConstraint, getlogicallliorder, issatisfied, getglobalnode, getibnag, getlocalnode, getspectrumslotsrange, gettransmissionmode, getname, gettransmissionmodule, TransmissionModuleCompatibility, getrate, getspectrumslotsneeded, OpticalInitiateConstraint, getnodeview, getnodeview, getsdncontroller, getrouterview, removeintent!, getlinkstates, getcurrentlinkstate, setlinkstate!, logicalordercontainsedge, logicalordergetpath, edgeify, getintent, RemoteIntent, getisinitiator, getidagnodeid, getibnfhandler, getidagnodes, @passtime, getlinkstates, issuccess, getstaged, getidaginfo,getinstalledlightpaths, LightpathRepresentation, GBPSf, getresidualbandwidth, getidagnodeidx, getidagnodedescendants, CrossLightpathIntent, GlobalEdge, getfirst

const MINDF = MINDFul

import JET
import JET: @test_opt

TESTDIR = @__DIR__

# if you don't want JET tests do `push!(ARGS, "--nojet")` before `include`ing
RUNJET = !any(==("--nojet"), ARGS)

# get the test module from MINDFul
TM = Base.get_extension(MINDFul, :TestModule)
@test !isnothing(TM)

# some boilerplate functions

function loadmultidomaintestibnfs()
    domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]


    ibnfs = [
        let
            ag = name_graph[2]
            ibnag = MINDF.default_IBNAttributeGraph(ag)
            ibnf = IBNFramework(ibnag)
        end for name_graph in domains_name_graph
    ]


    # add ibnf handlers

    for i in eachindex(ibnfs)
        for j in eachindex(ibnfs)
            i == j && continue
            push!(getibnfhandlers(ibnfs[i]), ibnfs[j] )
        end
    end

    return ibnfs
end

function loadmultidomaintestidistributedbnfs()
    domains_name_graph = first(JLD2.load(TESTDIR*"/data/itz_IowaStatewideFiberMap-itz_Missouri-itz_UsSignal_addedge_24-23,23-15__(1,9)-(2,3),(1,6)-(2,54),(1,1)-(2,21),(1,16)-(3,18),(1,17)-(3,25),(2,27)-(3,11).jld2"))[2]


    # MA1069 instantiate with HTTPHandler
    ibnfs = [
        let
            ag = name_graph[2]
            ibnag = MINDF.default_IBNAttributeGraph(ag)
            ibnf = IBNFramework(ibnag)
        end for name_graph in domains_name_graph
    ]

    return ibnfs
end
