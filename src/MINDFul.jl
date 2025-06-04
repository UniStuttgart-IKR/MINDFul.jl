module MINDFul

using DocStringExtensions
using EnumX
using UUIDs
using Graphs
using DataStructures
using Unitful, UnitfulData

import Dates: DateTime, now

import Printf: @sprintf
import AttributeGraphs as AG
import AttributeGraphs: AttributeGraph, vertex_attr, edge_attr

# @template (FUNCTIONS, METHODS, MACROS) = """
#                                          $(DOCSTRING)

#                                          ---
#                                          # Signatures
#                                          $(TYPEDSIGNATURES)
#                                          ---
#                                          ## Methods
#                                          $(METHODLIST)
#                                          """

public getsdncontroller, getibnag, getibnfid, getidag, getibnfhandlers, getibnfhandler, getidagcounter, getidagnodeid, getidagnodestate, getlogstate, getcurrentstate, getintent, getsourcenode, getdestinationnode, getrate, getconstraints, getweights, getedgeview, getedgeviews, getnodeview, getnodeview, getnodeviews, getintranodeviews,  getnodeview, gettransmissionmodulecompat, getintent, getidagnodeid, getisinitiator, getdistance, getspectrumslots, getspectrumavailability, getportnumber, getreservations, getreservations, getadddropportnumber, getlinkspectrumavailabilities, getlocalnode_input, getadddropport, getlocalnode_output, getspectrumslotsrange, getreservations, getopticalreach, getspectrumslotsneeded, getcost, getunderlyingequipment, gettransmissionmodes, gettransmissionmode, getnodeproperties, getproperties, getproperties, getrouterview, getoxcview, gettransmissionmoduleviewpool, gettransmissionmodulereservations, getlatitude, getlongitude, getinneighbors, getoutneighbors, getlocalnode, getglobalnode, gettransmissionmoduleviewpoolindex, gettransmissionmodesindex, getrouterportindex, getoxcadddropportindex, addintent!, removeintent!, compileintent!, uncompileintent!, installintent!, uninstallintent!, remoteintent!, getpathspectrumavailabilities, getfiberspectrumavailabilities, gettransmissionmode, gettransmissionmodule, getreservedtransmissionmode, findindexglobalnode, isinternalnode, isbordernode, getbordernodesaslocal, getbordernodesasglobal, getborderedges, getborderglobaledges, getlocalnode, getglobalnode, getopticalinitiateconstraint, ReturnCodes, issuccess



include("TypeDef/ReturnCodes.jl")
include("generic/utils.jl")
include("generic/macromagic.jl")
include("TypeDef/TypeDef.jl")
include("generic/io.jl")
include("generic/getset.jl")
include("PhyLayer/PhyLayer.jl")
include("SDNLayer/SDNLayer.jl")
include("IBNLayer/IBNLayer.jl")
include("generic/satisfy.jl")
include("generic/copyboilerplate.jl")
include("generic/defaults.jl")

end
