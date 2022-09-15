function isavailable(ibn::IBN, path::Vector{Int}, reqs...)
    for e in edgeify(path)
       isavailable(breakdown(ibn, e)..., reqs...) || return false
    end
    return true
end
function reserve(ibn::IBN, ibnintid::Tuple{Int,Int}, path::Vector{Int}, reqs...)
    for e in edgeify(path)
       reserve(breakdown(ibn, e)..., reqs...) || return false
    end
    return true
end

function reserve(ibn::IBN, ibnintid::Tuple{Int,Int}, optpath::Vector{OpticalCircuit}, reqs...)
    for optcirc in optpath
        # reserve node port
        src = optcirc.path[1]
        portnum = reserve_routerport(controllerofnode(ibn, src), ibnintid, src)
        # reserve optical edges (not ports)
        for optedg in edgeify(optcirc.path)
            reserve(reserve_fiber, ibnintid, optcirc.props; breakdown(ibn, optedg)...)
        end
        # reserve node port
        dst = optcirc.path[end]
        portnum = reserve_routerport(controllerofnode(ibn, dst), ibnintid, src)
    end
    return true
end

function breakdown(ibn::IBN, n::Int)
    controller = controllerofnode(ibn, n)
    if controller isa IBN
        node = ibn.ngr.vmap[n][2]
        ibnsrc = controllerofnodesrc
    else
        cesrc = (getid(ibn), e.src)
        ibnsrc = ibn
    end
end

function breakdown(ibn::IBN, e::Edge)
    controllerofnodesrc = controllerofnode(ibn, e.src)
    controllerofnodedst = controllerofnode(ibn, e.dst)
    if controllerofnodesrc == controllerofnodedst
        #intradomain
        return (;sdn1=controllerofnodesrc, sdn2=nothing, ce=domainedge(ibn.ngr, e), ceintra=nothing)
    else
        #interdomain
        if controllerofnodesrc isa IBN || controllerofnodedst isa IBN
            if controllerofnodesrc isa IBN
                cesrc = (getid(controllerofnodesrc), ibn.ngr.vmap[e.src][2])
                ibnsrc = controllerofnodesrc
            else
                cesrc = (getid(ibn), e.src)
                ibnsrc = ibn
            end
            if controllerofnodedst isa IBN
                cedst = (getid(controllerofnodedst), ibn.ngr.vmap[e.dst][2])
                ibndst = controllerofnodedst
            else
                cedst = (getid(ibn), e.dst)
                ibndst = ibn
            end
            ce = NestedEdge(cesrc, cedst)
            return ibns2sdns(ibnsrc, ibndst, ce)
        else
            return ibns2sdns(controllerofnodesrc, controllerofnodedst, nestededge(ibn.ngr, e))
        end
    end
end

"Break down a IBN path to the SDN paths"
function breakdown(ibn::IBN{T}, path::Vector{Int}) where T<:SDN
    dom = ibn.ngr.vmap[path[1]][1]
    sdns = Vector{T}([ibn.controllers[dom]])
    paths = Vector{Vector{Int}}([Vector{Int}()])
    for p in path
        domnext = ibn.ngr.vmap[p][1]
        if domnext != dom
            dom = domnext
            push!(sdns, ibn.controllers[dom])
            push!(paths, Vector{Int}())
        end
        push!(paths[end], ibn.ngr.vmap[p][2])
    end
    return (sdns, paths)
end

"""
Check edge availability between 2 controllers:
- capacity on edge
- port in nodes
"""
function isavailable(con1::IBN, con2::IBN, ce::NestedEdge, capacity::Real)
    isavailable(ibns2sdns(con1, con2, ce, capacity)...)
end

"""
Reserve resources between 2 controllers
"""
function reserve(con1::IBN, con2::IBN, ce::NestedEdge, capacity::Real)
    reserve(ibns2sdns(con1, con2, ce, capacity)...)
end

ibns2sdns(args...) = args
function ibns2sdns(ibn1::IBN, ibn2::IBN, ce::NestedEdge)
    src = ce.src
    dst = ce.dst

    src = ibn1.ngr.vmap[ce.src[2]]
    sdn1 = controllerofnode(ibn1, ce.src[2])
    srcintrasdn = src

    dstnode = ce.dst[2]
    dstdom = findfirst(x -> x == ibn2, ibn1.controllers)
    dst = (dstdom, dstnode)
    sdn2 = controllerofnode(ibn2, ce.dst[2])
    dstintrasdn = ibn2.ngr.vmap[ce.dst[2]]

    ce = NestedEdge(src, dst)
    ceintrasdn = NestedEdge(srcintrasdn, dstintrasdn)
    return (;sdn1=sdn1, sdn2=sdn2, ce=ce, ceintra=ceintrasdn)
end

"Delegates intent and triggers its compilation"
function delegateintent!(ibnc::IBN, ibns::IBN, dag::IntentDAG, idn::IntentDAGNode, remintent::Intent, algmethod; algargs...)
    remintr = addchild!(dag, getid(idn), remintent)
    ibnpissuer = IBNIssuer(getid(ibnc), getid(dag), getid(idn))
    remidx = addintent!(ibnpissuer, ibns, getintent(remintr))
    addchild!(dag, getid(remintr), RemoteIntent(getid(ibns), remidx))
    return deploy!(ibnc, ibns, remidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), algmethod; algargs...)
end

function setstate!(ibnc::IBN, ibns::IBN, intentibnid::Int, intentidx::Int, state::IntentState; time)
    #check all intents of all dags if there is a RemoteIntent(intentibnid, intentidx)
    # TODO just use IntentIssuer ?
    rmintent = RemoteIntent(intentibnid, intentidx)
    for dag in ibnc.intents
        # TODO don't search all but only what's on IBNIssuer
        rmis = filter(x -> x.intent==rmintent, descendants(dag))
        for rmi in rmis
            setstate!(rmi, dag, ibnc, state; time)
        end
    end
end

function delegate_edgeintents(ibn, dag, idn, interconstraints, compmethod)
    length(interconstraints) > 1 && @warn "Intent issues multiple EdgeIntents"
    for kvpair in interconstraints
        ei = EdgeIntent(kvpair.second)
        ibnserver = getibn(ibn, kvpair.first)
        delegateintent!(ibn, ibnserver, dag, idn, ei, compmethod)
    end
end

function delegate_edgeintent(ibn, dag, idn, kvpair, compmethod; time)
    ei = EdgeIntent(kvpair.second)
    ibnserver = getibn(ibn, kvpair.first)
    delegateintent!(ibn, ibnserver, dag, idn, ei, compmethod; time)
end

function anyreservations(ibn)
    routers = [get_prop(ibn.ngr, v, :router) for v in vertices(ibn.ngr) if has_prop(ibn.ngr, v, :router)]
    portreservations = getfield.(routers, :reservations)
    totalavailable = all(ismissing, reduce(vcat, portreservations))
    totalavailable || return true

    portavailables = getfield.(routers, :portavailability)
    totalavailable = all(==(true), reduce(vcat, portavailables))
    totalavailable || return true

    links = [get_prop(ibn.ngr, e.src, e.dst, :link) for e in edges(ibn.ngr) if has_prop(ibn.ngr, e.src, e.dst, :link)]
    slotreservations = vcat(getfield.(links, :reservations_src), getfield.(links, :reservations_dst))
    totalavailable = all(ismissing, reduce(vcat, slotreservations))
    totalavailable || return true

    slotavailables = vcat(getfield.(links, :spectrum_src), getfield.(links, :spectrum_dst))
    totalavailable = all(==(true), reduce(vcat, slotavailables))
    totalavailable || return true

    return false
end
