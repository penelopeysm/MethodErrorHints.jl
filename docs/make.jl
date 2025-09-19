using Documenter
using DocumenterInterLinks
using MethodErrorHints

links = InterLinks("Julia" => "https://docs.julialang.org/en/v1/")

makedocs(;
    sitename = "MethodErrorHints.jl",
    pages = ["Home" => "index.md"],
    plugins = [links],
)
