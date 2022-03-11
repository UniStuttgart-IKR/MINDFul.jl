"Defines the way the IBN Framework state machine will behave"
abstract type IBNModus end
struct SimpleIBNModus <: IBNModus end


"Information needed for interacting IBN"
struct IBNInterProps 
    "permissions of other IBN"
    permissions::BitVector
end
"""
The Intent Framework
The intent id is the vector index
`controllers` must have same length with `cgr.grv`
    $(TYPEDFIELDS)
"""
struct IBN{T<:SDN,R}
    "id of IBN"
    id::Int
    #TODO Union split ?
    "The intent collection of the IBN Framework"
    intents::Vector{IntentTree}
    #TODO integrate permissions 
    #TODO implement IBN-NBI
    "The collection of SDNs controlled from this IBN Framework and interacting IBNs (future should be IBN-NBIs)"
    controllers::Vector{Union{T, IBN}}
    #TODO make R -> CompositeGraph directly
    """
    Composite Graph consisting of the several SDNs
    cgr is a shallow copy of the sdn graphs, 
    meaning all PHY information is available in the IBN
    """
    cgr::CompositeGraph{R,R}
    "InterIBN interoperability with key being the IBN id"
    interprops::Dict{Int,IBNInterProps}
end
#TODO not good minus 1
controllerofnode(ibn::IBN, node::Int) = ibn.controllers[domain(ibn.cgr, node)]
isintraintent(ibn::IBN, intentt::IntentTree{R}) where {R<:Intent} = ibn.id == src(intentt)[1] == dst(intentt)[1]
ibns(ibn::IBN) = Iterators.filter(x -> isa(x, IBN),ibn.controllers)
sdns(ibn::IBN) = Iterators.filter(x -> isa(x, SDN),ibn.controllers)

ibn(ibn::IBN, id) = id == ibn.id ? ibn : getfirst(x -> getfield(x,:id) == id, ibns(ibn))
#TODO implement a different method (Channels, Tasks, yield)

IBN(counter::Counter, args...) = IBN(counter(), args...)
IBN!(counter::Counter, args...) = IBN!(counter(), args...)
"Empty constructor"
IBN(c::Int, ::Type{T}) where {T<:SDN}  = IBN(c, 
                                            Vector{IntentTree{Intent}}(), 
                                            Vector{Union{T, IBN}}(), 
                                            CompositeGraph(),
                                            Dict{Int, IBNInterProps}())
IBN(c::Int, controllers::Vector{T}) where {T<:Union{SDN,IBN}}  = IBN(c, controllers, CompositeGraph(getfield.(controllers, :gr)))
IBN!(c::Int, controllers::Vector{T}, eds::Vector{CompositeEdge{R}}) where {T<:Union{SDN,IBN}, R}  = IBN(c, controllers, mergeSDNs!(controllers, eds))
IBN(c::Int, controllers::Vector{T}, cg::CompositeGraph) where {T<:Union{SDN,IBN}}  = IBN(c, 
                                                            Vector{IntentTree}(), 
                                                            Vector{Union{T, IBN}}(controllers), 
                                                            cg,
                                                            Dict{Int, IBNInterProps}())

function connect(ibn1::IBN, ibn2::IBN, e::Edge)
    push!(ibn1.interprops)
end

function connectIBNs!(ibn::Vector{IBN}, cedges::Vector{CompositeEdge})
    for ce in cedges
        if ce.src[1] != ce.dst[1]
            push!(ibn[ce.src[1]].interprops.nodge, ce)
            push!(ibn[ce.dst[1]].interprops.nodge, ce)
        end
    end
end

"add a provider IBN to the list of the customer IBN with `vlist` being the communication points"
function connectIBNs!(ibn1::IBN, ibn2::IBN, cedges::Vector{CompositeEdge{T}}, dprops::Union{Vector{Dict{Symbol,R}}, Nothing}=nothing) where {T, R}
    if ibn1.id in getfield.(ibns(ibn2), :id) || ibn2.id in getfield.(ibns(ibn1), :id)
        @warn("IBN already listed")
        return false
    end

    # Interconnecting nodes
    v1list = Set{Int}()
    v2list = Set{Int}()
    for ce in cedges
        for sd in [ce.src, ce.dst]
            if sd[1] == ibn1.id
                push!(v1list, sd[2])
            elseif sd[1] == ibn2.id
                push!(v2list, sd[2])
            end
        end
    end

    #add controllers 
    
    # build graph as prrovided from the other ibn
    gr2, vmap2 = subgraph(ibn2, ibn1)
    v2add = [vp for vp in v2list if !has_vertex(gr2, vp)]
    add_vertices!(gr2, ibn2.cgr, v2add)

    gr1, vmap1 = subgraph(ibn1, ibn2)
    v1add = [vp for vp in v1list if !has_vertex(gr1, vp)]
    add_vertices!(gr1, ibn1.cgr, v1add)
    
    CompositeGraphs.add_graph!(ibn1.cgr, gr2, cedges, dprops; vmap=vcat(vmap2, v2add), both_ways=true)
    #reverse cedges
    CompositeGraphs.add_graph!(ibn2.cgr, gr1, cedges, dprops; vmap=vcat(vmap1, v1add), both_ways=true, rev_cedges=true)
end

"Incorporate new SDN to the IBN structure"
addSDN(ibn::IBN) = error("not implemented")
"add interSDN edges"
addinterSDNedges(ibn::IBN, ces::Vector{CompositeEdge}) = error("not implemented")

"Add Intent as Network Operator"
function addintent(ibn::IBN, intent::Intent)
    push!(ibn.intents, IntentTree(intent))
    return length(ibn.intents)
end

"Add InterIBN-Intent as IBN2IBN, customer2provider"
function addintent(ibnp::IBN, ibnc::IBN, intent::Intent)
    error("not implemented")
    #return intent number
end

"ibn-customer accesses the intent state machine of ibn-provider"
function step!(ibnp::IBN, ibnc::IBN, intidx::Int)

end

"ibn-customer asks for the graph of ibn-provider"
function subgraph(ibnp::IBN, ibnc::IBN)
    #check permissions
    return (MetaDiGraph(), Vector{Int}())
end

"""
Installs a single intent.
First, it compiles the intent if it doesn't have already an implementation
Second, it applies the intent implementation on the network
"""
function step!(ibn::IBN, inid::Int, itra::InstallIntent, ibnModus::SimpleIBNModus; intent_comp=shortestpathcompilation, intent_real=directrealization)
    #TODO introduce a way to control behavior
    intent = ibn.intents[inid]
    if state(intent) isa UninstalledIntent
        if ismissing(compilation(intent))
            setcompilation!(intent, intent_comp(ibn, ibn.intents[inid]))
        end
        ismissing(compilation(intent)) && return false
        realized = intent_real(ibn, compilation(intent))

        if realized 
            @info "Installed intent $(ibn.intents[inid])"
            setstate!(intent, InstalledIntent())
            return true
        else
            return false
        end
    else
        @info "Cannot install intent $(intent) on state $(state(intent))"
        return false
    end
end

"""
Installs a bunch of intent all together.
Takes into consideration resources collisions.
"""
function step(ibn::IBN, inid::Vector{Int}, itra::InstallIntent)
    return false
end

"Uninstalls a single intent"
function step!(ibn::IBN, inid::Int, itra::UninstallIntent)
    intent = ibn.intents[inid]
    if state(intent) isa InstalledIntent
        withdrew = withdraw(ibn, intent)
        if withdrew
            @info "Uninstalled intent $(ibn.intents[inid])"
            setstate!(intent, UninstalledIntent())
            return true
        else
            return false
        end
    else
        @info "Already uninstalled intent $(ibn.intents[inid])"
        return false
    end
end

"Checks if intent is satisfied"
function issatisfied(ibn::IBN, inid::Int)
    issatisfied = isinstalled(ibn, inid)
    for constr in ibn.intents[inid].constrs
        issatisfied = issatisfied && issatisfied(ibn, inid, constr)
    end
    return issatisfied
end

isinstalled(ibn::IBN, inid::Int) = state(ibn.intents[inid]) isa InstalledIntent
issatisfied(ibn::IBN, inid::Int, constr::CapacityConstraint) = return compilation(ibn.intents[inid]).capacity >= constr.capacity
issatisfied(ibn::IBN, inid::Int, constr:: DelayConstraint) = sum(delay(l) for l in edgeify(compilation(ibn.intents[inid]).path)) <= constr.delay

function shortestpathcompilation(ibn::IBN, intent::IntentTree{ConnectivityIntent})
    #intent can be completely handled inside the IBN network
    if isintraintent(ibn, intent)
        #TODO adaptation for id
        path = yen_k_shortest_paths(ibn.cgr.flatgr, src(intent)[2], dst(intent)[2], weights(ibn.cgr.flatgr), 1).paths[]
        cap = [c.capacity for c in constraints(intent) if c isa CapacityConstraint][]
        return ConnectivityIntentCompilation(path, cap)
    else
#        if intent.data.src[1] == ibn.id && intent.data.dst[1] != ibn.id
#            addchild(intent, ConnectivityIntent((ibn.id, intent.data.src[2]), (ibn.id, 10), intent.data.constraints ))
#            addchild(intent, ConnectivityIntent((intent.data.dst[1], 1), (intent.data.dst[1], intent.data.dst[2]), intent.data.constraints ))
#        end
        @warn("inter-IBN intents not implemented for `shortestpathcompilation`")
        return missing
    end
end

"""
Realize the intent implementation by delegating tasks in the different responsible SDNs
First check, then reserve
"""
function directrealization(ibn::IBN, intimp::ConnectivityIntentCompilation)
    #TODO check if intent already installed ?
    succeeded = true
    reclist = Vector{}()
    for e in edgeify(intimp.path)
        if controllerofnode(ibn, e.src) == controllerofnode(ibn, e.dst)
            #intradomain
            succeeded = succeeded && @recargs!(reclist, isavailable(controllerofnode(ibn, e.src), domainedge(ibn.cgr, e), intimp.capacity))
        else
            #interdomain
            succeeded = succeeded && @recargs!(reclist, isavailable(controllerofnode(ibn, e.src), controllerofnode(ibn, e.dst), compositeedge(ibn.cgr, e), intimp.capacity))
        end
        succeeded || break
    end
    if succeeded
        for rec in reclist
            reserve(rec...)
        end
    end
    return succeeded
end

function withdraw(ibn::IBN, intimp::ConnectivityIntentCompilation)
    for e in edgeify(intimp.path)
        if controllerofnode(ibn, e.src) == controllerofnode(ibn, e.dst)
            #intradomain
            free!(controllerofnode(ibn, e.src), domainedge(ibn.cgr, e), intimp.capacity)
        else
            #interdomain
            free!(controllerofnode(ibn, e.src), controllerofnode(ibn, e.dst), compositeedge(ibn.cgr, e), intimp.capacity)
        end
    end
    return true
end

