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

"""
$(TYPEDSIGNATURES) 

Recursively compare all fields until a primitive element type is found
"""
function isthesame(obj1::T, obj2::T) where {T}
    skiphandlers = false
    if T <: IBNFramework{O, S, T, H} where {O, S, T, H <: IBNFramework}
        # cannot do recursive
        length(getibnfhandlers(obj1)) == length(getibnfhandlers(obj2)) || return false
        skiphandlers = true
    end
    if isprimitivetype(T)
        if T <: Ptr
            return true
        else
            if obj1 == obj2
                return true
            else
                return false
            end
        end
    elseif T <: Dict
        if obj1 == obj2
            return true
        else
            all(k in keys(obj2) for k in keys(obj1)) || return false
            all(k in keys(obj1) for k in keys(obj2)) || return false
            return all(keys(obj1)) do k
                isthesame(obj1[k], obj2[k])
            end
        end
    elseif T <: AbstractVector
        return all(zip(obj1, obj2)) do (obj1el, obj2el)
            isthesame(obj1el, obj2el)
        end
    else
        return all(fieldnames(T)) do fn
            if skiphandlers
                if fn == :ibnfhandlers
                    return true
                else
                    isthesame(getfield(obj1, fn), getfield(obj2, fn))
                end
            else
                return true
            end
        end
    end
end
