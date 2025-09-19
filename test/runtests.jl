using MethodErrorHints, Test

function foo1 end

@testset verbose = true "MethodErrorHints.jl" begin
    @method_error_hint foo1(x::Int) "foo1_1"
    @test_throws "foo1_1" foo1(1)
end
