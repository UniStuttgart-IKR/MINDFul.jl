"""
$(TYPEDSIGNATURES)

Get the sdn controller subtype of [`AbstractSDNController`](@ref)
"""
function getsdncontroller(s)
    return s.sdncontroller
end

"""
$(TYPEDSIGNATURES)

Get the [`IBNAttributeGraph`](@ref)
"""
function getibnag(s)
    return s.ibnag
end

"""
$(TYPEDSIGNATURES)

Get the id of the [`IBNFramework`](@ref)
"""
function getibnfid(s)
    return s.ibnfid
end

function getnode(s)
    return s.node
end

"""
$(TYPEDSIGNATURES)

Get the [`IntentDAG`](@ref)
"""
function getidag(s::IBNFramework)
    return s.intentdag
end

"""
$(TYPEDSIGNATURES)
"""
function getibnfhandlers(s::IBNFramework)
    return getibnfcomm(s).ibnfhandlers
end

"""
$(TYPEDSIGNATURES)
"""
function getibnfhandler(s::IBNFramework, uuid::UUID)
    return something(getfirst(ibnh -> uuid == getibnfid(ibnh), getibnfhandlers(s)))
end

"""
$(TYPEDSIGNATURES)

Get the handler of the given IBNFramework.
"""
function getibnfhandler(s::IBNFramework)
    return s
end

"""
$(TYPEDSIGNATURES)
"""
function getidagcounter(intentdaginfo::IntentDAGInfo)
    return intentdaginfo.intentcounter
end

"""
$(TYPEDSIGNATURES)
"""
function getinstalledlightpaths(intentdaginfo::IntentDAGInfo)
    return intentdaginfo.installedlightpaths
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodeid(idagnode::IntentDAGNode)
    return idagnode.idagnodeid
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodestate(idagnode::IntentDAGNode)
    return getcurrentstate(getlogstate(idagnode))
end

"""
$(TYPEDSIGNATURES)
"""
function getlogstate(idagnode::IntentDAGNode)
    return idagnode.logstate
end

"""
$(TYPEDSIGNATURES)
"""
function getintentissuer(idagnode::IntentDAGNode)
    return idagnode.intentissuer
end

"""
$(TYPEDSIGNATURES)
"""
function getcurrentstate(intentlogstate::IntentLogState)
    return intentlogstate[end][2]
end

"""
$(TYPEDSIGNATURES)
"""
function getintent(idagnode::IntentDAGNode)
    return idagnode.intent
end

"""
$(TYPEDSIGNATURES)
"""
function getsourcenode(conintent::ConnectivityIntent)
    return conintent.sourcenode
end

"""
$(TYPEDSIGNATURES)
"""
function getdestinationnode(conintent::ConnectivityIntent)
    return conintent.destinationnode
end

"""
$(TYPEDSIGNATURES)
"""
function getrate(conintent::ConnectivityIntent)
    return conintent.rate
end

"""
$(TYPEDSIGNATURES)
"""
function getconstraints(conintent::ConnectivityIntent)
    return conintent.constraints
end

"""
$(TYPEDSIGNATURES)
"""
function getweights(ibnag::IBNAttributeGraph)
    return [
        let
                ed = Edge(v1, v2)
                has_edge(ibnag, ed) ? getdistance(getedgeview(ibnag, ed)) : KMf(Inf)
        end
            for v1 in vertices(ibnag), v2 in vertices(ibnag)
    ]
end

"""
$(TYPEDSIGNATURES)
"""
function getedgeview(ibnag::IBNAttributeGraph, ed::Edge)
    return AG.edge_attr(ibnag)[ed]
end

"""
$(TYPEDSIGNATURES)
"""
function getedgeviews(ibnag::IBNAttributeGraph)
    return [AG.edge_attr(ibnag)[ed] for ed in edges(ibnag)]
end

"""
$(TYPEDSIGNATURES)
"""
function getnodeview(ibnag::IBNAttributeGraph, node::LocalNode)
    return AG.vertex_attr(ibnag)[node]
end

"""
$(TYPEDSIGNATURES)
"""
function getnodeview(ibnag::IBNAttributeGraph, node::GlobalNode)
    return AG.vertex_attr(ibnag)[getlocalnode(ibnag, node)]
end

"""
$(TYPEDSIGNATURES)
"""
function getnodeviews(ibnag::IBNAttributeGraph)
    return AG.vertex_attr(ibnag)
end

"""
$(TYPEDSIGNATURES)
"""
function getintranodeviews(ibnag::IBNAttributeGraph)
    ibnfid = getibnfid(ibnag)
    return filter(AG.vertex_attr(ibnag)) do nodeview
        getibnfid(getglobalnode(getproperties(nodeview))) == ibnfid
    end
end

"""
$(TYPEDSIGNATURES)
"""
function getibnfid(ibnag::IBNAttributeGraph)
    return AG.graph_attr(ibnag)
end

"""
$(TYPEDSIGNATURES)
"""
function getnodeview(ibnf::IBNFramework, node::LocalNode)
    return AG.vertex_attr(getibnag(ibnf))[node]
end

"""
$(TYPEDSIGNATURES)
"""
function emptyaggraphwithnewuuid(ibnag::IBNAttributeGraph{T}, uuid::UUID) where {T <: NodeView}
    return IBNAttributeGraph{T}(uuid)
end

"""
$(TYPEDSIGNATURES)
"""
function gettransmissionmodulecompat(oic::OpticalInitiateConstraint)
    return oic.transmissionmodulecompat
end

"""
$(TYPEDSIGNATURES)
"""
function getdestinationnode(otc::OpticalTerminateConstraint)
    return otc.finaldestination
end

"""
$(TYPEDSIGNATURES)
"""
function getintent(ri::RemoteIntent)
    return ri.intent
end
"""
$(TYPEDSIGNATURES)
"""
function getidagnodeid(ri::RemoteIntent)
    return ri.idagnodeid
end
"""
$(TYPEDSIGNATURES)
"""
function getibnfid(ri::RemoteIntent)
    return ri.ibnfid
end
"""
$(TYPEDSIGNATURES)
"""
function getisinitiator(ri::RemoteIntent)
    return ri.isinitiator
end

"""
$(TYPEDSIGNATURES)
"""
function getpath(lpr::LightpathRepresentation)
    return lpr.path
end

"""
$(TYPEDSIGNATURES)
"""
function getstartsoptically(lpr::LightpathRepresentation)
    return lpr.startsoptically
end

"""
$(TYPEDSIGNATURES)
"""
function getterminatessoptically(lpr::LightpathRepresentation)
    return lpr.terminatessoptically
end

"""
$(TYPEDSIGNATURES)
"""
function gettotalbandwidth(lpr::LightpathRepresentation)
    return lpr.totalbandwidth
end

"""
$(TYPEDSIGNATURES)
"""
function getdestinationnode(lpr::LightpathRepresentation)
    return lpr.destinationnode
end

"""
$(TYPEDSIGNATURES)
"""
function getlocalnode(ena::EndNodeAllocations)
    return ena.localnode
end

"""
$(TYPEDSIGNATURES)
"""
function getrouterportindex(ena::EndNodeAllocations)
    return ena.routerportindex
end

"""
$(TYPEDSIGNATURES)
"""
function gettransmissionmoduleviewpoolindex(ena::EndNodeAllocations)
    return ena.transmissionmoduleviewpoolindex
end

"""
$(TYPEDSIGNATURES)
"""
function gettransmissionmodesindex(ena::EndNodeAllocations)
    return ena.transmissionmodesindex
end

"""
$(TYPEDSIGNATURES)
"""
function getlocalnode_input(ena::EndNodeAllocations)
    return ena.localnode_input
end

"""
$(TYPEDSIGNATURES)
"""
function getadddropport(ena::EndNodeAllocations)
    return ena.adddropport
end

"""
$(TYPEDSIGNATURES)
"""
function getlocalnode(ena::MutableEndNodeAllocations)
    return ena.localnode
end

"""
$(TYPEDSIGNATURES)
"""
function getrouterportindex(ena::MutableEndNodeAllocations)
    return ena.routerportindex
end

"""
$(TYPEDSIGNATURES)
"""
function gettransmissionmoduleviewpoolindex(ena::MutableEndNodeAllocations)
    return ena.transmissionmoduleviewpoolindex
end

"""
$(TYPEDSIGNATURES)
"""
function gettransmissionmodesindex(ena::MutableEndNodeAllocations)
    return ena.transmissionmodesindex
end

"""
$(TYPEDSIGNATURES)
"""
function getlocalnode_input(ena::MutableEndNodeAllocations)
    return ena.localnode_input
end

"""
$(TYPEDSIGNATURES)
"""
function getadddropport(ena::MutableEndNodeAllocations)
    return ena.adddropport
end

"""
$(TYPEDSIGNATURES)
"""
function getlocalnode_output(ena::MutableEndNodeAllocations)
    return ena.localnode_output
end

"""
$(TYPEDSIGNATURES)
"""
function setlocalnode!(ena::MutableEndNodeAllocations, intval::Union{Nothing, Int})
    return ena.localnode = intval
end

"""
$(TYPEDSIGNATURES)
"""
function setrouterportindex!(ena::MutableEndNodeAllocations, intval::Union{Nothing, Int})
    return ena.routerportindex = intval
end

"""
$(TYPEDSIGNATURES)
"""
function settransmissionmoduleviewpoolindex!(ena::MutableEndNodeAllocations, intval::Union{Nothing, Int})
    return ena.transmissionmoduleviewpoolindex = intval
end

"""
$(TYPEDSIGNATURES)
"""
function settransmissionmodesindex!(ena::MutableEndNodeAllocations, intval::Union{Nothing, Int})
    return ena.transmissionmodesindex = intval
end

"""
$(TYPEDSIGNATURES)
"""
function setlocalnode_input!(ena::MutableEndNodeAllocations, intval::Union{Nothing, Int})
    return ena.localnode_input = intval
end

"""
$(TYPEDSIGNATURES)
"""
function setadddropport!(ena::MutableEndNodeAllocations, intval::Union{Nothing, Int})
    return ena.adddropport = intval
end

"""
$(TYPEDSIGNATURES)
"""
function setlocalnode_output!(ena::MutableEndNodeAllocations, intval::Union{Nothing, Int})
    return ena.localnode_output = intval
end


"""
$(TYPEDSIGNATURES)
"""
function getsourcenodeallocations(lpintent::LightpathIntent)
    return lpintent.sourcenodeallocations
end

"""
$(TYPEDSIGNATURES)
"""
function getdestinationnodeallocations(lpintent::LightpathIntent)
    return lpintent.destinationnodeallocations
end

"""
$(TYPEDSIGNATURES)
"""
function getspectrumslotsrange(lpintent::LightpathIntent)
    return lpintent.spectrumslotsrange
end

"""
$(TYPEDSIGNATURES)
"""
function getpath(lpintent::LightpathIntent)
    return lpintent.path
end

"""
$(TYPEDSIGNATURES)
"""
function getlightpathconnectivityintent(clpi::CrossLightpathIntent)
    return clpi.lightpathconnectivityintent
end

"""
$(TYPEDSIGNATURES)
"""
function getremoteconnectivityintent(clpi::CrossLightpathIntent)
    return clpi.remoteconnectivityintent
end

"""
$(TYPEDSIGNATURES)
Get the base URL of the HTTP server of a remote domain.
"""
function getbaseurl(remotehandler::AbstractIBNFHandler)
    return remotehandler.baseurl
end

"""
$(TYPEDSIGNATURES)
Get the established permission of a remote domain.
"""
function getibnfhandlerperm(remotehandler::AbstractIBNFHandler)
    return remotehandler.permission
end

"""
$(TYPEDSIGNATURES)
Get the generated token for authenticating a remote domain.
"""
function getibnfhandlergentoken(remotehandler::AbstractIBNFHandler)
    return remotehandler.gentoken
end

"""
$(TYPEDSIGNATURES)
Set the generated token for authenticating a remote domain.
"""
function setibnfhandlergentoken!(remotehandler::AbstractIBNFHandler, generatedtoken::String)
    return remotehandler.gentoken = generatedtoken
end

"""
$(TYPEDSIGNATURES)
Get the received token for authenticating to a remote domain.
"""
function getibnfhandlerrecvtoken(remotehandler::AbstractIBNFHandler)
    return remotehandler.recvtoken
end

"""
$(TYPEDSIGNATURES)
Set the received token for authenticating to a remote domain.
"""
function setibnfhandlerrecvtoken!(remotehandler::AbstractIBNFHandler, receivedtoken::String)
    return remotehandler.recvtoken = receivedtoken
end

"""
$(TYPEDSIGNATURES)
Get the port of the server of a remote domain.
"""
function getibnfhandlerport(remotehandler::AbstractIBNFHandler)
    return parse(Int, HTTP.URI(remotehandler.baseurl).port)
end

"""
$(TYPEDSIGNATURES)
"""
function getibnfwithid(ibnfs::Vector{<:IBNFramework}, ibnfid::UUID)
    for ibnf in ibnfs
        if getibnfid(ibnf) == ibnfid
            return ibnf
        end
    end
    return
end

"""
$(TYPEDSIGNATURES)
"""
function getibnfcomm(ibnf::IBNFramework)
    return ibnf.ibnfcomm
end

"""
$(TYPEDSIGNATURES)
Get the server of an IBNFramework.
"""
function getibnfserver(ibnf::IBNFramework)
    return getibnfcomm(ibnf).server
end

"""
$(TYPEDSIGNATURES)
Set the running server of an IBNFramework.
"""
function setibnfserver!(ibnf::IBNFramework, server::OxygenServer)
    return ibnf.ibnfcomm.server = server
end

"""
$(TYPEDSIGNATURES)
Get the RSA private key of a local domain.
"""
function getibnfrsaprivatekey(ibnf::IBNFramework)
    return getibnfhandlers(ibnf)[1].rsakey
end

"""
$(TYPEDSIGNATURES)
Get the RSA public key of a remote domain.
"""
function getibnfhandlerrsapublickey(remotehandler::RemoteHTTPHandler)
    return remotehandler.rsakey
end

"""
$(TYPEDSIGNATURES)
Set the RSA secret for authenticating a remote domain.
"""
function setibnfhandlerrsasecret!(remotehandler::RemoteHTTPHandler, secret::String)
    return remotehandler.rsasecret = secret
end

"""
$(TYPEDSIGNATURES)
Get the RSA secret for authenticating a remote domain.
"""
function getibnfhandlerrsasecret(remotehandler::RemoteHTTPHandler)
    return remotehandler.rsasecret
end

"""
$(TYPEDSIGNATURES)
"""
function getavailabilityrequirement(ac::AvailabilityConstraint)
    return ac.availabilityrequirement
end

"""
$(TYPEDSIGNATURES)
"""
function getcompliancetarget(ac::AvailabilityConstraint)
    return ac.compliancetarget
end
