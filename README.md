# MethodErrorHints.jl

[**Documentation**](https://pysm.dev/MethodErrorHints.jl/)

This package exports a single macro, `@method_error_hint`, which lets you (more easily) define error hints for specific method signatures.

For example, the code below will print "Hello, world" in blue when `f(1)` is called.
(GitHub can't show you the coloured output, but if you run this in a Julia REPL you will see it.)

```julia
julia> using MethodErrorHints

julia> function f end
f (generic function with 0 methods)

julia> @method_error_hint f(x::Int) "\n\n    Hello, world\n" color=:blue

julia> f(1)
ERROR: MethodError: no method matching f(::Int64)
The function `f` exists, but no method is defined for this combination of argument types.

    Hello, world

Stacktrace:
 [1] top-level scope
   @ REPL[4]:1
```

However, calling `f("hello")` will not print the message, because that invocation does not match the signature `f(x::Int)`.

```julia
julia> f("hello")
ERROR: MethodError: no method matching f(::String)
The function `f` exists, but no method is defined for this combination of argument types.
Stacktrace:
 [1] top-level scope
   @ REPL[5]:1
```

Please see [the documentation](https://pysm.dev/MethodErrorHints.jl) for more details.
