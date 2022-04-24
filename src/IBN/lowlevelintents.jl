function lowlevelintents(ibn::IBN, pt::PathIntent)
    [NodeRouterIntent(nd, 1) for nd in [pt.path[1], pt.path[end]]]
end

function lowlevelintents(ibn::IBN, si::SpectrumIntent)
    [NodeSpectrumIntent(nd, e, si.spectrumalloc, si.drate) for e in edgeify(si.lightpath) for nd in [e.src, e.dst]]
end
