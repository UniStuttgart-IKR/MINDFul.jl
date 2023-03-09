"$(TYPEDSIGNATURES) Get low level intents for `PathIntent` `pt`"
function lowlevelintents(pt::PathIntent)
    [NodeRouterPortIntent(nd, 100.0) for nd in [pt.path[1], pt.path[end]]]
end

# Terminate for HalfFiberIn ?
"$(TYPEDSIGNATURES) Get low level intents for `SpectrumIntent` `si`"
function lowlevelintents(si::SpectrumIntent)
    # TODO 06.03.2023
    lightpathedges = edgeify(si.lightpath)
    spllis = [let
                ind = (il-1)*2 + iv
                if ind == 1
                    NodeSpectrumIntent(nd, e, si.spectrumalloc, getrate(si), signalOXCAdd) 
                elseif ind == length(lightpathedges) * 2
                    NodeSpectrumIntent(nd, e, si.spectrumalloc, getrate(si), signalOXCDrop) 
                else
                    NodeSpectrumIntent(nd, e, si.spectrumalloc, getrate(si), signalOXCbypass) 
                end
            end
            for (il,e) in enumerate(lightpathedges) for (iv,nd) in enumerate([src(e), dst(e)])]

    rmllis = generateroadmllis(spllis)

    if any(c -> c isa BorderInitiateConstraint,getconstraints(si))
        deleteat!(spllis, 1)
        deleteat!(rmllis, 1)
    end
    if any(c -> c isa BorderTerminateConstraint,getconstraints(si))
        deleteat!(spllis, length(spllis))
        deleteat!(rmllis, length(rmllis))
    end
    return vcat(spllis, rmllis)
end

function generateroadmllis(spllis::Vector{<:NodeSpectrumIntent})
    [ let
        if sp.sptype == signalOXCAdd
            NodeROADMIntent(getnode(sp), missing, sp.edge, sp.slots)
        elseif sp.sptype == signalOXCDrop
            NodeROADMIntent(getnode(sp), sp.edge, missing, sp.slots)
        elseif sp.sptype == signalOXCbypass
            prsp = spllis[i-1]
            if prsp.sptype == signalOXCbypass && getnode(prsp) == getnode(sp) && prsp.slots == sp.slots
                NodeROADMIntent(getnode(sp), prsp.edge, sp.edge, sp.slots)
            else
                missing
            end
        else
            missing
        end
     end for (i,sp) in enumerate(spllis)] |> skipmissing |> collect
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

