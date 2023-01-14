"""
$(TYPEDEF)
$(TYPEDFIELDS)
Save arguments to `recarglist` and evaluate function `funex`
"""
macro recargs!(recarglist::Symbol, funex::Expr)
    return quote
        push!($(esc(recarglist)), [$(esc.(funex.args[2:end])...)] )
        $(esc(funex))
    end
end
