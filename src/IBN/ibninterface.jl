##
# This file defines the interface used between the different IBN domains.
##

"$(TYPEDSIGNATURES) Check if `path` under requirements `reqs` is available in `ibn`"
function isavailable(ibn::IBN, path::Vector{Int}, reqs...)
    for e in edgeify(path)
       isavailable(breakdown(ibn, e)..., reqs...) || return false
    end
    return true
end

"""
$(TYPEDSIGNATURES)

The `ibn` reserves the path `path` udner requirements `regs` as requested by the `ibnintid`, i.e., `(IBN_ID, INTENT_ID).`
"""
function reserve!(ibn::IBN, ibnintid::Tuple{Int,Int}, path::Vector{Int}, reqs...)
    for e in edgeify(path)
       reserve!(breakdown(ibn, e)..., reqs...) || return false
    end
    return true
end

"""
$(TYPEDSIGNATURES)

The `ibn` reserves the optical path `optpath` udner requirements `regs` as requested by the `ibnintid`, i.e., `(IBN_ID, INTENT_ID).`
"""
function reserve!(ibn::IBN, ibnintid::Tuple{Int,Int}, optpath::Vector{OpticalCircuit}, reqs...)
    for optcirc in optpath
        # reserve! node port
        src = optcirc.path[1]
        portnum = reserve_routerport(controllerofnode(ibn, src), ibnintid, src)
        # reserve! optical edges (not ports)
        for optedg in edgeify(optcirc.path)
            reserve!(reserve_fiber, ibnintid, optcirc.props; breakdown(ibn, optedg)...)
        end
        # reserve! node port
        dst = optcirc.path[end]
        portnum = reserve_routerport(controllerofnode(ibn, dst), ibnintid, src)
    end
    return true
end

"$(TYPEDSIGNATURES) Get the responsible controllers for the edge `e` and the local view of the nodes invlolved."
function breakdown(ibn::IBN, e::Edge)
    controllerofnodesrc = controllerofnode(ibn, e.src)
    controllerofnodedst = controllerofnode(ibn, e.dst)
    if controllerofnodesrc == controllerofnodedst
        #intradomain
        return (;sdn1=controllerofnodesrc, sdn2=nothing, ce=subgraphedge(ibn.ngr, e), ceintra=nothing)
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

"$(TYPEDSIGNATURES) Break down a IBN path to the paths from the SDN view"
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
$(TYPEDSIGNATURES) 

Check edge `ce` availability between 2 IBN domains `con1, con2` for capacity `capacity`.
It actually:
- checks residual capacity on the edge
- checks residual ports in edgenode
"""
function isavailable(con1::IBN, con2::IBN, ce::NestedEdge, capacity::Real)
    isavailable(ibns2sdns(con1, con2, ce, capacity)...)
end

"""
$(TYPEDSIGNATURES) 

Reserve resources between 2 controllers
"""
function reserve!(con1::IBN, con2::IBN, ce::NestedEdge, capacity::Real)
    reserve!(ibns2sdns(con1, con2, ce, capacity)...)
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

"""
$(TYPEDSIGNATURES)

Delegates remote intent `remintent` `dag`, `idn` from IBN customer `ibnc` to IBN server `ibns` and triggers its compilation
Once added to `ibns`, compilation is requested using `algmethod` and `algargs` if any.
"""
function delegateintent!(ibnc::IBN, ibns::IBN, dag::IntentDAG, idn::IntentDAGNode, remintent::Intent, algmethod; algargs...)
    remintr = addchild!(dag, getid(idn), remintent)
    ibnpissuer = IBNIssuer(getid(ibnc), getid(dag), getid(idn))
    remidx = addintent!(ibnpissuer, ibns, getintent(remintr))
    addchild!(dag, getid(remintr), RemoteIntent(getid(ibns), remidx))
    return deploy!(ibnc, ibns, remidx, MINDFul.docompile, MINDFul.SimpleIBNModus(), algmethod; algargs...)
end

"""
$(TYPEDSIGNATURES)

`ibnc` asks `ibns` to change state of the intent `intentibnid`, `intentidx` to `state` at time `time`.
"""
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

"$(TYPEDSIGNATURES)"
function delegate_edgeintents(ibn, dag, idn, interconstraints, compmethod)
    length(interconstraints) > 1 && @warn "Intent issues multiple EdgeIntents"
    for kvpair in interconstraints
        ei = EdgeIntent(kvpair.second)
        ibnserver = getibn(ibn, kvpair.first)
        delegateintent!(ibn, ibnserver, dag, idn, ei, compmethod)
    end
end

"$(TYPEDSIGNATURES)"
function delegate_edgeintent(ibn, dag, idn, kvpair, compmethod; time)
    ei = EdgeIntent(kvpair.second)
    ibnserver = getibn(ibn, kvpair.first)
    delegateintent!(ibn, ibnserver, dag, idn, ei, compmethod; time)
end
