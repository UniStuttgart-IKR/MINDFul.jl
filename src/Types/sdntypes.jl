abstract type SDN end

"Return the graph SDN is responsible for"
graph(sdn::SDN) = error("Interface not implemented")

"Reserve `cap` resources amonge path `path`"
reserve(sdn::SDN, path::Vector{Int}, cap::Real) = error("Interface not implemented")

"Free `cap `resources among path `path`"
free(sdm::SDN, path::Vector{Int}, capacity::Real) = error("Interface not implemented")

isavailable(con1, con2, ce::NestedEdge, capacity::Real) = error("Interface not implemented")

