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
    try
        return s.ibnfid
    catch e
        return s.handlerproperties.ibnfid
    end
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
    return s.ibnfhandlers
end

"""
$(TYPEDSIGNATURES)
"""
function getibnfhandler(s::IBNFramework, uuid::UUID)
    return something(getfirst(ibnh -> uuid == getibnfid(ibnh) , s.ibnfhandlers))
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
    IBNAttributeGraph{T}(uuid)
end

"""
$(TYPEDSIGNATURES)
"""
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
