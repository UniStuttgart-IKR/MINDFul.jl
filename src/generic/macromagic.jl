"""
$(TYPEDSIGNATURES)

Return a `return false` if the expression `ex` evaluates to false.
If `verbose=true` print the statement and the location.
If the expression passed is `true` do nothing.
"""
macro returniffalse(verbose, ex)
    return quote
        if !($(esc(ex)))
            if $(esc(verbose))
                println("False expression in", $(string(__source__.file)), ':', $(__source__.line), " --> ", $(string(ex)))
            end
            return false
        end
    end
end


"""
$(TYPEDSIGNATURES)

This macro is used to receive the (simulated) timing information.
This macro does two things:
- puts the `offsettime::DateTime=now()` in the input keyword parameters
- puts `entrytime = now()` as the first command to happen in the function
Use [`logtime`](@ref) to calculate the current time inside the function.
Use [`passtime`](@ref) to pass the timing information to another function.
"""
macro recvtime(funcexpr) 
    addkeywordparameters!(funcexpr, Expr(:kw, :(offsettime::DateTime), :(now()) ) )
    pushfirst!(funcexpr.args[2].args, Expr(:(=), :entrytime, :(now()) ) )
    return funcexpr
end

"""
$(TYPEDSIGNATURES)

This macro is used to pass the (simulated) timing information.
It is valid to be used in functions defined with [`entrytime`](@ref).
It basically passes `(; entrytime, offsettime)`

This strategy calls `now()` every time before passing the arguments.
If that proves to slow down the implementation consider to pass `offsettime, entrytime` around and calcualte @logtime once in the end.
Another caveat is that the communication overhead between domains is not measured.
Finally this technique is well suited for simulations, but cannot work good for real time applications.
An `offsetime=nothing` could be implemented to handle real-time applications.
"""
macro passtime() 
    return :((; $(esc(:offsettime)) = @logtime )...)
end


"""
$(TYPEDSIGNATURES)

This macro is used to calculate the current (simulated) time.
"""
macro logtime()
    return :($(esc(:offsettime)) + (now() - $(esc(:entrytime))) ) 
end

"""
$(TYPEDSIGNATURES)
"""
function addkeywordparameters!(funcexpr::Expr, keywordparexprs::Expr...)
    if Base.isexpr(funcexpr.args[1], :call) || Base.isexpr(funcexpr.args[1], :tuple)
        # normal
        parametersdad = funcexpr.args[1]
        ff = findfirst(ex -> Base.isexpr(ex, :parameters), parametersdad.args)
        if isnothing(ff)
            if !isempty(parametersdad.args) && parametersdad.args[1] isa Symbol
                position = 2
            else
                position = 1
            end
            insert!(funcexpr.args[1].args, position, Expr(:parameters, keywordparexprs... ))
        else
            funcexpr.args[1].args[ff] = Expr(:parameters, parametersdad.args[ff].args..., keywordparexprs... )
        end
    elseif Base.isexpr(funcexpr.args[1], :where)
        # template
        parametersdad = funcexpr.args[1].args[1]
        ff = findfirst(ex -> Base.isexpr(ex, :parameters), parametersdad.args)
        if isnothing(ff)
            if !isempty(parametersdad.args) && parametersdad.args[1] isa Symbol
                position = 2
            else
                position = 1
            end
            insert!(funcexpr.args[1].args[1].args, position, Expr(:parameters, keywordparexprs... ))
        else
            funcexpr.args[1].args[1].args[ff] = Expr(:parameters, parametersdad.args[ff].args..., keywordparexprs... )
        end
    else
        error("Function has unknown structure and cannot find where to insert keywords.")
    end
    return funcexpr
end

