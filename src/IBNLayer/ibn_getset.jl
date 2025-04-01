function getsdncontroller(s)
    return s.sdncontroller
end

function getibnag(s)
    return s.ibnag
end

function getibnfid(s)
    return s.ibnfid
end

function getnode(s)
    return s.node
end

function getidag(s::IBNFramework)
    return s.intentdag
end

function getibnfhandlers(s::IBNFramework)
    return s.ibnfhandlers
end

function getibnfhandler(s::IBNFramework, uuid::UUID)
    return something(getfirst(ibnh -> uuid == getibnfid(ibnh) , s.ibnfhandlers))
end

function getidagcounter(intentdaginfo::IntentDAGInfo)
    return intentdaginfo.intentcounter
end

function getidagnodeid(idagnode::IntentDAGNode)
    return idagnode.idagnodeid
end

function getidagnodestate(idagnode::IntentDAGNode)
    return getcurrentstate(getlogstate(idagnode))
end

function getlogstate(idagnode::IntentDAGNode)
    return idagnode.logstate
end

function getcurrentstate(intentlogstate::IntentLogState)
    return intentlogstate[end][2]
end

function getintent(idagnode::IntentDAGNode)
    return idagnode.intent
end

function getsourcenode(conintent::ConnectivityIntent)
    return conintent.sourcenode
end

function getdestinationnode(conintent::ConnectivityIntent)
    return conintent.destinationnode
end

function getrate(conintent::ConnectivityIntent)
    return conintent.rate
end

function getconstraints(conintent::ConnectivityIntent)
    return conintent.constraints
end

function getweights(ibnag::IBNAttributeGraph)
    return [
        let
                ed = Edge(v1, v2)
                has_edge(ibnag, ed) ? getdistance(getedgeview(ibnag, ed)) : KMf(Inf)
        end
            for v1 in vertices(ibnag), v2 in vertices(ibnag)
    ]
end

function getedgeview(ibnag::IBNAttributeGraph, ed::Edge)
    return AG.edge_attr(ibnag)[ed]
end

function getedgeviews(ibnag::IBNAttributeGraph)
    return [AG.edge_attr(ibnag)[ed] for ed in edges(ibnag)]
end

function getnodeview(ibnag::IBNAttributeGraph, node::LocalNode)
    return AG.vertex_attr(ibnag)[node]
end

function getnodeview(ibnag::IBNAttributeGraph, node::GlobalNode)
    return AG.vertex_attr(ibnag)[getlocalnode(ibnag, node)]
end

function getnodeviews(ibnag::IBNAttributeGraph)
    return AG.vertex_attr(ibnag)
end

function getintranodeviews(ibnag::IBNAttributeGraph)
    ibnfid = getibnfid(ibnag)
    return filter(AG.vertex_attr(ibnag)) do nodeview
        getibnfid(getglobalnode(getproperties(nodeview))) == ibnfid
    end
end

function getibnfid(ibnag::IBNAttributeGraph)
    return AG.graph_attr(ibnag)
end

function getnodeview(ibnf::IBNFramework, node::LocalNode)
    return AG.vertex_attr(getibnag(ibnf))[node]
end

function emptyaggraphwithnewuuid(ibnag::IBNAttributeGraph{T}, uuid::UUID) where {T <: NodeView}
    IBNAttributeGraph{T}(uuid)
end

function gettransmissionmodulecompat(oic::OpticalInitiateConstraint)
    oic.transmissionmodulecompat
end

"""
$(TYPEDSIGNATURES)
"""
function getintent(ri::RemoteIntent)
    ri.intent
end
"""
$(TYPEDSIGNATURES)
"""
function getidagnodeid(ri::RemoteIntent)
    ri.idagnodeid
end
"""
$(TYPEDSIGNATURES)
"""
function getibnfid(ri::RemoteIntent)
    ri.ibnfid
end
"""
$(TYPEDSIGNATURES)
"""
function getisinitiator(ri::RemoteIntent)
    ri.isinitiator
end
