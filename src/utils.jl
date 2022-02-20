export edgeify, @recargs!

"Converts a node path to a sequence of edges"
edgeify(p) = map(Edge , zip(p, p[2:end]));

Base.@kwdef struct Counter
    #TODO implemente as simple integer?
    states::Dict{Int,Int} = Dict{Int,Int}(0 => 0)
end

(o::Counter)() = o.states[0] += 1
(o::Counter)(i::Int) = haskey(o.states, i) ? o.states[i] += 1 : o.states[i] = 0

"Save arguments to `recarglist` and evaluate function `funex`"
macro recargs!(recarglist::Symbol, funex::Expr)
    return quote
        push!($(esc(recarglist)), [$(esc.(funex.args[2:end])...)] )
        $(esc(funex))
    end
end

