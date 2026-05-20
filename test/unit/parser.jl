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
        function run(x, y::Int, force::Bool, dry_run=false; verbose=false, mode::AbstractString="fast")
            x + y
        end
        short(a, b=1, c::String="x", enabled::Core.Bool=true) = a
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
    @test parsed.syntax_facts.functions[1].positional_args == ["x", "y", "force", "dry_run"]
    @test parsed.syntax_facts.functions[1].bool_positional_args == ["force", "dry_run"]
    @test parsed.syntax_facts.functions[1].stringly_domain_args == ["mode"]
    @test parsed.syntax_facts.functions[1].keyword_args == ["verbose", "mode"]
    @test parsed.syntax_facts.functions[2].positional_args == ["a", "b", "c", "enabled"]
    @test parsed.syntax_facts.functions[2].bool_positional_args == ["enabled"]
    @test isempty(parsed.syntax_facts.functions[2].stringly_domain_args)
    @test parsed.syntax_facts.functions[3].positional_args == ["io", "value"]
    @test parsed.syntax_facts.functions[4].positional_args == ["x"]
end

@testset "parser function dispatch facts" begin
    temp = mktempdir()
    source = joinpath(temp, "dispatch.jl")
    write(
        source,
        """
        function run(x::T, y::Vector{T}; mode::Symbol=:fast)::T where {T<:Real}
            x
        end
        short(x::Int)::String = string(x)
        Base.show(io::IO, value::Thing{T}) where {T} = print(io, value)
        """,
    )

    parsed = parse_julia_file(source)

    @test [(item.name, item.return_type, item.where_parameters) for item in parsed.syntax_facts.functions] == [
        ("run", "T", ["T<:Real"]),
        ("short", "String", String[]),
        ("Base.show", nothing, ["T"]),
    ]
    @test parsed.syntax_facts.functions[1].typed_positional_args == ["x::T", "y::Vector{T}"]
    @test parsed.syntax_facts.functions[2].typed_positional_args == ["x::Int"]
    @test parsed.syntax_facts.functions[3].typed_positional_args == ["io::IO", "value::Thing{T}"]
    @test [(call.name, call.terminal_name) for call in parsed.syntax_facts.calls] == [
        ("string", "string"),
        ("print", "print"),
    ]
end

@testset "parser binding facts" begin
    temp = mktempdir()
    source = joinpath(temp, "bindings.jl")
    write(
        source,
        """
        const DEFAULT_LIMIT = 8
        const TYPED_LIMIT::Int = 13
        global CACHE = Dict()
        """,
    )

    parsed = parse_julia_file(source)

    @test [
        (
            item.kind,
            item.name,
            item.terminal_name,
            item.type_annotation,
            item.is_constant,
        ) for item in parsed.syntax_facts.bindings
    ] == [
        ("const", "DEFAULT_LIMIT", "DEFAULT_LIMIT", nothing, true),
        ("const", "TYPED_LIMIT", "TYPED_LIMIT", "Int", true),
        ("global", "CACHE", "CACHE", nothing, false),
    ]
end

@testset "parser control flow facts" begin
    temp = mktempdir()
    source = joinpath(temp, "flow.jl")
    write(
        source,
        """
        function nested(values)
            if !isempty(values)
                for value in values
                    while value > 0
                        try
                            println(value)
                            break
                        catch
                            break
                        end
                    end
                end
            end
            values
        end
        """,
    )

    parsed = parse_julia_file(source)
    function_fact = only(parsed.syntax_facts.functions)

    @test function_fact.control_flow_depth == 4
    @test function_fact.control_flow_kinds == ["if", "for", "while", "try"]
end

@testset "parser function body shape facts" begin
    temp = mktempdir()
    source = joinpath(temp, "body_shape.jl")
    write(
        source,
        """
        function pipeline(value)
            loaded = load(value)
            normalized = normalize(loaded)
            scored = score(normalized)
            rendered = render(scored)
            rendered
        end
        """,
    )

    parsed = parse_julia_file(source)
    function_fact = only(parsed.syntax_facts.functions)

    @test function_fact.body_statement_count == 5
    @test function_fact.body_named_calls == ["load", "normalize", "score", "render"]
end

@testset "parser function macro facts" begin
    temp = mktempdir()
    source = joinpath(temp, "macros.jl")
    write(
        source,
        """
        function staged(value)
            @alpha value
            @beta begin
                @gamma value
            end
            function inner()
                @delta value
            end
            value
        end
        """,
    )

    parsed = parse_julia_file(source)
    function_fact = first(parsed.syntax_facts.functions)

    @test function_fact.macro_invocation_count == 3
    @test function_fact.macro_invocation_names == ["alpha", "beta", "gamma"]
end

@testset "parser call facts" begin
    temp = mktempdir()
    source = joinpath(temp, "calls.jl")
    write(
        source,
        """
        function run(x; verbose=false)
            JSON3.read(x; allow_inf=true)
            local total = x + 1
        end
        short(y) = helper(y)
        macro demo(x)
            println(x)
        end
        @time run(1)
        Test.@test run(2) == 2
        """,
    )

    parsed = parse_julia_file(source)
    calls = parsed.syntax_facts.calls

    @test [(item.name, item.terminal_name, item.argument_count, item.keyword_args) for item in calls] == [
        ("JSON3.read", "read", 1, ["allow_inf"]),
        ("helper", "helper", 1, String[]),
        ("println", "println", 1, String[]),
        ("run", "run", 1, String[]),
        ("run", "run", 1, String[]),
    ]
    @test !("short" in [item.name for item in calls])
    @test !("demo" in [item.name for item in calls])
end

@testset "parser docstring facts" begin
    temp = mktempdir()
    source = joinpath(temp, "docs.jl")
    write(
        source,
        """
        \"\"\"Package module docs.\"\"\"
        module Docs
        \"\"\"Run a value.

        Keeps the first paragraph searchable.
        \"\"\"
        run(value) = value
        \"\"\"A named payload.\"\"\"
        struct Payload
            value::Int
        end
        \"\"\"Public constant.\"\"\"
        const DEFAULT_PAYLOAD = Payload(1)
        \"\"\"Shared cache.\"\"\"
        global CACHE = Dict()
        end
        """,
    )

    parsed = parse_julia_file(source)

    @test [
        (item.target_kind, item.target_name, item.text) for item in
        parsed.syntax_facts.docstrings
    ] == [
        ("module", "Docs", "Package module docs."),
        (
            "function",
            "run",
            "Run a value.\n\nKeeps the first paragraph searchable.\n",
        ),
        ("struct", "Payload", "A named payload."),
        ("const", "DEFAULT_PAYLOAD", "Public constant."),
        ("global", "CACHE", "Shared cache."),
    ]
end

@testset "parser identifier facts" begin
    temp = mktempdir()
    source = joinpath(temp, "identifiers.jl")
    write(
        source,
        """
        module Identifiers
        struct Payload
            value::Int
        end
        run(value::Payload) = JSON3.read(string(value))
        end
        """,
    )

    parsed = parse_julia_file(source)
    identifiers = parsed.syntax_facts.identifiers

    @test any(
        item -> item.name == "Identifiers" &&
                item.parent_kind == "module" &&
                item.line == 1,
        identifiers,
    )
    @test any(
        item -> item.name == "Payload" && item.parent_kind == "struct",
        identifiers,
    )
    @test any(
        item -> item.name == "JSON3" &&
                item.parent_kind == "." &&
                item.parent_expression == "JSON3.read",
        identifiers,
    )
    @test any(
        item -> item.name == "value" && item.parent_kind == "call",
        identifiers,
    )
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
            mode::Symbol = :ready
        end
        Base.@kwdef mutable struct Box
            item::Thing
            enabled::Bool = true
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
    @test parsed.syntax_facts.types[2].fields == ["value", "name", "mode"]
    @test parsed.syntax_facts.types[2].typed_fields == ["value::T", "mode::Symbol"]
    @test parsed.syntax_facts.types[2].defaulted_fields == ["mode"]
    @test [
        (field.owner_name, field.name, field.type_annotation, field.has_default) for field in
        parsed.syntax_facts.types[2].field_facts
    ] == [
        ("Thing", "value", "T", false),
        ("Thing", "name", nothing, false),
        ("Thing", "mode", "Symbol", true),
    ]
    @test !parsed.syntax_facts.types[2].is_mutable
    @test parsed.syntax_facts.types[3].fields == ["item", "enabled"]
    @test parsed.syntax_facts.types[3].typed_fields == ["item::Thing", "enabled::Bool"]
    @test parsed.syntax_facts.types[3].defaulted_fields == ["enabled"]
    @test [
        (field.owner_name, field.name, field.type_annotation, field.has_default) for field in
        parsed.syntax_facts.types[3].field_facts
    ] == [
        ("Box", "item", "Thing", false),
        ("Box", "enabled", "Bool", true),
    ]
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
