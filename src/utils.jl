function constructfromdict(_::Type{T}, dict::Dict{Symbol}) where T
    T([dict[fn] for fn in fieldnames(T)]...)
end
