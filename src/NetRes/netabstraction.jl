getmlnode(sdn::SDN, i::Integer) = getmlnode(getgraph(sdn), i)
getmlnode(ibn::IBN, i::Integer) = getmlnode(ibn.ngr, i)
getmlnode(graph, i::Integer) = get_prop(graph, i, :mlnode)
getrouter(graph, i::Integer) = getrouter(getmlnode(graph,i))
getoxc(graph, i::Integer) = getoxc(getmlnode(graph,i))

getlink(x, e::Edge) = getlink(x, src(e), dst(e))
getlink(ibn::IBN, i::Integer, j::Integer) = getlink(ibn.ngr, i, j)
getlink(sdn::SDN, i::Integer, j::Integer) = getlink(getgraph(sdn), i, j)
getlink(graph, i::Integer, j::Integer) = get_prop(graph, i, j, :link)

hasport(rt::RouterView) = any(rt.portavailability)
availableports(rt::RouterView) = count(rt.portavailability)

hastransmissionmodule(mln::MLNode, transmodl::TransmissionModuleView) = any(x -> iscompatible(transmodl, x), mln.transmodulespool)
usetransmissionmodule!(mln::MLNode, transmodl::TransmissionModuleView, ibnintid::Tuple{Int,UUID}) = let; push!(mln.transmodreservations, (transmodl, ibnintid)); return true; end
function freetransmissionmodule!(mln::MLNode, transmodl::TransmissionModuleView, ibnintid::Tuple{Int,UUID})
    num = length(mln.transmodreservations)
    filter!(!=((transmodl, ibnintid)), mln.transmodreservations)
    length(mln.transmodreservations) < num ? true : false
end

function reserveroadmswitch!(oxc::OXCView, inedge::Union{Edge,Missing}, outedge::Union{Edge,Missing}, slots::UnitRange{Int}, intidx::Tuple{Int, UUID})
    inedidx = ismissing(inedge) ? 0 : findfirst(==(inedge), oxc.inedges)
    outedidx = ismissing(outedge) ? 0 : findfirst(==(outedge), oxc.outedges)
    (isnothing(inedidx) || isnothing(outedidx)) && error("Did not find edge in OXC")
    _isavailableroadmswitch(oxc, inedidx, outedidx, slots) || error("not available slots in OXC")
    push!(oxc.switchconf, (inedidx, outedidx, slots))
    push!(oxc.reservations, intidx)
    return true
end

function isavailableroadmswitch(oxc::OXCView, inedge::Union{Edge,Missing} ,outedge::Union{Edge,Missing}, slots::UnitRange{Int})
    inedidx = ismissing(inedge) ? 0 : findfirst(==(inedge), oxc.inedges)
    outedidx = ismissing(outedge) ? 0 : findfirst(==(outedge), oxc.outedges)
    (isnothing(inedidx) || isnothing(outedidx)) && error("Did not find edge in OXC")
    isav =  _isavailableroadmswitch(oxc, inedidx, outedidx, slots)
    return isav
end

function _isavailableroadmswitch(oxc::OXCView, inedidx::Int, outedidx::Int, slots::UnitRange{Int})
    isavailable = true
    for sc in oxc.switchconf
        doublebreak = false
        for (i,edgidx) = enumerate([inedidx, outedidx])
            if edgidx == sc[i] !== 0
                if any(slots .∈ [sc[3]])
                    isavailable = false
                    doublebreak = true
                    break
                end
            end
        end
        doublebreak && break
    end
    return isavailable
end

function freeroadmswitch!(oxc::OXCView, intidx::Tuple{Int, UUID})
    ff = findfirst(==(intidx), oxc.reservations)
    isnothing(ff) && error("Intent in OXC is not found")
    deleteat!(oxc.switchconf, ff)
    deleteat!(oxc.reservations, ff)
end

"""
$(TYPEDSIGNATURES) Checks wether `rt` has a port with rate bigger or equal to `rate`
"""
function hasport(rt::RouterView, rate::Float64)
    any(enumerate(rt.portavailability)) do (portidx, portavail)
        portavail && rate <= getportrate(rt, portidx)
    end
end

"""
$(TYPEDSIGNATURES)

Use a port in Router `rt` to serve an intent described by the `Tuple` `ibnintid`.
"""
function useport!(rt::RouterView, ibnintid::Tuple{Int,UUID})
    ff = findfirst(==(true), rt.portavailability)
    if ff !==nothing
        rt.portavailability[ff] = false
        rt.reservations[ff] = ibnintid
        return true
    end
    return false
end

"""
$(TYPEDSIGNATURES)

Use a port in Router `rt` to serve an intent described by the `Tuple` `ibnintid`.
"""
function useport!(rt::RouterView, portidx::Int, ibnintid::Tuple{Int,UUID})
    if rt.portavailability[portidx] == true
        rt.portavailability[portidx] = false
        rt.reservations[portidx] = ibnintid
        return true
    end
    return false
end

"""
$(TYPEDSIGNATURES)

Free a port in Router `rt` from serving an intent described by the `Tuple` `ibnintid`.
"""
function freeport!(rt::RouterView, ibnintid::Tuple{Int,UUID})
    fall = findall(==(ibnintid), skipmissing(rt.reservations))
    for ff in fall
        rt.portavailability[ff] = true
        rt.reservations[ff] = missing
    end
    return true
end

"""
$(TYPEDSIGNATURES)

Free the port `portidx` in Router `rt` from serving an intent `intidx`.
"""
function freeport!(rt::RouterView, portidx::Int, intidx)
    rt.portavailability[portidx] = true
    rt.reservations[portidx] = missing
    return true
end

"$(TYPEDSIGNATURES) Get length of the fiber `fv`"
getdistance(fv::F) where {F<:FiberView} = getdistance(fv.fiber)
function getspectrumslots(fv::F) where {F<:FiberView}
    @assert fv.spectrum_src == fv.spectrum_dst
    fv.spectrum_src .& fv.spectrum_dst
end
delay(fv::FiberView) = 5u"ns/km" * getdistance(fv)

"""
$(TYPEDSIGNATURES)

Check if there are `nslots` available slots in `f`.
"""
function hasslots(f::FiberView, nslots::Int)
    freeslots = 0
    for (slots_av_src, slots_av_dst) in zip(f.spectrum_src, f.spectrum_dst)
        if slots_av_src && slots_av_dst
            freeslots += 1
            if freeslots == nslots
                return true
            end
        else
            freeslots = 0
        end
    end
    return false
end
hasslots(f::FiberView, sr::UnitRange{Int}) = all(vcat(f.spectrum_src[sr], f.spectrum_dst[sr]))

"""
$(TYPEDSIGNATURES)

Use slots `channel` in fiber `f` for serving intent `ibnintid`.
If `reserve_src=true` use the slots in the `src`. Else in the `dst`.
"""
function useslots!(f::FiberView, channel::UnitRange{Int}, ibnintid::Tuple{Int,UUID}, reserve_src::Bool)
    for i in channel
        if reserve_src
            if !f.spectrum_src[i]
                @warn("Some slots are already allocated. Reverting.")
                for j in channel.start:i-1
                    f.spectrum_src[j] = true
                end
                return false
            end
            f.spectrum_src[i] = false
            f.reservations_src[i] = ibnintid
        else
            if !f.spectrum_dst[i]
                @warn("Some slots are already allocated. Reverting.")
                for j in channel.start:i-1
                    f.spectrum_dst[j] = true
                end
                return false
            end
            f.spectrum_dst[i] = false
            f.reservations_dst[i] = ibnintid
        end
    end
    return true
end

"""
$(TYPEDSIGNATURES)

Free slots `channel` in fiber `f` for serving intent `ibnintid`.
If `reserve_src=true` free the slots in the `src`. Else in the `dst`.
"""
function freeslots!(f::FiberView, channel::UnitRange{Int}, ibnintid::Tuple{Int,UUID}, reserve_src::Bool)
    for i in channel
        if reserve_src
            f.spectrum_src[i] && @warn("Some slots are already unused")
            f.spectrum_src[i] = true
            f.reservations_src[i] = missing
        else
            f.spectrum_dst[i] && @warn("Some slots are already unused")
            f.spectrum_dst[i] = true
            f.reservations_dst[i] = missing
        end
    end
    return true
end

"""
$(TYPEDSIGNATURES)

Return number of reserved slots
"""
function reservedslots(f::FiberView)
    @assert all(.!ismissing(f.reservations_src) .== .!ismissing(f.reservations_dst))
    count(!ismissing ,f.reservations_src)
end

function firstfit(spec, nslots::Int)
    freeslots = 0
    for (i, slotsava) in enumerate(spec)
        if slotsava
            freeslots += 1
            if freeslots == nslots
                return i-freeslots+1
            end
        else
            freeslots = 0
        end
    end
    return nothing
end

"$(TYPEDSIGNATURES) Using the first fit algorithm find `nslots` consequitive slots in `f`"
firstfit(f::FiberView, nslots::Int) = firstfit(f.spectrum_src .& f.spectrum_dst, nslots)

function firstfit(fs::Vector{F}, nslots::Int) where {F<:FiberView}
    spectrums_src = getfield.(fs, :spectrum_src)
    spectrums_dst = getfield.(fs, :spectrum_dst)
    avspectrum_src = reduce(.&, spectrums_src)
    avspectrum_dst = reduce(.&, spectrums_dst)
    firstfit(avspectrum_src .& avspectrum_dst, nslots)
end

#
#-------------------- Network Faults ----------------------
#

"$(TYPEDSIGNATURES) Check if `fc` operates correctly."
doesoperate(fv::FiberView) = fv.operates

"$(TYPEDSIGNATURES) Set fiber `device` of `ibn` at status `status` in time `time`. Use `forcelog` to force or not a logging."
function set_operation_status!(ibn::IBN, device::FiberView, status::Bool; time, forcelog=false)
    if device.operates != status || forcelog
        device.operates = status
        push!(device.logstate, (time, device.operates))

        # trigger intent monitoring from reservations
        intentidxs = skipmissing(unique(vcat(device.reservations_src,device.reservations_dst)))
        for intentidx in intentidxs
#            ibn.id == intentidx[1] || @warn("Device has been configured from a foreign IBN and cannot be notified of the status change")
            remibn = getibn(ibn, intentidx[1])
            idn = getintent(remibn, intentidx[2])[intentidx[3]]
            dag = getintent(remibn, intentidx[2])
            if status
                setstate!(idn, dag, remibn, Val(installed); time)
            else
                setstate!(idn, dag, remibn, Val(failure); time)
            end
        end
    end
end
