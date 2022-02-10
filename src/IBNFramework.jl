module IBNFramework

using Parameters
using Graphs, MetaGraphs
using DocStringExtensions
using Unitful
using CompositeGraphs

export SDN, SDNdummy, IBN, addintent, sdnofnode

include("SDN/SDN.jl")

include("IBN/IBN.jl")

include("SimNetResou/SimNetResou.jl")

include("utils.jl")

end
