# Defines SDN type and the interfaces

abstract type SDN end

"""Return the graph SDN is responsible for"""
graph(sdn::SDN) = error("Interface not implemented")

"""Reserve `cap` resources amonge path `path`"""
reserve(sdn::SDN, path::Vector{Int}, cap::Real) = error("Interface not implemented")

"""Free `cap `resources among path `path`"""
free(sdm::SDN, path::Vector{Int}, capacity::Real) = error("Interface not implemented")

#TODO define how a MetaGraph should be


"""
Check edge availability between 2 controllers:
- capacity on edge
- port in nodes
"""
function isavailable(con1, con2, ce::CompositeEdge, capacity::Real)
    src = ce.src
    dst = ce.dst
    if !(con1 isa SDN)
        src = con1.cgr.vmap[ce.src[2]]
        con1 = controllerofnode(con1, ce.src[2])
    end
    if !(con2 isa SDN)
        dst = con2.cgr.vmap[ce.dst[2]]
        con2 = controllerofnode(con2, ce.dst[2])
    end
    isavailable(con1, con2, ce, capacity, CompositeEdge(src, dst))
end

"""
Reserve resources between 2 controllers
"""
function reserve(con1, con2, ce::CompositeEdge, capacity::Real)
    src = ce.src
    dst = ce.dst
    if !(con1 isa SDN)
        src = con1.cgr.vmap[ce.src[2]]
        con1 = controllerofnode(con1, ce.src[2])
    end
    if !(con2 isa SDN)
        dst = con2.cgr.vmap[ce.dst[2]]
        con2 = controllerofnode(con2, ce.dst[2])
    end
    reserve(con1, con2, ce, capacity, CompositeEdge(src, dst))
end
