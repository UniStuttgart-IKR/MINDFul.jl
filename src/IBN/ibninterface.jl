#function isavailable(ibn::IBN{T}, path::Vector{Int}, capacity::Real) where T<:SDN
#    available = true
#    (sdns, paths) = breakdown(ibn, path)
#    for (sdn,path) in zip(sdns, paths)
#        available = available && isavailable(sdn, path, capacity)
#        available || return false
#    end
#    # interSDN
#    ceds = CompositeGraphs.compositeedge.([ibn.cgr], filter(x -> !CompositeGraphs.issamedomain(ibn.cgr, x), [e for e in edgeify(path)]))
#    for ce in ceds
#        available = available && isavailable(ibn.controllers[ce.src[1]], ibn.controllers[ce.dst[1]], ce, capacity)
#        available || return false
#    end
#    return available
#end

function isavailable(ibn::IBN, path::Vector{Int}, capacity::Real)
    for e in edgeify(path)
       isavailable(breakdown(ibn, e)..., capacity) || return false
    end
    return true
end
function reserve(ibn::IBN, path::Vector{Int}, capacity::Real)
    for e in edgeify(path)
       reserve(breakdown(ibn, e)..., capacity) || return false
    end
    return true
end


function breakdown(ibn::IBN, e::Edge)
    controllerofnodesrc = controllerofnode(ibn, e.src)
    controllerofnodedst = controllerofnode(ibn, e.dst)
    if controllerofnodesrc == controllerofnodedst
        #intradomain
        return (controllerofnodesrc, domainedge(ibn.cgr, e))
    else
        #interdomain
        if controllerofnodesrc isa IBN || controllerofnodedst isa IBN
            if controllerofnodesrc isa IBN
                cesrc = (getid(controllerofnodesrc), ibn.cgr.vmap[e.src][2])
                ibnsrc = controllerofnodesrc
            else
                cesrc = (getid(ibn), e.src)
                ibnsrc = ibn
            end
            if controllerofnodedst isa IBN
                cedst = (getid(controllerofnodedst), ibn.cgr.vmap[e.dst][2])
                ibndst = controllerofnodedst
            else
                cedst = (getid(ibn), e.dst)
                ibndst = ibn
            end
            ce = CompositeEdge(cesrc, cedst)
            return (ibnsrc, ibndst, ce)
        else
            return (controllerofnodesrc, controllerofnodedst, compositeedge(ibn.cgr, e))
        end
    end
end

"Break down a IBN path to the SDN paths"
function breakdown(ibn::IBN{T}, path::Vector{Int}) where T<:SDN
    dom = ibn.cgr.vmap[path[1]][1]
    sdns = Vector{T}([ibn.controllers[dom]])
    paths = Vector{Vector{Int}}([Vector{Int}()])
    for p in path
        domnext = ibn.cgr.vmap[p][1]
        if domnext != dom
            dom = domnext
            push!(sdns, ibn.controllers[dom])
            push!(paths, Vector{Int}())
        end
        push!(paths[end], ibn.cgr.vmap[p][2])
    end
    return (sdns, paths)
end

"""
Check edge availability between 2 controllers:
- capacity on edge
- port in nodes
"""
function isavailable(con1::IBN, con2::IBN, ce::CompositeEdge, capacity::Real)
    isavailable(ibns2sdns(con1, con2, ce, capacity)...)
end

"""
Reserve resources between 2 controllers
"""
function reserve(con1::IBN, con2::IBN, ce::CompositeEdge, capacity::Real)
    reserve(ibns2sdns(con1, con2, ce, capacity)...)
end

function ibns2sdns(ibn1::IBN, ibn2::IBN, ce::CompositeEdge, capacity)
    src = ce.src
    dst = ce.dst

    src = ibn1.cgr.vmap[ce.src[2]]
    sdn1 = controllerofnode(ibn1, ce.src[2])
    srcintrasdn = src

    dstnode = ce.dst[2]
    dstdom = findfirst(x -> x == ibn2, ibn1.controllers)
    dst = (dstdom, dstnode)
    sdn2 = controllerofnode(ibn2, ce.dst[2])
    dstintrasdn = ibn2.cgr.vmap[ce.dst[2]]

    ce = CompositeEdge(src, dst)
    ceintrasdn = CompositeEdge(srcintrasdn, dstintrasdn)
    return (sdn1, sdn2, ce, capacity, ceintrasdn)
end

function delegateinheritcompilation!(ibnp::IBN, ibnc::IBN, intr::IntentTree, remintent::Intent, algmethod; algargs...)
    success = false
    remintr = addchild!(intr, remintent)
    remidx = addintent(ibnp, ibnc, newintent(remintr.data))
    setcompilation!(remintent, RemoteIntentCompilation(ibnc, remidx))
    success = deploy!(ibnp, ibnc, remidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), algmethod; algargs...)
    success && setstate!(remintr, compiled)
    return success
end

function delegatecompilation!(ibnp::IBN, ibnc::IBN, intr::IntentTree, algmethod; algargs...)
    success = false
    remidx = addintent(ibnp, ibnc, newintent(intr.data))
    setcompilation!(intr, RemoteIntentCompilation(ibnc, remidx))
    success = deploy!(ibnp, ibnc, remidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), algmethod; algargs...)
    success && setstate!(intr, compiled)
    return success
end
