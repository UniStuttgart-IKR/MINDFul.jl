module IBNFramework

using Reexport
using Parameters
using Graphs, MetaGraphs
using DocStringExtensions
using Unitful
using CompositeGraphs
using UUIDs
import MetaGraphsNext as MGN
import MetaGraphsNext: MetaGraph as MG
import MetaGraphsNext: MetaDiGraph as MDG
import IterTools: partition

import Term

@reexport using AbstractTrees
@reexport import AbstractTrees:isroot

export Counter
export SDN, SDNdummy
export IBN, addintent!, deploy!, transnodes, issatisfied
export RouterView, FiberView
export Intent, IntentConstraint, CapacityConstraint, DelayConstraint, ConnectivityIntent, IntentDAG, IntentDAGNode, IntentTransition, IntentState
export getroot, addchild!, children
export simgraph, compositeGraph2IBNs!, randomsimgraph! 
export ibnplot, ibnplot!, intentplot, intentplot!

include("utils.jl")
include("types/types.jl")
include("SDN/SDN.jl")
include("IBN/IBN.jl")
include("NetRes/NetRes.jl")
include("visualize.jl")

end
