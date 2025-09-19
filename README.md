# MethodErrorHints.jl

This package exports a single macro, `@method_error_hint`, which lets you define error hints for specific function methods.

For example, the code below will print "my error message" in blue when `foo1(1)` is called.

```julia
using MethodErrorHints

function foo end

@method_error_hint foo(x::Int) "my error message" color=:blue

foo1(1)
```

The macro takes two mandatory arguments (which must come first):

- The method signature that you want to attach the hint to. This mimics Julia function definition syntax. **Note: keyword arguments are not yet supported**
- The hint message.

Keyword arguments are allowed _after_ these two arguments, and are simply forwarded to `Base.printstyled` (see [its documentation here](https://docs.julialang.org/en/v1/base/io-network/#Base.printstyled)) for a full list of what is allowed).
