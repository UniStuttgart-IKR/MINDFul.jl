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
    for slotisavailable in f.spectrum
        if slotisavailable
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
hasslots(f::FiberView, sr::UnitRange{Int}) = all(f.spectrum[sr])

function useslots!(f::FiberView, channel::UnitRange{Int}, ibnintid::Tuple{Int,Int,UUID})
    for i in channel
        if f.spectrum[i] == false
            @warn("Some slots are already allocated. Reverting.")
            for j in channel.start:i-1
                f.spectrum[j] = true
            end
            return false
        end
        f.spectrum[i] = false
        f.reservations[i] = ibnintid
    end
    return true
end

function useslots!(f::FiberView, nslots::Int, allocationmethod::F=firstfit) where F<:Function
    slotidx = firstfit(f, nslots)
    if slotidx !== nothing
        for i in slotidx:nslots+slotidx-1
            f.spectrum[i] = false
        end
        return true
    else
        return false
    end
end

function firstfit(spec, nslots::Int)
    freeslots = 0
    for (i,slotisavailable) in enumerate(spec)
        if slotisavailable
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

firstfit(f::FiberView, nslots::Int) = firstfit(f.spectrum, nslots)

function firstfit(fs::Vector{F}, nslots::Int) where {F<:FiberView}
    spectrums = getfield.(fs, :spectrum)
    avspectrum = reduce(.&, spectrums)
    firstfit(avspectrum, nslots)
end
