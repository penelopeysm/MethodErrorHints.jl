module MethodErrorHints

"""
    @method_error_hint f(x, y::T, args...) msg
"""
macro method_error_hint(args...)
    expr = args[1]
    msg = args[2]
    printstyled_kwargs = args[3:end]
    return _method_error_hint(expr, msg, printstyled_kwargs)
end

# The kwargs passed into `register_error_hint` are a list of (symbol, type) tuples
# (but they have type Vector{Any})
function __kwarg_matches_type(
    kwarg_list::Vector{Any},
    kwarg_sym::Symbol,
    expected_type::Type,
)
    for (sym, type) in kwarg_list
        if sym === kwarg_sym
            return type <: expected_type
        end
    end
    return false
end

function _method_error_hint(expr::Expr, msg, printstyled_kwargs::Tuple)::Expr
    # Input validation
    # TODO: Type parameters don't work e.g. `f(x::T, y::T) where {T}`
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
    has_kwargs = expr.args[2] isa Expr && expr.args[2].head === :parameters
    (arg_exprs, kwarg_exprs) = if has_kwargs
        expr.args[3:end], expr.args[2].args
    else
        expr.args[2:end], ()
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
            # `x::T` or `::T`
            push!(target_argtypes, :($(esc(last(arg_expr.args)))))
        elseif arg_expr.head === :(...)
            # `args...`
            # TODO: Vararg{T} not supported I think
            if i == nargs
                has_varargs = true
                continue
            else
                error("`...` can only appear in the last position")
            end
        else
            error("unsupported argument expression: $arg_expr")
        end
    end
    @gensym argtypes
    arg_length_check_expr =
        has_varargs ? :(length($argtypes) >= $nargs - 1) : :(length($argtypes) == $nargs)
    arg_type_check_expr = if isempty(target_argtypes)
        :(true)
    else
        satisfies_exprs = map(eachindex(target_argtypes)) do i
            :($argtypes[$i] <: $(target_argtypes[i]))
        end
        foldl((a, b) -> :($a && $b), satisfies_exprs)
    end

    # Determine number and types of keyword arguments
    n_kwargs = length(kwarg_exprs)
    target_kwargtypes = Dict{Symbol,Any}()
    has_varkwargs = false
    for (i, kwarg_expr) in enumerate(kwarg_exprs)
        if kwarg_expr isa Symbol
            # `x`
            target_kwargtypes[kwarg_expr] = :Any
        elseif kwarg_expr.head === :(::)
            # `x::T`
            length(kwarg_expr.args) == 2 ||
                error("keyword argument type specification must be of the form `x::T`")
            target_kwargtypes[kwarg_expr.args[1]] = :($(esc(kwarg_expr.args[2])))
        elseif kwarg_expr.head === :(...)
            if i == n_kwargs
                has_varkwargs = true
                continue
            else
                error("`...` can only appear in the final keyword argument")
            end
        elseif kwarg_expr.head === :kw
            error(
                "default keyword arguments should not be specified in `@method_error_hint`; only types for keyword arguments are permitted",
            )
        end
    end
    @gensym kwargs
    kwarg_length_check_expr =
        has_varkwargs ? :(length($kwargs) >= $n_kwargs - 1) :
        :(length($kwargs) == $n_kwargs)
    # Check that all the expected keyword arguments (in `target_kwargtypes`) were
    # present in the function call, and have the correct types.
    kwarg_type_check_expr = if isempty(target_kwargtypes)
        :(true)
    else
        satisfies_exprs = map(collect(target_kwargtypes)) do (target_sym, target_type)
            :(__kwarg_matches_type($kwargs, $(QuoteNode(target_sym)), $target_type))
        end
        foldl((a, b) -> :($a && $b), satisfies_exprs)
    end

    # Construct the expression
    return quote
        Base.Experimental.register_error_hint(
            Base.MethodError,
        ) do io, exc, $argtypes, $kwargs
            is_target_method = (
                ($fname_check_expr) &&
                ($arg_length_check_expr) &&
                ($arg_type_check_expr) &&
                ($kwarg_length_check_expr) &&
                ($kwarg_type_check_expr)
            )
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
