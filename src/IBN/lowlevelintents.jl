"$(TYPEDSIGNATURES) Get low level intents for `PathIntent` `pt`"
function lowlevelintents(pt::PathIntent)
    [NodeRouterPortIntent(nd, 100.0) for nd in [pt.path[1], pt.path[end]]]
end

# Terminate for HalfFiberIn ?
"$(TYPEDSIGNATURES) Get low level intents for `SpectrumIntent` `si`"
function lowlevelintents(si::SpectrumIntent)
    llis = [NodeSpectrumIntent(nd, e, si.spectrumalloc, getrate(si)) for e in edgeify(si.lightpath) for nd in [src(e), dst(e)]]
    any(c -> c isa BorderInitiateConstraint,getconstraints(si)) && deleteat!(llis, 1)
    any(c -> c isa BorderTerminateConstraint,getconstraints(si)) && deleteat!(llis, length(llis))
    return llis
end

# multilayer GoThrough intents could be added here
"$(TYPEDSIGNATURES) Get low level intents for `LightpathIntent` `lpi`"
function lowlevelintents(lpi::LightpathIntent)
    llis = [NodeRouterPortIntent(lpi.path[1], getrate(lpi.transmodl)), NodeTransmoduleIntent(lpi.path[1], lpi.transmodl), 
            NodeTransmoduleIntent(lpi.path[end], lpi.transmodl), NodeRouterPortIntent(lpi.path[end], getrate(lpi.transmodl)),]
    any(c -> c isa BorderTerminateConstraint, getconstraints(lpi)) && deleteat!(llis, [3,4])
    any(c -> c isa BorderInitiateConstraint,getconstraints(lpi)) && deleteat!(llis, [1,2])
    return llis
end

