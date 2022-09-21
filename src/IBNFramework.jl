module IBNFramework

using Reexport
using Parameters
using Graphs, MetaGraphs
using DocStringExtensions
using Unitful
using NestedGraphs
using UUIDs
import MetaGraphsNext as MGN
import MetaGraphsNext: MetaGraph as MG
import MetaGraphsNext: MetaDiGraph as MDG
import IterTools: partition

import Term

@reexport using AbstractTrees
@reexport import AbstractTrees:isroot

export Counter
export SDN, SDNdummy, IBNEnv, updatetime!, resettime!
export IBN, addintent!, deploy!, transnodes, issatisfied
export RouterView, FiberView, distance
export Intent, IntentConstraint, CapacityConstraint, DelayConstraint, GoThroughConstraint,ConnectivityIntent, IntentDAG, IntentDAGNode, IntentTransition, IntentState
export getroot, addchild!, children, descendants, getintent, getintentissuer, getintentidxsfromissuer, getremoteintentsid
export simgraph, nestedGraph2IBNs!, randomsimgraph! 
export anyreservations, set_operation_status!
export @at, updateIBNFtime!, resetIBNF!
export edgeify, @recargs!

const THours = typeof(1.0u"hr")

include("Types/types.jl")
const COUNTER = Counter()

include("SDN/SDN.jl")
include("IBN/IBN.jl")
include("NetRes/NetRes.jl")
include("macrosugar.jl")
include("Metanalysis/metanalysis.jl")
include("utils.jl")

end
