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
    sence = contains ? "presence" : "absence "
    @info "checking for $(sence) of `$msg`"
    try
        f()
    catch e
        estr = sprint(showerror, e)
        contains && @test occursin(msg, estr)
        !contains && @test !occursin(msg, estr)
        return
    end
    # Fail if no error was thrown. Julia 1.6 doesn't have try-else, so we have to put a
    # return in the catch and do this outside
    @test false
end


@testset verbose = true "MethodErrorHints.jl" begin
    @testset verbose = true "no args/kwargs" begin
        function fooempty end
        m = "__fooempty__"
        @method_error_hint fooempty() m
        test_throws_with(m, () -> fooempty(); contains = true)
        test_throws_with(m, () -> fooempty(1); contains = false)
        test_throws_with(m, () -> fooempty("hello"); contains = false)
        test_throws_with(m, () -> fooempty(; x = 1); contains = false)
    end

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
            test_throws_with(m, () -> foo1(1; x = 1); contains = false)
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
            test_throws_with(m, () -> foo1t(T(); x = 1); contains = false)
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
        test_throws_with(m, () -> foo2(1; x = 1); contains = false)
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
        test_throws_with(m, () -> foo3(1; x = 1); contains = false)
    end

    @testset "args..." begin
        function foo4 end
        m = "__foo4__args__...__"
        @method_error_hint foo4(::Int, args...) m
        test_throws_with(m, () -> foo4(1, 1); contains = true)
        test_throws_with(m, () -> foo4(1, 1, :a); contains = true)
        test_throws_with(m, () -> foo4(1, 2.0); contains = true)
        test_throws_with(m, () -> foo4(1, "hello"); contains = true)
        test_throws_with(m, () -> foo4(1, []); contains = true)
        test_throws_with(m, () -> foo4(1); contains = true)
        test_throws_with(m, () -> foo4(1, :s, :t); contains = true)
        test_throws_with(m, () -> foo4(); contains = false)
        test_throws_with(m, () -> foo4(2.0); contains = false)
        test_throws_with(m, () -> foo4(1, 1; x = 1); contains = false)
    end

    @testset "args::T..." begin
        function foo5 end
        m = "__foo5__args__T__...__"
        @method_error_hint foo5(::Int, args::Symbol...) m
        test_throws_with(m, () -> foo5(1, :a); contains = true)
        test_throws_with(m, () -> foo5(1, :a, :b); contains = true)
        test_throws_with(m, () -> foo5(1); contains = true)
        test_throws_with(m, () -> foo5(1, 2.0); contains = false)
        test_throws_with(m, () -> foo5(1, "hello"); contains = false)
        test_throws_with(m, () -> foo5(1); contains = true)
        test_throws_with(m, () -> foo5(); contains = false)
        test_throws_with(m, () -> foo5(2.0); contains = false)
        test_throws_with(m, () -> foo5(2.0, :a, :b); contains = false)
        test_throws_with(m, () -> foo5(2; x = 2); contains = false)
        test_throws_with(m, () -> foo5(2, :a; x = 2); contains = false)
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

    @testset "; x=default" begin
        function fookwdef end
        m = "__fookwdef__x__Any__"
        @method_error_hint fookwdef(; x = 3) m
        test_throws_with(m, () -> fookwdef(; x = 1); contains = true)
        test_throws_with(m, () -> fookwdef(; x = 2.0); contains = true)
        test_throws_with(m, () -> fookwdef(; x = "hello"); contains = true)
        test_throws_with(m, () -> fookwdef(; x = []); contains = true)
        test_throws_with(m, () -> fookwdef(; x = 1, y = 1); contains = false)
        test_throws_with(m, () -> fookwdef(; y = 1); contains = false)
        test_throws_with(m, () -> fookwdef(); contains = true)
        test_throws_with(m, () -> fookwdef(1); contains = false)
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

    @testset "; x=default" begin
        function fookw2def end
        m = "__fookw2def__x__Int__"
        @method_error_hint fookw2def(; x::Int = 3) m
        test_throws_with(m, () -> fookw2def(; x = 1); contains = true)
        test_throws_with(m, () -> fookw2def(; x = 2.0); contains = false)
        test_throws_with(m, () -> fookw2def(; x = "hello"); contains = false)
        test_throws_with(m, () -> fookw2def(; x = []); contains = false)
        test_throws_with(m, () -> fookw2def(; x = 1, y = 1); contains = false)
        test_throws_with(m, () -> fookw2def(; y = 1); contains = false)
        test_throws_with(m, () -> fookw2def(); contains = true)
        test_throws_with(m, () -> fookw2def(1); contains = false)
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

    @testset "a mixture of kwargs" begin
        function fookw4 end
        m = "__fookw4__kwargs__...__"
        @method_error_hint fookw4(; x::Int, y = 4, kwargs...) m
        test_throws_with(m, () -> fookw4(; x = 1); contains = true)
        test_throws_with(m, () -> fookw4(; x = 1, y = 2); contains = true)
        test_throws_with(m, () -> fookw4(; x = 1, y = 2.0); contains = true)
        test_throws_with(m, () -> fookw4(; y = "hello"); contains = false)
        test_throws_with(m, () -> fookw4(; x = 2.0); contains = false)
        test_throws_with(m, () -> fookw4(; z = :a); contains = false)
        test_throws_with(m, () -> fookw4(; x = 3, z = :a); contains = true)
        test_throws_with(m, () -> fookw4(); contains = false)
        test_throws_with(m, () -> fookw4(1); contains = false)
    end

    @testset "undefined function" begin
        # Make sure that if @method_error_hint is applied to a non-existent function, it
        # doesn't cause crashes when checking against the function.
        function this_is_defined end
        m = "__undefinedfunc__x__Int__"
        @method_error_hint undefinedfunc(x::Int) m
        # This will throw a MethodError. It won't cause the error hint to print, but 
        # the code in the expanded macro will run, and we would like to make sure it
        # doesn't crash.
        test_throws_with(m, () -> this_is_defined(); contains = false)
    end

    @testset "undefined type" begin
        # Make sure that if @method_error_hint is applied with a non-existent type, it
        # doesn't cause crashes when checking against the function.

        @testset "arg" begin
            function foobadtype end
            m = "__foobadtype__x__DoesNotExist__"
            @method_error_hint foobadtype(x::DoesNotExist) m
            test_throws_with(m, () -> foobadtype(); contains = false)
        end
        @testset "kwarg" begin
            function foobadtype2 end
            m = "__foobadtype2__x__DoesNotExist__"
            @method_error_hint foobadtype2(; x::DoesNotExist) m
            test_throws_with(m, () -> foobadtype2(); contains = false)
        end
    end

    @testset "with IO handler" begin
        # Try different syntaxes for specifying the function.
        @testset "named function" begin
            function fooionamed end
            m = "__fooionamed__"
            f = io -> println(io, m)
            @method_error_hint fooionamed() f
            test_throws_with(m, () -> fooionamed(); contains = true)
        end
        @testset "anonymous function 1" begin
            function fooioanon1 end
            m = "__fooioanon1__"
            @method_error_hint fooioanon1() io -> println(io, m)
            test_throws_with(m, () -> fooioanon1(); contains = true)
        end
        @testset "anonymous function 2" begin
            function fooioanon2 end
            m = "__fooioanon2__"
            @method_error_hint fooioanon2() function (io)
                print(io, m)
            end
            test_throws_with(m, () -> fooioanon2(); contains = true)
        end
    end
end
