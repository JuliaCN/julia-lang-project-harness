@testset "project search index" begin
    root = mktempdir()
    write(
        joinpath(root, "Project.toml"),
        """
        name = "Example"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"

        [extras]
        Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

        [targets]
        test = ["Test"]
        """,
    )
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "test"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        export run, Config, DEFAULT_LIMIT
        using Dates
        include("api.jl")
        Base.@kwdef struct Config
            value::Int
            mode::Symbol = :fast
        end
        \"\"\"Default public limit.\"\"\"
        const DEFAULT_LIMIT::Int = 8
        end
        """,
    )
    write(
        joinpath(root, "src", "api.jl"),
        """
        \"\"\"Run a value through the public API.\"\"\"
        function run(value::T; verbose=false)::String where {T<:Integer}
            @alpha helper(value)
        end
        helper(value) = string(value)
        """,
    )
    write(
        joinpath(root, "test", "runtests.jl"),
        "using Test\n@testset \"search\" begin\n@test run(1) == 1\nend\n",
    )

    entries = julia_project_search_index(root)

    @test any(entry -> entry.kind == "module" && entry.name == "Example", entries)
    @test any(entry -> entry.kind == "export" && entry.name == "run", entries)
    @test any(entry -> entry.kind == "using" && entry.name == "Dates", entries)
    @test any(
        entry -> entry.kind == "struct" &&
                 entry.name == "Config" &&
                 occursin("fields=value,mode", entry.detail) &&
                 occursin("typed=value::Int,mode::Symbol", entry.detail) &&
                 occursin("defaults=mode", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "field" &&
                 entry.name == "Config.mode" &&
                 "field" in entry.tags &&
                 occursin("Config.mode::Symbol default", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "const" &&
                 entry.name == "DEFAULT_LIMIT" &&
                 "binding" in entry.tags &&
                 "constant" in entry.tags &&
                 occursin("::Int", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "function" &&
                 entry.name == "run" &&
                 occursin("verbose", entry.search_text) &&
                 occursin("typed=value::T", entry.detail) &&
                 occursin("returns=String", entry.detail) &&
                 occursin("where=T<:Integer", entry.detail) &&
                 occursin("macros=1:alpha", entry.detail) &&
                 "method" in entry.tags,
        entries,
    )
    @test any(entry -> entry.kind == "include" && entry.name == "api.jl", entries)
    @test any(
        entry -> entry.kind == "call" &&
                 entry.name == "helper" &&
                 "call" in entry.tags &&
                 occursin("args=1", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "doc" &&
                 entry.name == "run" &&
                 "function" in entry.tags &&
                 occursin("Run a value", entry.search_text),
        entries,
    )
    @test any(
        entry -> entry.kind == "identifier" &&
                 entry.name == "helper" &&
                 "call" in entry.tags,
        entries,
    )
    @test any(entry -> entry.kind == "testset" && entry.name == "search", entries)
    @test all(entry -> !isnothing(entry.location.path), entries)

    doc_results = search_julia_index(entries, "public API"; tags=["doc"], limit=3)
    @test !isempty(doc_results)
    @test first(doc_results).entry.kind == "doc"
    @test first(doc_results).entry.name == "run"
    @test first(doc_results).score > 0

    call_results = search_julia_project(root, "helper"; tags=["call"], limit=2)
    @test any(
        result -> result.entry.kind == "call" && result.entry.name == "helper",
        call_results,
    )
    @test all(result -> "call" in result.entry.tags, call_results)

    type_results = search_julia_project(root, "Config"; tags=["type"], limit=1)
    @test length(type_results) == 1
    @test only(type_results).entry.kind == "struct"
    field_results = search_julia_project(root, "mode"; tags=["field"], limit=1)
    @test length(field_results) == 1
    @test only(field_results).entry.kind == "field"
    @test only(field_results).entry.name == "Config.mode"
    binding_results = search_julia_project(root, "DEFAULT_LIMIT"; tags=["binding"], limit=1)
    @test length(binding_results) == 1
    @test only(binding_results).entry.kind == "const"
    @test isempty(search_julia_index(entries, "run"; limit=0))
end

@testset "path search index" begin
    root = mktempdir()
    source = joinpath(root, "standalone.jl")
    write(source, "module Standalone\nanswer() = 42\nend\n")

    entries = julia_lang_search_index([root])

    @test any(entry -> entry.kind == "module" && entry.name == "Standalone", entries)
    @test any(entry -> entry.kind == "function" && entry.name == "answer", entries)

    results = search_julia_lang([root], "answer"; tags=["method"], limit=1)

    @test length(results) == 1
    @test only(results).entry.name == "answer"
end
