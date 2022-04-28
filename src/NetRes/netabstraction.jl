hasport(rt::RouterView) = any(rt.portavailability)
availableports(rt::RouterView) = count(rt.portavailability)
function useport!(rt::RouterView, ibnintid::Tuple{Int,Int,UUID})
    ff = findfirst(==(true), rt.portavailability)
    if ff !==nothing
        rt.portavailability[ff] = false
        rt.reservations[ff] = ibnintid
        return true
    end
    return false
end

function freeport!(rt::RouterView, ibnintid::Tuple{Int, Int})
    ff = findfirst(==(ibnintid), rt.reservations)
    if ff !==nothing
        rt.portavailability[ff] = true
        rt.reservations[ff] = missing
    end
    return true
end

function freeport!(rt::RouterView, portidx::Int)
    rt.portavailability[portidx] = true
    rt.reservations[portidx] = missing
    return true
end

distance(fv::F) where {F<:FiberView} = distance(fv.fiber)
delay(fv::FiberView) = 5u"ns/km" * distance(fv)
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

function useslots!(f::FiberView, channel::UnitRange{Int}, ibnintid::Tuple{Int,Int,UUID}, reserve_src::Bool)
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

firstfit(f::FiberView, nslots::Int) = firstfit(f.spectrum_src .& f.spectrum_dst, nslots)

function firstfit(fs::Vector{F}, nslots::Int) where {F<:FiberView}
    spectrums_src = getfield.(fs, :spectrum_src)
    spectrums_dst = getfield.(fs, :spectrum_dst)
    avspectrum_src = reduce(.&, spectrums_src)
    avspectrum_dst = reduce(.&, spectrums_dst)
    firstfit(avspectrum_src .& avspectrum_dst, nslots)
end
