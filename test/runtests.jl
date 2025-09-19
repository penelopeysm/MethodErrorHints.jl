using MethodErrorHints, Test

"""
    test_throws_with(msg, f; contains)

Helper function to test if a function throws an error that either contains or does not
contain a given message.

`f` must be a function which when called with no arguments runs the code to be tested
and throws an error.

If `contains` is true, the test checks that the error message does contain `msg`. Otherwise
it checks that the error message does not contain `msg`.
"""
function test_throws_with(msg, f; contains)
    try
        f()
    catch e
        estr = sprint(showerror, e)
        contains && @test occursin(msg, estr)
        !contains && @test !occursin(msg, estr)
    else
        @test false
    end
end

function foo1 end

@testset verbose = true "MethodErrorHints.jl" begin
    @method_error_hint foo1(x::Int) "foo1_1"
    test_throws_with("foo1_1", () -> foo1(1); contains = true)
end
