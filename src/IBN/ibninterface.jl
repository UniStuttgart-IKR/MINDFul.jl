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
        node = ibn.cgr.vmap[n][2]
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
        return (;sdn1=controllerofnodesrc, sdn2=nothing, ce=domainedge(ibn.cgr, e), ceintra=nothing)
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
            return ibns2sdns(ibnsrc, ibndst, ce)
        else
            return ibns2sdns(controllerofnodesrc, controllerofnodedst, compositeedge(ibn.cgr, e))
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

ibns2sdns(args...) = args
function ibns2sdns(ibn1::IBN, ibn2::IBN, ce::CompositeEdge)
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
    return (;sdn1=sdn1, sdn2=sdn2, ce=ce, ceintra=ceintrasdn)
end

"C"
function delegateintent!(ibnp::IBN, ibnc::IBN, intr::IntentDAGNode, remintent::Intent, algmethod; algargs...)
    success = false
    remintr = addchild!(intr, remintent)
    ibnpissuer = IBNIssuer(getid(ibnp), getindex(intr))
    remidx = addintent!(ibnpissuer, ibnc, newintent(remintr.data))
    addchild!(remintent, RemoteIntent(ibnc, remidx))
    success = deploy!(ibnp, ibnc, remidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), algmethod; algargs...)
    success && setstate!(remintr, compiled)
    return success
end

function delegateintent!(ibnp::IBN, ibnc::IBN, intr::IntentDAGNode, algmethod; algargs...)
    success = false
    ibnpissuer = IBNIssuer(getid(ibnp), getindex(intr))
    remidx = addchild!(ibnpissuer, ibnc, newintent(intr.data))
    addchild!(intr, RemoteIntent(ibnc, remidx))
    success = deploy!(ibnp, ibnc, remidx, IBNFramework.docompile, IBNFramework.SimpleIBNModus(), algmethod; algargs...)
    success && setstate!(intr, compiled)
    return success
end
