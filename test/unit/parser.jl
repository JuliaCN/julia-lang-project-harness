using JuliaLangProjectHarness: parse_julia_file

@testset "parser" begin
    temp = mktempdir()
    source = joinpath(temp, "valid.jl")
    write(source, "module Valid\nexport run\nrun() = 1\nend\n")

    parsed = parse_julia_file(source)

    @test parsed.report.is_valid
    @test isnothing(parsed.report.parse_error)
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
