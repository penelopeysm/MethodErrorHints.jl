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
        # showerror only works on 1.11 :(
        estr = sprint(showerror, e)
        contains && @test occursin(msg, estr)
        !contains && @test !occursin(msg, estr)
        return
    end
    # Julia 1.6 doesn't have try-else, so we have to put a return
    # in the catch and do this outside
    @test false
end


@testset verbose = true "MethodErrorHints.jl" begin
    @testset verbose = true "x::T" begin
        @testset "types in Base" begin
            function foo1 end
            m = "__foo1__x__Real__"
            @method_error_hint foo1(x::Real) m
            test_throws_with(m, () -> foo1(1); contains = true)
            test_throws_with(m, () -> foo1(2.0); contains = true)
            test_throws_with(m, () -> foo1("hello"); contains = false)
            test_throws_with(m, () -> foo1([]); contains = false)
            test_throws_with(m, () -> foo1(); contains = false)
            test_throws_with(m, () -> foo1(1, 1); contains = false)
        end

        @testset "custom types" begin
            function foo1t end
            struct T end
            m = "__foo1t__x__T__"
            @method_error_hint foo1t(x::T) m
            test_throws_with(m, () -> foo1t(T()); contains = true)
            test_throws_with(m, () -> foo1t(2.0); contains = false)
            test_throws_with(m, () -> foo1t("hello"); contains = false)
            test_throws_with(m, () -> foo1t([]); contains = false)
            test_throws_with(m, () -> foo1t(); contains = false)
            test_throws_with(m, () -> foo1t(1, 1); contains = false)
        end
    end

    @testset "::T" begin
        function foo2 end
        m = "__foo2__noname__Real__"
        @method_error_hint foo2(::Real) m
        test_throws_with(m, () -> foo2(1); contains = true)
        test_throws_with(m, () -> foo2(2.0); contains = true)
        test_throws_with(m, () -> foo2("hello"); contains = false)
        test_throws_with(m, () -> foo2([]); contains = false)
        test_throws_with(m, () -> foo2(); contains = false)
        test_throws_with(m, () -> foo2(1, 1); contains = false)
    end

    @testset "x" begin
        function foo3 end
        m = "__foo3__x__Any__"
        @method_error_hint foo3(x) m
        test_throws_with(m, () -> foo3(1); contains = true)
        test_throws_with(m, () -> foo3(2.0); contains = true)
        test_throws_with(m, () -> foo3("hello"); contains = true)
        test_throws_with(m, () -> foo3([]); contains = true)
        test_throws_with(m, () -> foo3(); contains = false)
        test_throws_with(m, () -> foo3(1, 1); contains = false)
    end

    @testset "args..." begin
        function foo4 end
        m = "__foo4__args__...__"
        @method_error_hint foo4(::Int, args...) m
        test_throws_with(m, () -> foo4(1, 1); contains = true)
        test_throws_with(m, () -> foo4(1, 2.0); contains = true)
        test_throws_with(m, () -> foo4(1, "hello"); contains = true)
        test_throws_with(m, () -> foo4(1, []); contains = true)
        test_throws_with(m, () -> foo4(1); contains = true)
        test_throws_with(m, () -> foo4(1, :s, :t); contains = true)
        test_throws_with(m, () -> foo4(); contains = false)
        test_throws_with(m, () -> foo4(2.0); contains = false)
    end

    @testset "; x" begin
        function fookw end
        m = "__fookw__x__Any__"
        @method_error_hint fookw(; x) m
        test_throws_with(m, () -> fookw(; x = 1); contains = true)
        test_throws_with(m, () -> fookw(; x = 2.0); contains = true)
        test_throws_with(m, () -> fookw(; x = "hello"); contains = true)
        test_throws_with(m, () -> fookw(; x = []); contains = true)
        test_throws_with(m, () -> fookw(; x = 1, y = 1); contains = false)
        test_throws_with(m, () -> fookw(; y = 1); contains = false)
        test_throws_with(m, () -> fookw(); contains = false)
        test_throws_with(m, () -> fookw(1); contains = false)
    end

    @testset "; x::T" begin
        function fookw2 end
        m = "__fookw2__x__Int__"
        @method_error_hint fookw2(; x::Int) m
        test_throws_with(m, () -> fookw2(; x = 1); contains = true)
        test_throws_with(m, () -> fookw2(; x = 2.0); contains = false)
        test_throws_with(m, () -> fookw2(; x = "hello"); contains = false)
        test_throws_with(m, () -> fookw2(; x = 1, y = 1); contains = false)
        test_throws_with(m, () -> fookw2(; y = 1); contains = false)
        test_throws_with(m, () -> fookw2(); contains = false)
        test_throws_with(m, () -> fookw2(1); contains = false)
    end

    @testset "; kwargs..." begin
        function fookw3 end
        m = "__fookw3__kwargs__...__"
        @method_error_hint fookw3(; x::Int, kwargs...) m
        test_throws_with(m, () -> fookw3(; x = 1); contains = true)
        test_throws_with(m, () -> fookw3(; x = 1, y = 2); contains = true)
        test_throws_with(m, () -> fookw3(; x = 1, y = 2.0); contains = true)
        test_throws_with(m, () -> fookw3(; y = "hello"); contains = false)
        test_throws_with(m, () -> fookw3(; x = 2.0); contains = false)
        test_throws_with(m, () -> fookw3(); contains = false)
        test_throws_with(m, () -> fookw3(1); contains = false)
    end
end
