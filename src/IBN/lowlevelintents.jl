"$(TYPEDSIGNATURES) Get low level intents for `PathIntent` `pt`"
function lowlevelintents(pt::PathIntent)
    [NodeRouterPortIntent(nd, 100.0) for nd in [pt.path[1], pt.path[end]]]
end

"$(TYPEDSIGNATURES) Get low level intents for `SpectrumIntent` `si`"
function lowlevelintents(si::SpectrumIntent)
    [NodeSpectrumIntent(nd, e, si.spectrumalloc, si.drate) for e in edgeify(si.lightpath) for nd in [e.src, e.dst]]
end

"$(TYPEDSIGNATURES) Get low level intents for `LightpathIntent` `lpi`"
function lowlevelintents(lpi::LightpathIntent)
    [NodeRouterPortIntent(lpi.path[1], getrate(lpi.transmodl)), NodeRouterPortIntent(lpi.path[end], 1getrate(lpi.transmodl)), 
     NodeTransmoduleIntent(lpi.path[1], lpi.transmodl), NodeTransmoduleIntent(lpi.path[end], lpi.transmodl)]
end

