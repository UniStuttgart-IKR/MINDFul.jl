"$(TYPEDSIGNATURES) Get low level intents for `PathIntent` `pt`"
function lowlevelintents(pt::PathIntent)
    [NodeRouterIntent(nd, 1) for nd in [pt.path[1], pt.path[end]]]
end

"$(TYPEDSIGNATURES) Get low level intents for `SpectrumIntent` `si`"
function lowlevelintents(si::SpectrumIntent)
    [NodeSpectrumIntent(nd, e, si.spectrumalloc, si.drate) for e in edgeify(si.lightpath) for nd in [e.src, e.dst]]
end
