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
export RouterView, FiberView, distance
export Intent, IntentConstraint, CapacityConstraint, DelayConstraint, ConnectivityIntent, IntentDAG, IntentDAGNode, IntentTransition, IntentState
export getroot, addchild!, children, descendants, getintent, getintentissuer
export simgraph, compositeGraph2IBNs!, randomsimgraph! 
export anyreservations, set_operation_status!
export @at

include("utils.jl")
const COUNTER = Counter()
const THours = typeof(1.0u"hr")

include("types/types.jl")
const IBNFPROPS = IBNFProps(0.0u"hr")

include("SDN/SDN.jl")
include("IBN/IBN.jl")
include("NetRes/NetRes.jl")
include("macrosugar.jl")

end
