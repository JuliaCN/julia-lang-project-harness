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

@testset "parser Moshi syntax facts" begin
    temp = mktempdir()
    source = joinpath(temp, "moshi.jl")
    write(
        source,
        """
        module MoshiShape
        using Moshi.Data: @data
        using Moshi.Match: @match
        using Moshi.Derive: @derive

        @data Message begin
            Quit
            Write(String)
        end

        @derive Message[Show, Hash]

        function route(value)
            @match value begin
                Message.Quit() => nothing
                Message.Write(text) => text
                _ => nothing
            end
        end
        end
        """,
    )

    parsed = parse_julia_file(source)

    @test [
        (
            item.kind,
            item.macro_name,
            item.target_name,
            item.variant_names,
            item.case_names,
            item.case_patterns,
        ) for item in
        parsed.syntax_facts.moshi
    ] == [
        ("data", "@data", "Message", ["Quit", "Write"], String[], String[]),
        ("derive", "@derive", "Message", String[], String[], String[]),
        (
            "match",
            "@match",
            "value",
            String[],
            ["Quit", "Write"],
            ["Message.Quit", "Message.Write"],
        ),
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
