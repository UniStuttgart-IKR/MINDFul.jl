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


"""
$(TYPEDEF)
$(TYPEDFIELDS)
Pass clock time and the function to evaluate
"""
macro at(time::Expr, funex::Expr)
    return quote
        updateIBNFtime!($(esc(time)))
        $(esc(funex))
    end
end
