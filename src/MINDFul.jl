module MINDFul

using Graphs, NestedGraphs
using DocStringExtensions
using Unitful, UUIDs

import MetaGraphs as MG
import MetaGraphs: set_prop!, get_prop, has_prop, props
import MetaGraphsNext as MGN
import IterTools: partition
import Distances: haversine
const EARTH_RADIUS = 6371

export SDN, SDNdummy, IBNEnv
export IBN, addintent!, remintent!, deploy!, bordernodes, issatisfied, getintentdag, getallintentnodes, getintentnode, getconstraints, getnode, getconditions, globalnode, getnode, getstate, getsrc, getdst
export RouterView, FiberView, getdistance
export Intent, IntentConstraint, CapacityConstraint, DelayConstraint, GoThroughConstraint,ConnectivityIntent, IntentDAG, IntentDAGNode, IntentTransition, IntentState, LightpathIntent
export addchild!, children, descendants, getintent, getintentissuer, getintentidxsfromissuer, getremoteintentsid, getid
export simgraph, nestedGraph2IBNs!, randomsimgraph! 
export anyreservations, set_operation_status!, edgeify
export getrate, getfreqslots, getoptreach

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
