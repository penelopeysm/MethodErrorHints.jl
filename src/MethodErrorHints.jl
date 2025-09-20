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

For example, this macro should be called within the [`__init__`](@extref) function of a
module, to ensure that the hint is registered when the module is loaded. Furthermore, since
this is an experimental Julia feature, if you wish to guard against breakage you should gate
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

In this first example, `f1` must be called with two positional arguments and a keyword
argument `z` that have precisely the types specified, plus a keyword argument `z`. Names of
positional arguments are optional as long as a type is specified, but names of keyword
arguments are mandatory. If a positional argument is untyped like `y` here, it is treated as
`Any`.

```julia
function f1 end
@method_error_hint f1(x::Int, y; z::String) "My error hint" color=:red
# f1(3,   :a ; z="hello"     ) ✔
# f1(3,   2  ; z="hello"     ) ✔
# f1(3,   :a                 ) ✘ (no `z` keyword argument)
# f1(3.0, :a ; z="hello"     ) ✘ (type of `x` is wrong)
# f1(3,   :a ; z=1           ) ✘ (type of `z` is wrong)
# f1(3       ; z="hello"     ) ✘ (missing positional argument `y`)
# f1(3,   :a ; z="hello", w=1) ✘ (extra keyword argument)
```

Here, `f2` must take a single positional argument of any type, and optionally a keyword
argument `z`. If `z` is provided, it must be of type `Int`. The macro does not actually use
the default value specified for the keyword argument; you can use `undef` to avoid
specifying one.

```julia
function f2 end
@method_error_hint f2(x; z::Int=3) "Another error hint" bold=true
# f2(3                )  ✔
# f2(3     ; z=2      )  ✔
# f2(3     ; z="hello")  ✘ (type of `z` is wrong)
# f2(3, :a            )  ✘ (extra positional argument)
# f2(3, :a ; z=2      )  ✘ (extra positional argument)
```

Variable-length positional and keyword arguments are supported.

```julia
function f3 end
@method_error_hint f3(args...; kwargs...) "Another hint" italic=true
# Any invocation of `f3` will trigger this.
```

# Known limitations

Please note that these are unlikely to be fixed in the future.

- Type parameters and `where`-clauses are not supported, for example `f(x::T, y::T) where
  {T}`.

- `Vararg` annotations are not supported. (But annotations on splatted arguments, like
  `args::Int...`, are supported.)

If you need this functionality, you should probably craft your own error hint using
[`Base.Experimental.register_error_hint`](@extref). For example, the method signature
`f(x::T, y::T) where {T}` could be implemented as follows:

```julia
Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
    if exc.f === f && length(argtypes) == 2 && argtypes[1] == argtypes[2]
        printstyled(io, "My error hint"; color=:red)
    end
end

# Extended help

## Behind the scenes

This macro's only real job is to parse the method signature, and then generate a call to
[`Base.Experimental.register_error_hint`](@extref) that checks that the method the user
tried to invoke matches the signature. This is best illustrated by an example. This:

```julia
function f1 end
@method_error_hint f1(x::Int, y; z::String) "My error hint" color=:red
```

expands into something like this:

```julia
Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
    # This Dict is parsed from the method signature passed to the macro, i.e., this is the
    # 'target' signature we are trying to match.
    target_kwargtypes = Dict{Symbol,Any}(:z => String)
    # This Vector is also parsed from the method signature, and indicates which keyword
    # arguments are mandatory (i.e., have no default value in the method signature).
    mandatory_kwargs = [:z]
    # This one indicates whether the method signature has `kwargs...`.
    has_varkwargs = false
    # Extract the actual symbols of the keyword arguments passed in the invocation
    kwarg_symbols = __kwargs_symbols(kwargs)
    if (
        # Check that the function name is correct
        exc.f === f1
        # Check that number of positional arguments is correct
        && length(argtypes) == 2
        # Check that types of positional arguments are correct
        && argtypes[1] <: Int
        && argtypes[2] <: Any
        # Check that any mandatory keyword arguments are present (i.e., if there is no
        # default value in the method signature, it must be present in the invocation)
        && haskey(kwarg_symbols, :z)
        # Check that no unexpected keyword arguments are present (i.e., any keyword argument
        # in the invocation must either be specified in the method signature and obey the
        # type specified in the signature, or the method signature must have `kwargs...`).
        && all(collect(kwargs)) do (sym, typ)
            if haskey(target_kwargtypes, sym)
                # On Julia <= 1.10 we get values instead of types so we have to use `isa`
                # instead of `<:`
                typ <: target_kwargtypes[sym]
            else
                has_varkwargs
            end
        end
    )
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

# The role of `__kwargs_symbols` is to extract the symbols of the keyword arguments in the
# actual function invocation. This requires us to process the `kwargs` argument of
# `register_error_hint(...) do io, exc, argtypes, kwargs`. The type and contents of this
# argument differ on different Julia versions, hence this if/else.
@static if VERSION >= v"1.11"
    # On Julia 1.11, the `kwargs` obtained from `register_error_hint` are a list of
    # `(symbol, type)` tuples (but they have type Vector{Any}).
    __kwargs_symbols(v::Vector{Any})::Vector{Symbol} = map(first, v)
elseif VERSION >= v"1.6"
    # On Julia 1.6 - 1.10 the `kwargs` come out as some weird internal `Base.Iterators.Pairs`
    # type, which when `collect`ed gives a `Vector{Pair}` that can be iterated over as usual.
    # However, the second element of the Pair is the _value_ of the keyword argument, not
    # the type. In 1.10 `Base.Iterators.Pairs` is also available as `Base.Pairs` but not on
    # 1.6, so to cover all these we just use `Base.Iterators.Pairs`.
    __kwargs_symbols(v::Base.Iterators.Pairs)::Vector{Symbol} = map(first, collect(v))
    # If there are no kwargs it gives us an empty tuple, so we need this method too
    __kwargs_symbols(::Tuple{})::Vector{Symbol} = Symbol[]
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
    # Check that the function name is defined; if it's not defined then the error hint
    # itself will throw an error
    fname_defined_expr = Expr(:isdefined, esc(fname))
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
    vararg_type = :Any
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
            if i == nargs
                has_varargs = true
                vararg_type = if arg_expr.args[1] isa Symbol
                    :Any
                else
                    :($(esc(last(arg_expr.args[1].args))))
                end
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
        has_varargs ? :(length($argtypes) >= $(nargs - 1)) : :(length($argtypes) == $nargs)
    arg_type_check_expr = if isempty(target_argtypes)
        :(true)
    else
        satisfies_exprs = map(eachindex(target_argtypes)) do i
            :($argtypes[$i] <: $(target_argtypes[i]))
        end
        foldl((a, b) -> :($a && $b), satisfies_exprs)
    end
    vararg_type_check_expr =
        has_varargs ? :(all($argtypes[$nargs:end] .<: $vararg_type)) : :(true)

    # Determine number and types of keyword arguments
    n_kwargs = length(kwarg_exprs)
    target_kwargtypes = :(Dict{Symbol,Any}())
    mandatory_kwargs = Symbol[]
    has_varkwargs = false
    for (i, kwarg_expr) in enumerate(kwarg_exprs)
        if kwarg_expr isa Symbol
            # `x`
            sym, type = kwarg_expr, :Any
            push!(target_kwargtypes.args, Expr(:call, :(=>), QuoteNode(sym), esc(type)))
            push!(mandatory_kwargs, sym)
        elseif kwarg_expr.head === :(::)
            # `x::T`
            length(kwarg_expr.args) == 2 ||
                error("keyword argument type specification must be of the form `x::T`")
            sym, type = kwarg_expr.args[1], kwarg_expr.args[2]
            push!(target_kwargtypes.args, Expr(:call, :(=>), QuoteNode(sym), esc(type)))
            push!(mandatory_kwargs, sym)
        elseif kwarg_expr.head === :(...)
            if i == n_kwargs
                has_varkwargs = true
                continue
            else
                error("`...` can only appear in the final keyword argument")
            end
        elseif kwarg_expr.head === :kw
            first_arg = kwarg_expr.args[1]
            sym, type = if first_arg isa Symbol
                # `x=default`
                first_arg, :Any
            elseif first_arg isa Expr && first_arg.head === :(::)
                # `x::T=default`
                length(first_arg.args) == 2 ||
                    error("unsupported keyword argument expression: $kwarg_expr")
                first_arg.args
            else
                error("unsupported keyword argument expression: $kwarg_expr")
            end
            push!(target_kwargtypes.args, Expr(:call, :(=>), QuoteNode(sym), esc(type)))
        else
            error("unsupported keyword argument expression: $kwarg_expr")
        end
    end

    @gensym kwargs_symbols
    # This checks that all the mandatory kwargs (i.e., those specified in the method
    # signature without a default value) are present
    mandatory_kwargs_present_expr = if isempty(mandatory_kwargs)
        :(true)
    else
        foldl((a, b) -> :($a && $b), map(mandatory_kwargs) do sym
            :($(QuoteNode(sym)) in $kwargs_symbols)
        end)
    end

    # On Julia 1.11, the `kwargs` we get from `register_error_hint` contain the types
    # of the keyword arguments, so we use `<:` to check them. On earlier Julia versions
    # we actually get the values themselves so we have to use `isa`.
    isa_or_subtypes = @static if VERSION >= v"1.11"
        (<:)
    else
        isa
    end

    # Construct the expression
    return quote
        Base.Experimental.register_error_hint(
            Base.MethodError,
        ) do io, exc, $argtypes, kwargs
            target_kwargtypes = $target_kwargtypes
            $kwargs_symbols = __kwargs_symbols(kwargs)
            if (
                ($fname_defined_expr) &&
                ($fname_check_expr) &&
                ($arg_length_check_expr) &&
                ($arg_type_check_expr) &&
                ($vararg_type_check_expr) &&
                # all the given kwargs are allowed to be present (i.e., they are either
                # specified in the method signature with a type that matches the one
                # passed in the invocation, or the method signature has `kwargs...`). Note
                # that because we don't know the length or contents of `kwargs` at macro
                # time, we have to actually use `all` here rather than unfolding an
                # expression.
                all(collect(kwargs)) do (sym, type_or_val)
                    if haskey(target_kwargtypes, sym)
                        ($isa_or_subtypes)(type_or_val, target_kwargtypes[sym])
                    else
                        $has_varkwargs
                    end
                end &&
                ($mandatory_kwargs_present_expr)
            )
                printstyled(io, $(esc(msg)); $ps_kwargs_dict...)
            end
        end
    end
end

export @method_error_hint

end # module MethodErrorHints
