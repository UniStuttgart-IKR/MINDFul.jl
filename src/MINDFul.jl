module MINDFul

using Graphs, MetaGraphs, NestedGraphs
using DocStringExtensions
using Unitful, UUIDs

import MetaGraphsNext as MGN
import MetaGraphsNext: MetaGraph as MG
import MetaGraphsNext: MetaDiGraph as MDG
import IterTools: partition
import Distances: haversine
const EARTH_RADIUS = 6371

export SDN, SDNdummy, IBNEnv
export IBN, addintent!, remintent!, deploy!, bordernodes, issatisfied
export RouterView, FiberView, getdistance
export Intent, IntentConstraint, CapacityConstraint, DelayConstraint, GoThroughConstraint,ConnectivityIntent, IntentDAG, IntentDAGNode, IntentTransition, IntentState, LightpathIntent
export getuserintent, addchild!, children, descendants, getintent, getintentissuer, getintentidxsfromissuer, getremoteintentsid, getid
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
