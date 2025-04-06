function Base.copy(s::IntentDAGInfo)
    return mycopy(s)
end

function Base.copy(s::IBNAttributeGraph)
    return mycopy(s)
end

function Base.copy(s::IBNFramework)
    return mycopy(s)
end

function Base.copy(s::IntentDAG)
    return mycopy(s)
end

function Base.copy(s::IntentDAGNode)
    return mycopy(s)
end
