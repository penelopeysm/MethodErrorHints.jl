module MethodErrorHints

"""
    @method_error_hint f(x, y::T, args...) msg
"""
macro method_error_hint(args...)
    expr::Expr = args[1]
    msg::String = args[2]
    printstyled_kwargs = args[3:end]
    return _method_error_hint(expr, msg, printstyled_kwargs)
end

function _method_error_hint(expr::Expr, msg::String, printstyled_kwargs::Tuple)::Expr
    # Input validation
    expr.head === :call || error("@method_error_hint must be applied to a function call")
    length(expr.args) == 1 && error(
        "@method_error_hint must be applied to a function call with at least one argument",
    )

    # Wrangle the keyword arguments to be forwarded to `printstyled`
    ps_kwargs_dict = :(Dict{Symbol,Any}())
    for ps_kwarg in printstyled_kwargs
        if !(
            ps_kwarg isa Expr &&
            ps_kwarg.head === :(=) &&
            length(ps_kwarg.args) == 2 &&
            ps_kwarg.args[1] isa Symbol
        )
            error(
                "additional arguments to @method_error_hint must be keyword arguments passed to `printstyled`, but got `$ps_kwarg`",
            )
        else
            # This bit was quite hard to figure out ... I copied the code from Test.jl
            # https://github.com/JuliaLang/julia/blob/12f7bb52e5714c577189665a05606e3764f333cf/stdlib/Test/src/Test.jl#L2092-L2096
            key = Expr(:quote, ps_kwarg.args[1])
            push!(ps_kwargs_dict.args, Expr(:call, :(=>), key, esc(ps_kwarg.args[2])))
        end
    end

    # Get the function name
    fname = expr.args[1]
    fname_check_expr = :(exc.f === $(esc(fname)))

    # Decide which arguments of `expr` are positional and which are keyword
    has_kwargs = expr.args[2].head === :parameters
    (arg_exprs, kwarg_exprs) = if has_kwargs
        expr.args[3:end], expr.args[2].args
    else
        expr.args[2:end], nothing
    end

    # Determine number and types of arguments
    nargs = length(arg_exprs)
    has_varargs = false
    target_argtypes = Any[]
    for (i, arg_expr) in enumerate(arg_exprs)
        if arg_expr isa Symbol
            # `x`
            push!(target_argtypes, :Any)
        elseif arg_expr.head === :(::)
            # `x::T`
            push!(target_argtypes, :($(esc(arg_expr.args[2]))))
        elseif arg_expr.head === :(...)
            if i == nargs
                has_varargs = true
                nargs -= 1  # Not a true argument
            else
                error("`...` can only appear in the last position")
            end
        else
            error("unsupported argument expression: $arg_expr")
        end
    end
    @gensym argtypes
    arg_length_check_expr =
        has_varargs ? :(length($argtypes) >= $nargs) : :(length($argtypes) == $nargs)
    function make_arg_type_check_expr(argtypes_sym::Symbol)
        if isempty(target_argtypes)
            return :(true)
        else
            satisfies_exprs = map(eachindex(target_argtypes)) do i
                :($argtypes_sym[$i] <: $(target_argtypes[i]))
            end
            return foldl((a, b) -> :($a && $b), satisfies_exprs)
        end
    end
    arg_type_check_expr = make_arg_type_check_expr(argtypes)

    # TODO: Handle kwargs
    # @show kwarg_exprs

    # Construct the expression
    return quote
        Base.Experimental.register_error_hint(
            Base.MethodError,
        ) do io, exc, $argtypes, kwargs
            is_target_method =
                (($fname_check_expr) && ($arg_length_check_expr) && ($arg_type_check_expr))
            if is_target_method
                # TODO: are the kwargs correct here?
                println(io)
                printstyled(io, $(esc(msg)); $ps_kwargs_dict...)
            end
        end
    end
end

export @method_error_hint

end # module MethodErrorHints
