"""
$(TYPEDSIGNATURES) 

Construct a `IBNAttributeGraph` representation for all mutli-domain network from the IBNFramework neighboring `interIBNF`
ATTENTION: the inner graph data are still representing information internally per domain.
"""
function createmultidomainIBNAttributeGraph(ibnf::IBNFramework)
    ibnfuuids = UUID[]

    ag1 = getibnag(ibnf)
    mdag = emptyaggraphwithnewuuid(ag1, UUID(0))

    _recursive_createmultidomainIBNAttributeGraph!(mdag, ibnfuuids, ibnf, ibnf)

    return mdag
end

function _recursive_createmultidomainIBNAttributeGraph!(mdag::IBNAttributeGraph, ibnfuuids::Vector{UUID}, myibnf::IBNFramework, remoteibnf::AbstractIBNFHandler)
    ibnfid = getibnfid(remoteibnf)
    ibnfid ∈ ibnfuuids && return
    remoteibnag = requestibnattributegraph_init(myibnf, remoteibnf)

    for v in vertices(remoteibnag)
        nodeview = getnodeview(remoteibnag, v)
        globalnode = getglobalnode(getproperties(nodeview))
        
        foundindex = findindexglobalnode(mdag, globalnode)
        if isnothing(foundindex)
            add_vertex!(mdag)
            push!(AG.vertex_attr(mdag), nodeview)
        else
            if isnodeviewinternal(nodeview)
                AG.vertex_attr(mdag)[foundindex] = nodeview
            end
        end
    end

    for e in edges(remoteibnag)
        offset_e = findoffsetedge(mdag, remoteibnag, e)
        add_edge!(mdag, offset_e)
        edgeview = getedgeview(remoteibnag, e)
        AG.edge_attr(mdag)[offset_e] = edgeview
    end

    push!(ibnfuuids, ibnfid)

    for interibnf in requestibnfhandlers_init(myibnf, remoteibnf)
        _recursive_createmultidomainIBNAttributeGraph!(mdag, ibnfuuids, myibnf, interibnf)
    end
end

function findoffsetedge(mdag::IBNAttributeGraph, remoteibnag::IBNAttributeGraph, e::Edge)
    globalnode_src = getglobalnode(getproperties(getnodeview(remoteibnag, src(e))))
    globalnode_dst = getglobalnode(getproperties(getnodeview(remoteibnag, dst(e))))
    src_idx = findindexglobalnode(mdag, globalnode_src)
    dst_idx = findindexglobalnode(mdag, globalnode_dst)
    (isnothing(src_idx) || isnothing(src_idx)) && error("global node not found in multi-domain attribute graph")
    
    offset_e = Edge(src_idx, dst_idx)
    return offset_e
end

