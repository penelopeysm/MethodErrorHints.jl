"""
    MethodErrorHints.jl

A Julia package providing a macro to register custom hint messages for `MethodError`s.

This package exports a single macro, [`@method_error_hint`](@ref), which allows you to
register custom hint messages to be displayed when a `MethodError` is thrown for a function
call.
"""
module MethodErrorHints

"""
    @method_error_hint sig msg [key=val...]

Register a hint message `msg` to be printed when a `MethodError` is thrown for a function
call matching the signature `sig`.

The signature `sig` is specified in a similar way to a typical method definition in Julia.
See below for examples.

Additional key-value pairs `key=val` are passed to [`Base.printstyled`](@extref) when
printing the hint message, allowing customization of the appearance of the message. Please
see the documentation of [`Base.printstyled`](@extref) for the available options.

# Usage

This function uses [`Base.Experimental.register_error_hint`](@extref), and thus all the
suggestions in its docstring are also applicable here.

For example, this macro should be called within the `__init__` function of a module, to
ensure that the hint is registered when the module is loaded. Furthermore, since this is 
an experimental Julia feature, if you wish to guard against breakage you should gate
calls to this macro behind `if isdefined(Base.Experimental, :register_error_hint)`.

```julia
if isdefined(Base.Experimental, :register_error_hint)
    function __init__()
        @method_error_hint f1(x::Int, y; z::String) "My error hint" color=:red
    end
end
```

# Examples

Here, ✔ indicates an invocation that will trigger the hint, and ✘ indicates one that will
not. For the most part, the rules exactly mimic method dispatch in Julia, with some small
exceptions noted in the next section.

```julia
@method_error_hint f1(x::Int, y; z::String) "My error hint" color=:red
# f1(3,   :a ; z="hello"     ) ✔
# f1(3,   2  ; z="hello"     ) ✔
# f1(3,   :a                 ) ✘ (no `z` keyword argument)
# f1(3.0, :a ; z="hello"     ) ✘ (type of `x` is wrong)
# f1(3,   :a ; z=1           ) ✘ (type of `z` is wrong)
# f1(3       ; z="hello"     ) ✘ (missing positional argument `y`)
# f1(3,   :a ; z="hello", w=1) ✘ (extra keyword argument)
```

```julia
@method_error_hint f2(x; z::Int=3) "Another error hint" bold=true
# f2(3                )  ✔
# f2(3     ; z=2      )  ✔
# f2(3     ; z="hello")  ✘ (type of `z` is wrong)
# f2(3, :a            )  ✘ (extra positional argument)
# f2(3, :a ; z=2      )  ✘ (extra positional argument)
```

```julia
@method_error_hint f3(args...; kwargs...) "Another hint" italic=true
# Any invocation of `f3` will trigger this.
```

# Known limitations

- `Vararg` annotations on splatted positional arguments are not supported. This will probably
  be fixed in a future version.

- Type parameters and `where`-clauses are not supported, for example `f(x::T, y::T) where
  {T}`. If you need this functionality, you should consider crafting your own error hint
  (for this particular signature, following the example in the docstring of
  [`Base.Experimental.register_error_hint`](@extref), you could check that `length(argtypes)
  == 2 && argtypes[1] == argtypes[2]`). Support for type parameters will probably never be
  implemented in this package.

# Extended help

## Behind the scenes

This macro's only real job is to parse the method signature, and then generate a call to
[`Base.Experimental.register_error_hint`](@extref) that checks that the method the user
tried to invoke matches the signature. This is best illustrated by an example. This:

```julia
@method_error_hint f1(x::Int, y; z::String) "My error hint" color=:red
```

expands into something like this (modulo variable names and other trivial differences):

```julia
Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
    is_target_method = (
        exc.f === f1
        && length(argtypes) == 2
        && argtypes[1] <: Int
        && argtypes[2] <: Any
        && length(kwargs) == 1
        && MethodErrorHints.__kwarg_matches_type(kwargs, :z, String)
    )
    if is_target_method
        println(io)
        printstyled(io, "My error hint"; :color=:red)
    end
end
```

If you would like to see this in more detail, please refer to [the source code of this
package](https://github.com/penelopeysm/MethodErrorHints.jl).
"""
macro method_error_hint(args...)
    expr = args[1]
    msg = args[2]
    printstyled_kwargs = args[3:end]
    return _method_error_hint(expr, msg, printstyled_kwargs)
end

@static if VERSION >= v"1.11"
    # On Julia 1.11, the kwargs passed into `register_error_hint` are a list of (symbol,
    # type) tuples (but they have type Vector{Any})
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
elseif VERSION >= v"1.6"
    # On Julia 1.6 - 1.10 it's some weird internal Base.Iterators.Pairs type, which when
    # `collect`ed gives a Vector{Pair} that can be iterated over as usual.
    # In 1.10 it's also available as Base.Pairs but not on 1.6, so to cover all these
    # we just use Base.Iterators.Pairs.
    function __kwarg_matches_type(
        kwarg_dict::Base.Iterators.Pairs,
        kwarg_sym::Symbol,
        expected_type::Type,
    )
        for (sym, val) in collect(kwarg_dict)
            if sym === kwarg_sym
                return val isa expected_type
            end
        end
        return false
    end
end

function _method_error_hint(expr::Expr, msg, printstyled_kwargs::Tuple)::Expr
    # Input validation
    expr.head === :where && error(
        "@method_error_hint does not support type parameters and `where` clauses in the method signature",
    )
    expr.head === :call || error("@method_error_hint must be applied to a function call")

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

    # Decide which arguments of `expr` are positional and which are keyword. If keyword
    # arguments are present, they are always grouped together as the second argument, with a
    # head of :parameters. Any remaining arguments are positional.
    (arg_exprs, kwarg_exprs) = if length(expr.args) == 1
        # no arguments at all
        [], ()
    elseif expr.args[2] isa Expr && expr.args[2].head === :parameters
        # there are keyword arguments
        expr.args[3:end], expr.args[2].args
    else
        # no keyword arguments
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
                println(io)
                printstyled(io, $(esc(msg)); $ps_kwargs_dict...)
            end
        end
    end
end

export @method_error_hint

end # module MethodErrorHints
