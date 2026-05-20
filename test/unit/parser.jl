using JuliaLangProjectHarness: parse_julia_file

@testset "parser" begin
    temp = mktempdir()
    source = joinpath(temp, "valid.jl")
    write(source, "module Valid\nexport run\nrun() = 1\nend\n")

    parsed = parse_julia_file(source)

    @test parsed.report.is_valid
    @test isnothing(parsed.report.parse_error)
    @test parsed.metrics.nonblank_line_count == 4
    @test parsed.syntax_facts.has_syntax_tree
end

@testset "parser namespace and api facts" begin
    temp = mktempdir()
    source = joinpath(temp, "entry.jl")
    write(
        source,
        """
        baremodule Example
        export run, Config
        public internal_api
        using JSON3
        using JSON3: read, write
        import Base: show
        import Dates
        end
        """,
    )

    parsed = parse_julia_file(source)

    @test length(parsed.syntax_facts.modules) == 1
    @test only(parsed.syntax_facts.modules).name == "Example"
    @test only(parsed.syntax_facts.modules).is_bare
    @test [(item.kind, item.names) for item in parsed.syntax_facts.exports] == [
        ("export", ["run", "Config"]),
        ("public", ["internal_api"]),
    ]
    @test [(item.kind, item.root, item.names) for item in parsed.syntax_facts.imports] == [
        ("using", "JSON3", String[]),
        ("using", "JSON3", ["read", "write"]),
        ("import", "Base", ["show"]),
        ("import", "Dates", String[]),
    ]
end

@testset "parser function facts" begin
    temp = mktempdir()
    source = joinpath(temp, "methods.jl")
    write(
        source,
        """
        function run(x, y::Int; verbose=false, mode=:fast)
            x + y
        end
        short(a, b=1, c::String="x") = a
        Base.show(io::IO, value::Thing) = print(io, value)
        macro demo(x)
            x
        end
        """,
    )

    parsed = parse_julia_file(source)

    @test [(item.kind, item.name, item.terminal_name) for item in parsed.syntax_facts.functions] == [
        ("function", "run", "run"),
        ("function", "short", "short"),
        ("function", "Base.show", "show"),
        ("macro", "demo", "demo"),
    ]
    @test parsed.syntax_facts.functions[1].positional_args == ["x", "y"]
    @test parsed.syntax_facts.functions[1].keyword_args == ["verbose", "mode"]
    @test parsed.syntax_facts.functions[2].positional_args == ["a", "b", "c"]
    @test parsed.syntax_facts.functions[3].positional_args == ["io", "value"]
    @test parsed.syntax_facts.functions[4].positional_args == ["x"]
end

@testset "parser type facts" begin
    temp = mktempdir()
    source = joinpath(temp, "types.jl")
    write(
        source,
        """
        abstract type AbstractThing end
        struct Thing{T} <: AbstractThing
            value::T
            name
        end
        mutable struct Box
            item::Thing
        end
        primitive type Word32 <: Unsigned 32 end
        """,
    )

    parsed = parse_julia_file(source)

    @test [(item.kind, item.name, item.parameters, item.supertype) for item in parsed.syntax_facts.types] == [
        ("abstract", "AbstractThing", String[], nothing),
        ("struct", "Thing", ["T"], "AbstractThing"),
        ("struct", "Box", String[], nothing),
        ("primitive", "Word32", String[], "Unsigned"),
    ]
    @test parsed.syntax_facts.types[2].fields == ["value", "name"]
    @test !parsed.syntax_facts.types[2].is_mutable
    @test parsed.syntax_facts.types[3].fields == ["item"]
    @test parsed.syntax_facts.types[3].is_mutable
end

@testset "parser macro and test facts" begin
    temp = mktempdir()
    source = joinpath(temp, "tests.jl")
    write(
        source,
        """
        using Test
        @testset "core" begin
            @test 1 == 1
            @test_throws ErrorException error("boom")
        end
        Test.@testset "qualified" begin
            Test.@test true
        end
        @time run()
        """,
    )

    parsed = parse_julia_file(source)

    @test [(item.name, item.terminal_name) for item in parsed.syntax_facts.macro_invocations] == [
        ("@testset", "testset"),
        ("@test", "test"),
        ("@test_throws", "test_throws"),
        ("Test.@testset", "testset"),
        ("Test.@test", "test"),
        ("@time", "time"),
    ]
    @test [(item.kind, item.name, item.label) for item in parsed.syntax_facts.tests] == [
        ("testset", "@testset", "core"),
        ("test", "@test", nothing),
        ("test_throws", "@test_throws", nothing),
        ("testset", "Test.@testset", "qualified"),
        ("test", "Test.@test", nothing),
    ]
end

@testset "parser include facts" begin
    temp = mktempdir()
    source = joinpath(temp, "entry.jl")
    write(
        source,
        """
        include("api.jl")
        include(joinpath("core", "impl.jl"))
        include(path)
        """,
    )

    parsed = parse_julia_file(source)
    includes = parsed.syntax_facts.includes

    @test length(includes) == 3
    @test includes[1].is_literal
    @test includes[1].target == "api.jl"
    @test includes[1].resolved_target == joinpath(temp, "api.jl")
    @test includes[2].is_literal
    @test includes[2].target == joinpath("core", "impl.jl")
    @test includes[2].resolved_target == joinpath(temp, "core", "impl.jl")
    @test !includes[3].is_literal
    @test isnothing(includes[3].target)
    @test includes[3].line == 3
    @test includes[3].column == 0
end
