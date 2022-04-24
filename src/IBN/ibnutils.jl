distance(ibn::IBN, path::Vector{Int}) = sum(distance(get_prop(ibn.cgr, l, :link)) for l in edgeify(path))
