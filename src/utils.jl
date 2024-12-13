"""
$(TYPEDSIGNATURES)

Convenience function to construct any struct of type `T` by passing a `Dict` corresponding to the fields needed.
"""
function constructfromdict(_::Type{T}, dict::Dict{Symbol}) where T
    T([dict[fn] for fn in fieldnames(T)]...)
end

