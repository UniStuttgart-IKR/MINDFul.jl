module TestModule

using DocStringExtensions, UUIDs, Graphs
import HTTP
import MINDFul as MINDF
import AttributeGraphs as AG
import Random: MersenneTwister, randperm


import MINDFul: ReturnCodes, IBNFramework, getibnfhandlers, GlobalNode, ConnectivityIntent, addintent!, NetworkOperator, compileintent!, KShorestPathFirstFitCompilation, installintent!, uninstallintent!, uncompileintent!, getidag, getrouterview, getoxcview, RouterPortLLI, TransmissionModuleLLI, OXCAddDropBypassSpectrumLLI, canreserve, reserve!, getlinkspectrumavailabilities, getreservations, unreserve!, getibnfid, getidagnodestate, IntentState, getidagnodechildren, getidagnode, OpticalTerminateConstraint, getlogicallliorder, issatisfied, getglobalnode, getibnag, getlocalnode, getspectrumslotsrange, gettransmissionmode, getname, gettransmissionmodule, TransmissionModuleCompatibility, getrate, getspectrumslotsneeded, OpticalInitiateConstraint, getnodeview, getsdncontroller, removeintent!, getcurrentlinkstate, setlinkstate!, logicalordercontainsedge, logicalordergetpath, edgeify, getintent, RemoteIntent, getisinitiator, getidagnodeid, getibnfhandler, getidagnodes, @passtime, getlinkstates, issuccess, getstaged, getidaginfo, getinstalledlightpaths, LightpathRepresentation, GBPSf, getresidualbandwidth, getidagnodeidx, getidagnodedescendants, CrossLightpathIntent, GlobalEdge, getfirst, NodeView, isbordernode, requestlinkstates_init, getbasicalgmem, getintcompalg, CachedResults, getlogstate, IntentCompilationAlgorithm, BestEmpiricalAvailabilityCompilation, getcandidatepathsnum, prioritizegrooming_default, getconstraints, AvailabilityConstraint, getdatetime, loadnetworkfile

using Unitful, UnitfulData
import Dates: now, Hour, DateTime, Second
import TOML

import Serialization: serialize, deserialize

# weak dependencies
using Test, JET

# The test prelude: `using .TestModule` gives the testing utilities, the test networks and the MINDFul names the tests use
export MINDF
export ReturnCodes, IBNFramework, getibnfhandlers, GlobalNode, ConnectivityIntent, addintent!, NetworkOperator, compileintent!, KShorestPathFirstFitCompilation, installintent!, uninstallintent!, uncompileintent!, getidag, getrouterview, getoxcview, RouterPortLLI, TransmissionModuleLLI, OXCAddDropBypassSpectrumLLI, canreserve, reserve!, getlinkspectrumavailabilities, getreservations, unreserve!, getibnfid, getidagnodestate, IntentState, getidagnodechildren, getidagnode, OpticalTerminateConstraint, getlogicallliorder, issatisfied, getglobalnode, getibnag, getlocalnode, getspectrumslotsrange, gettransmissionmode, getname, gettransmissionmodule, TransmissionModuleCompatibility, getrate, getspectrumslotsneeded, OpticalInitiateConstraint, getnodeview, getsdncontroller, removeintent!, getcurrentlinkstate, setlinkstate!, logicalordercontainsedge, logicalordergetpath, edgeify, getintent, RemoteIntent, getisinitiator, getidagnodeid, getibnfhandler, getidagnodes, @passtime, getlinkstates, issuccess, getstaged, getidaginfo, getinstalledlightpaths, LightpathRepresentation, GBPSf, getresidualbandwidth, getidagnodeidx, getidagnodedescendants, CrossLightpathIntent, GlobalEdge, getfirst, NodeView, isbordernode, requestlinkstates_init, getbasicalgmem, getintcompalg, CachedResults, getlogstate, IntentCompilationAlgorithm, BestEmpiricalAvailabilityCompilation, getcandidatepathsnum, prioritizegrooming_default, getconstraints, AvailabilityConstraint, getdatetime
export TESTDATADIR, loadnetworkfile, setcachedresults!, runjet, buildintcompalg, deserializeorcalculatecachedresults
export loadmultidomaintestibnfs, loadsingledomaintestibnag, loadsingledomaintestibnf, loadmultidomaintestidistributedbnfs, loadpermissionedbnfs
export islowlevelintentdagnodeinstalled, nothingisallocated, localnodesaregraphnodeidx, testlocalnodeisindex, testoxcfiberallocationconsistency, spectruminvariantviolations
export testcompilation, testinstallation, testuninstallation, testuncompilation, testexpectedfaileddag, getfirstremoteintent, testzerostaged
export testedgeoxclogs, testoxcllistateconsistency, testalluuidnodeindices, testlinklogsseriallyincrementaltimestamps, testintentstateseriallyincreamentaltimestamps
export testinstalledlightpathsupdowntimespositive, testallstatelogascendingtime, JETfilteroutfunctions, @test_nothrows, @test_permissionsthrows
export testsuitephysical!, testsuitebasicintent!, testsuiteopticalconstraintssingledomain!, testsuitemultidomain!, testsuitefailingintime!
export testsuitegrooming!, testsuitegroomingonfail!, testsuiteinterface!, testsuitepermissions!, testsuitefailedcompilation!, testsuitecompilationalgorithm

include("TestModule/helpers.jl")
include("TestModule/networks.jl")
include("TestModule/tests.jl")
include("TestModule/conformance.jl")

end
