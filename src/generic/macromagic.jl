"""
$(TYPEDSIGNATURES)

Return a `return ReturnCodes.Fail` if the expression `ex` evaluates to false.
If `verbose=true` print the statement and the location.
If the expression passed is `true` do nothing.
TODO: have also a helper message be printed
"""
macro returniffalse(verbose, ex)
    return quote
        if !($(esc(ex)))
            if $(esc(verbose))
                println("False expression in", $(string(__source__.file)), ':', $(__source__.line), " --> ", $(string(ex)))
            end
            return ReturnCodes.FAIL
        end
    end
end

"""
$(TYPEDSIGNATURES)

Return a `return false` if the expression `ex` evaluates to false.
If `verbose=true` print the statement and the location.
If the expression passed is `true` do nothing.
"""
macro returnfalseiffalse(verbose, ex)
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
Use [`@logtime`](@ref) to calculate the current time inside the function.
Use [`@passtime`](@ref) to pass the timing information to another function.
"""
macro recvtime(funcexpr)
    addkeywordparameters!(funcexpr, Expr(:kw, :(offsettime::Union{DateTime, Nothing}), :(now())))
    pushfirst!(funcexpr.args[2].args, Expr(:(=), :entrytime, :(now())))
    return :($(esc(funcexpr)))
end

"""
$(TYPEDSIGNATURES)

This macro is used to pass the (simulated) timing information.
It basically passes `(; offsettime)`

This strategy calls `now()` every time before passing the arguments.
If that proves to slow down the implementation consider to pass `offsettime, entrytime` around and calcualte @logtime once in the end.
Another caveat is that the communication overhead between domains is not measured.
An `offsetime=nothing` logs the time of the current system.
"""
macro passtime()
    # return :((; $(esc(:offsettime)) = @logtime )...)
    return :((; $(esc(:offsettime)) = isnothing($(esc(:offsettime))) ? nothing : @nestedlogtime)...)
end


"""
$(TYPEDSIGNATURES)

This macro is used to calculate the current (simulated) time as `offsettime + (now() - entrytime)`
"""
macro logtime()
    # return :($(esc(:offsettime)) + (now() - $(esc(:entrytime))) )
    return :(isnothing($(esc(:offsettime))) ? now() : $(esc(:offsettime)) + (now() - $(esc(:entrytime))))
end

macro nestedlogtime()
    # return :($(esc(:offsettime)) + (now() - $(esc(:entrytime))) )
    return :(isnothing($(esc(esc(:offsettime)))) ? now() : $(esc(esc(:offsettime))) + (now() - $(esc(esc(:entrytime)))))
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
            if !isempty(parametersdad.args) && (parametersdad.args[1] isa Symbol || (parametersdad.args[1] isa Expr && Base.isexpr(parametersdad.args[1], :.)))
                position = 2
            else
                position = 1
            end
            insert!(funcexpr.args[1].args, position, Expr(:parameters, keywordparexprs...))
        else
            funcexpr.args[1].args[ff] = Expr(:parameters, parametersdad.args[ff].args..., keywordparexprs...)
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
            insert!(funcexpr.args[1].args[1].args, position, Expr(:parameters, keywordparexprs...))
        else
            funcexpr.args[1].args[1].args[ff] = Expr(:parameters, parametersdad.args[ff].args..., keywordparexprs...)
        end
    else
        error("Function has unknown structure and cannot find where to insert keywords.")
    end
    return funcexpr
    # return :($(esc(funcexpr)))
end
