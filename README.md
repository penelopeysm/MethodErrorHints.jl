# MethodErrorHints.jl

[**Documentation**](https://pysm.dev/MethodErrorHints.jl/)

This package exports a single macro, `@method_error_hint`, which lets you define error hints for specific function methods.

For example, the code below will print "my error message" in blue when `foo1(1)` is called.
(GitHub can't show you the coloured output, but if you run this in a Julia REPL you will see it.)

```julia
julia> using MethodErrorHints

julia> function foo1 end
foo1 (generic function with 0 methods)

julia> @method_error_hint foo1(x::Int) "my error message" color=:blue

julia> foo1(1)
ERROR: MethodError: no method matching foo1(::Int64)
The function `foo1` exists, but no method is defined for this combination of argument types.
my error message
Stacktrace:
 [1] top-level scope
   @ REPL[4]:1

julia> foo1("hello")  # No hint here as it doesn't match the signature with the hint
ERROR: MethodError: no method matching foo1(::String)
The function `foo1` exists, but no method is defined for this combination of argument types.
Stacktrace:
 [1] top-level scope
   @ REPL[5]:1
```

The macro takes two mandatory arguments (which must come first):

- The method signature that you want to attach the hint to. This mimics Julia function definition syntax, and can include both positional and keyword arguments.
- The hint message.

Keyword arguments to `@method_error_hint` are allowed _after_ these two arguments, and are simply forwarded to `Base.printstyled` (see [its documentation here](https://docs.julialang.org/en/v1/base/io-network/#Base.printstyled) for a full list of what is allowed).
