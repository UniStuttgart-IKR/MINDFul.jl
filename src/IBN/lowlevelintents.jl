"$(TYPEDSIGNATURES) Get low level intents for `PathIntent` `pt`"
function lowlevelintents(pt::PathIntent)
    [NodeRouterPortIntent(nd, 100.0) for nd in [pt.path[1], pt.path[end]]]
end

# Terminate for HalfFiberIn ?
"$(TYPEDSIGNATURES) Get low level intents for `SpectrumIntent` `si`"
function lowlevelintents(si::SpectrumIntent)
    llis = [NodeSpectrumIntent(nd, e, si.spectrumalloc, getrate(si)) for e in edgeify(si.lightpath) for nd in [src(e), dst(e)]]
    if any(c -> c isa BorderInitiateConstraint,getconstraints(si))
        llis[2:end]
    elseif any(c -> c isa BorderTerminateConstraint,getconstraints(si))
        llis[1:end-1]
    else any(c -> c isa BorderInitiateConstraint,getconstraints(si))
        llis
    end
end

# multilayer GoThrough intents could be added here
"$(TYPEDSIGNATURES) Get low level intents for `LightpathIntent` `lpi`"
function lowlevelintents(lpi::LightpathIntent)
    if any(c -> c isa BorderInitiateConstraint,getconstraints(lpi))
        [NodeRouterPortIntent(lpi.path[end], 1getrate(lpi.transmodl)), NodeTransmoduleIntent(lpi.path[end], lpi.transmodl)]
    elseif any(c -> c isa BorderTerminateConstraint, getconstraints(lpi))
        [NodeRouterPortIntent(lpi.path[1], getrate(lpi.transmodl)), NodeTransmoduleIntent(lpi.path[1], lpi.transmodl)]
    else
        [NodeRouterPortIntent(lpi.path[1], getrate(lpi.transmodl)), NodeRouterPortIntent(lpi.path[end], 1getrate(lpi.transmodl)), 
         NodeTransmoduleIntent(lpi.path[1], lpi.transmodl), NodeTransmoduleIntent(lpi.path[end], lpi.transmodl)]
    end
end

