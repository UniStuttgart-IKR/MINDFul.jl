# Defines SDN type and the interfaces

abstract type SDN end

"""Return the graph SDN is responsible for"""
graph(sdn::SDN) = error("Interface not implemented")

"""Reserve `cap` resources amonge path `path`"""
reserve(sdn::SDN, path::Vector{Int}, cap::Real) = error("Interface not implemented")

"""Free `cap `resources among path `path`"""
free(sdm::SDN, path::Vector{Int}, capacity::Real) = error("Interface not implemented")

#TODO define how a MetaGraph should be
