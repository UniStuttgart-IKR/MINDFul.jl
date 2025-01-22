"""
$(TYPEDSIGNATURES)

Convenience function to construct any struct of type `T` by passing a `Dict` corresponding to the fields needed.
"""
function constructfromdict(_::Type{T}, dict::Dict{Symbol}) where T
    return T([dict[fn] for fn in fieldnames(T)]...)
end

"""
$(TYPEDSIGNATURES)

Convenience function to construct any struct of type `T` by passing a `Dict` corresponding to the fields needed.
A further dict `dict2` is searched for data.
"""
function constructfromdict(_::Type{T}, dict::Dict{Symbol}, dict2::Dict{Symbol}) where {T}
    return T([
        haskey(dict, fn) ? dict[fn] : dict2[fn]
        for fn in fieldnames(T)
    ]...)
end

"""
$(TYPEDSIGNATURES)

Return a `return false` if the expression `ex` evaluates to false.
If `verbose=true` print the statement and the location.
If the expression passed is `true` do nothing.
"""
macro returniffalse(verbose, ex)
    quote
        if !($(esc(ex)))
            if $(esc(verbose)) 
                println("False expression in", $(string(__source__.file)), ':', $(__source__.line), " --> ", $(string(ex)))
            end
            return false
        end
    end
end

