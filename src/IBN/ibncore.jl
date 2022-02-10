"Defines the way the IBN Framework state machine will behave"
abstract type IBNModus end
struct SimpleIBNModus <: IBNModus end

"""
The Intent Framework
The intent id is the vector index
"""
struct IBN{T<:SDN, R<:AbstractGraph}
    #TODO how to assure that id is unique
    "The id of the IBN Framework"
    id::Int
    "The intent collection of the IBN Framework"
    intents::Vector{Intent}
    "The states of the intents. One-to-one relationship with `intents`"
    states::Vector{IntentState}
    "The implementation of the intents. One-to-one relationship with `intents`"
    intimps::Vector{Union{IntentCompilation,Missing}}
    "All IBNs to interact with"
    neibns::Vector{IBN{T}}
    "The collection of SDNs controlled from this IBN Framework"
    sdns::Vector{T}
    "Composite Graph consisting of the several SDNs"
    cgr::R
end
sdnofnode(ibn::IBN, node::Int) = ibn.sdns[domain(ibn.cgr, node)]

#TODO implement a different method (Channels, Tasks, yield)
ibnid = 1

IBN(sdns::Vector{T}) where {T<:SDN}  = IBN((global ibnid += 1), sdns)
IBN(id::Int, sdns::Vector{T}) where {T<:SDN}  = IBN(id, 
                                           sdns, 
                                           CompositeGraph(getfield.(sdns, :gr)))
IBN!(id::Int, sdns::Vector{T}, eds::Vector{CompositeEdge{R}}) where {T<:SDN, R}  = IBN(id, 
                                           sdns, 
                                           mergeSDNs!(sdns, eds))
IBN(id::Int, sdns::Vector{T}, cg::CompositeGraph) where {T<:SDN}  = IBN(id, 
                                           Vector{Intent}(), 
                                           Vector{IntentState}(), 
                                           Vector{Union{IntentCompilation,Missing}}(), 
                                           Vector{IBN{T}}(), 
                                           sdns, 
                                           cg)

function addintent(ibn::IBN, intent::Intent)
    push!(ibn.intents, intent)
    push!(ibn.states, UninstalledIntent())
    push!(ibn.intimps, missing)
    return true
end

"""
Installs a single intent.
First, it compiles the intent if it doesn't have already an implementation
Second, it applies the intent implementation on the network
"""
function step(ibn::IBN, inid::Int, itra::InstallIntent, ibnModus::SimpleIBNModus; intent_comp=shortestpathcompilation, intent_real=directrealization)
    #TODO introduce a way to control behavior
    if ibn.states[inid] isa UninstalledIntent
        if ismissing(ibn.intimps[inid])
            ibn.intimps[inid] = intent_comp(ibn, ibn.intents[inid])
        end

        realized = intent_real(ibn, ibn.intimps[inid])

        if realized 
            @info "Installed intent $(ibn.id)-$(inid)"
            ibn.states[inid] = InstalledIntent()
            return true
        else
            return false
        end
    else
        @info "Cannot install intent $(ibn.id)-$(inid) on state $(ibn.states[inid])"
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
function step(ibn::IBN, inid::Int, itra::UninstallIntent)
    if ibn.states[inid] isa InstalledIntent
        withdrew = withdraw(ibn, ibn.intimps[inid])
        if withdrew
            @info "Uninstalled intent $(ibn.id)-$(inid)"
            ibn.states[inid] = UninstalledIntent()
            return true
        else
            return false
        end
    else
        @info "Already uninstalled intent $(ibn.id)-$(inid)"
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

isinstalled(ibn::IBN, inid::Int) = inid <= length(ibn.states) ? ibn.states[inid] isa InstalledIntent : false
issatisfied(ibn::IBN, inid::Int, constr::CapacityConstraint) = return ibn.intimps[inid].capacity >= constr.capacity
issatisfied(ibn::IBN, inid::Int, constr:: DelayConstraint) = sum(delay(l) for l in edgeify(ibn.intimps[inid].path)) <= constr.delay

function shortestpathcompilation(ibn::IBN, intent::ConnectivityIntent)
    #intent can be completely handled inside the IBN network
    if intent.src[1] == intent.dst[1] == ibn.id
        path = yen_k_shortest_paths(ibn.cgr.flatgr, intent.src[2], intent.dst[2], weights(ibn.cgr.flatgr), 1).paths[]
        cap = [c.capacity for c in intent.constrs if c isa CapacityConstraint][]
        return ConnectivityIntentCompilation(path, cap)
    else
        @warn("inter-IBN intents not implemented for `shortestpathcompilation`")
        return false
    end
end

"Realize the inent implementation by delegating tasks in the different responsible SDNs"
function directrealization(ibn::IBN, intimp::ConnectivityIntentCompilation)
    #TODO check if intent already installed ?
    #TODO how to undo
    for e in edgeify(intimp.path)
        if sdnofnode(ibn, e.src) == sdnofnode(ibn, e.dst)
            #intradomain
            reserve(sdnofnode(ibn, e.src), domainedge(ibn.cgr, e), intimp.capacity)
        else
            #interdomain
            reserve(sdnofnode(ibn, e.src), sdnofnode(ibn, e.dst), compositeedge(ibn.cgr, e), intimp.capacity)
        end
    end
    #TODO not always true
    return true
end

function withdraw(neibns::Vector{IBN}, sdns::Vector{SDN}, intimp::ConnectivityIntentCompilation)
    free(mgr, intimp.path, intimp.capacity)
end
