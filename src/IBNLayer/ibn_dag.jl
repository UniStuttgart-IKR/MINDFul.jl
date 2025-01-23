# IntentDAG customizations

"""
$(TYPEDSIGNATURES)
"""
function getidaginfo(intentdag::IntentDAG)
    return AG.graph_attr(intentdag)
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodes(intentdag::IntentDAG)
    return AG.vertex_attr(intentdag)
end

"""
$(TYPEDSIGNATURES)
"""
function getidagcounter(intentdag::IntentDAG)
    return getidagcounter(getidaginfo(intentdag))
end

"""
$(TYPEDSIGNATURES)
"""
function increaseidagcounter!(intentdag::IntentDAG)
    idaginfo = getidaginfo(intentdag)
    idaginfo.intentcounter += 1
end


"""
$(TYPEDSIGNATURES)

Get the vertex index of the intent DAG node with id `dagnodeid`
"""
function getidagnodeidx(intentdag::IntentDAG, dagnodeid::UUID)
    return findfirst(==(dagnodeid), getidagnodeid.(getidagnodes(intentdag)))
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnode(intentdag::IntentDAG, dagnodeid::UUID)
    return getidagnodes(intentdag)[getidagnodeidx(intentdag, dagnodeid)]
end

"""
$(TYPEDSIGNATURES)
"""
function getidagnodestate(intentdag::IntentDAG, dagnodeid::UUID)
    return getidagnodestate(getidagnode(intentdag, dagnodeid))
end

"""
$(TYPEDSIGNATURES)
"""
function addidagnode!(intentdag::IntentDAG, intent::AbstractIntent; parentid::Union{Nothing, UUID}=nothing, intentissuer=MachineGenerated())
    intentcounter = increaseidagcounter!(intentdag)
    idagnode = IntentDAGNode(intent, UUID(intentcounter), intentissuer, IntentLogState())

    add_vertex!(intentdag)
    newidagnodeidx = nv(intentdag)
    push!(getidagnodes(intentdag), idagnode)
    
    if !isnothing(parentid)
        parentidx = getidagnodeidx(intentdag, parentid)
        add_edge!(intentdag, parentidx, newidagnodeidx)
    end

    return getidagnodeid(idagnode)
end

function removeidagnode!(intentdag::IntentDAG, idagnodeid::UUID)
    vertexidx = getidagnodeidx(intentdag, idagnodeid)
    rem_vertex!(intentdag, vertexidx)
    return true
end
