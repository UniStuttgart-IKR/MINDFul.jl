"$(TYPEDSIGNATURES) Get total distance of `path` in `ibn`"
getdistance(ibn::IBN, path::Vector{Int}) = sum(getdistance(get_prop(ibn.ngr, l, :link)) for l in edgeify(path))

"$(TYPEDSIGNATURES) Uninstall, uncompile and delete all intents of `ibn`"
function purgeintent!(ibn::IBN, intentidx::Int; time)
    deploy!(ibn, intentidx, MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time)
    deploy!(ibn, intentidx, MINDFul.douncompile, MINDFul.SimpleIBNModus(), () -> nothing; time)
    remintent!(ibn, intentidx)
end

"$(TYPEDSIGNATURES) Uninstall and uncompile intent `intentidx` in `ibn`"
function restartintent!(ibn::IBN, intentidx::Int; time)
    deploy!(ibn, intentidx, MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time)
    deploy!(ibn, intentidx, MINDFul.douncompile, MINDFul.SimpleIBNModus(); time)
end

"$(TYPEDSIGNATURES) Uninstall all intents in `ibn`"
function uninstallallintents!(ibn::IBN; time)
    for dag in ibn.intents
        deploy!(ibn, getid(dag), MINDFul.douninstall, MINDFul.SimpleIBNModus(), MINDFul.directuninstall!; time)
    end
end

"$(TYPEDSIGNATURES) Checks if `ibn` has reserved something due to an intent or not"
function anyreservations(ibn)
    routers = [getrouter(ibn, v) for v in getmynodes(ibn)]
    portreservations = getfield.(routers, :reservations)
    totalavailable = all(ismissing, reduce(vcat, portreservations))
    totalavailable || return true

    portavailables = getfield.(routers, :portavailability)
    totalavailable = all(==(true), reduce(vcat, portavailables))
    totalavailable || return true

    mlnodes = [getmlnode(ibn, v) for v in getmynodes(ibn)]
    all(isempty, gettransmodreservations.(mlnodes)) || return true

    links = [get_prop(ibn.ngr, e.src, e.dst, :link) for e in edges(ibn.ngr) if has_prop(ibn.ngr, e.src, e.dst, :link)]
    slotreservations = vcat(getfield.(links, :reservations_src), getfield.(links, :reservations_dst))
    totalavailable = all(ismissing, reduce(vcat, slotreservations))
    totalavailable || return true

    slotavailables = vcat(getfield.(links, :spectrum_src), getfield.(links, :spectrum_dst))
    totalavailable = all(==(true), reduce(vcat, slotavailables))
    totalavailable || return true

    return false
end

getdistance(ibn::IBN, path::Vector{T}) where T<:Integer = sum([getdistance(getlink(ibn, e)) for e in edgeify(path) if has_edge(ibn.ngr, e)])
