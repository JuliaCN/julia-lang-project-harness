@testset "project search index" begin
    root = mktempdir()
    write(
        joinpath(root, "Project.toml"),
        """
        name = "Example"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"

        [weakdeps]
        Moshi = "2e0e35c7-a2e4-4343-998d-7ef72827ed2d"

        [compat]
        Moshi = "0.3"

        [extensions]
        ExampleMoshiExt = "Moshi"

        [extras]
        Moshi = "2e0e35c7-a2e4-4343-998d-7ef72827ed2d"
        Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

        [targets]
        test = ["Moshi", "Test"]
        """,
    )
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "ext"))
    mkpath(joinpath(root, "test"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        export run, Config, DEFAULT_LIMIT
        using Dates
        using Moshi.Data: @data
        include("api.jl")
        @data Mode begin
            Fast
            Safe
        end
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
            if verbose
                for item in value:value
                    @alpha helper(item)
                end
            end
            helper(value)
        end
        helper(value) = string(value)
        function scan(groups)
            total = 0
            for group in groups
                for item in group
                    if item > 0
                        total += item
                    end
                end
            end
            total
        end
        """,
    )
    write(
        joinpath(root, "ext", "ExampleMoshiExt.jl"),
        """
        module ExampleMoshiExt
        using Example
        using Moshi.Data: @data

        @data ExtensionMode begin
            Active
        end
        end
        """,
    )
    write(
        joinpath(root, "test", "runtests.jl"),
        "using Test\n@testset \"search\" begin\n@test run(1) == 1\nend\n",
    )

    entries = julia_project_search_index(root)

    @test any(
        entry -> entry.kind == "owner" &&
                 entry.name == "src/Example.jl" &&
                 "owner" in entry.tags &&
                 "reasoning-tree" in entry.tags &&
                 "entry" in entry.tags &&
                 "public" in entry.tags &&
                 occursin("role=entry", entry.detail) &&
                 occursin("modules=Example", entry.detail) &&
                 occursin("public=Config,DEFAULT_LIMIT,run", entry.detail) &&
                 occursin("includes=src/api.jl", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "owner" &&
                 entry.name == "src/api.jl" &&
                 "source" in entry.tags &&
                 "method" in entry.tags &&
                 occursin("methods=helper,run", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "owner" &&
                 entry.name == "test/runtests.jl" &&
                 "test" in entry.tags &&
                 occursin("tests=\"search\",direct=1", entry.detail),
        entries,
    )
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
        entry -> entry.kind == "moshi" &&
                 entry.name == "Mode" &&
                 "moshi" in entry.tags &&
                 "data" in entry.tags &&
                 occursin("Moshi @data target=Mode", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "moshi_extension" &&
                 occursin("ExampleMoshiExt", entry.name) &&
                 "agent-capability" in entry.tags &&
                 "test_target" in entry.tags &&
                 occursin("activation=test_target", entry.detail) &&
                 occursin("capabilities=syntax,domain-model,search", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "function" &&
                 entry.name == "run" &&
                 occursin("verbose", entry.search_text) &&
                 occursin("typed=value::T", entry.detail) &&
                 occursin("returns=String", entry.detail) &&
                 occursin("where=T<:Integer", entry.detail) &&
                 occursin("flow=2:if,for", entry.detail) &&
                 occursin("branches=1", entry.detail) &&
                 occursin("loops=1", entry.detail) &&
                 occursin("loop_depth=1", entry.detail) &&
                 occursin("macros=1:alpha", entry.detail) &&
                 "method" in entry.tags,
        entries,
    )
    @test any(
        entry -> entry.kind == "function" &&
                 entry.name == "run" &&
                 "control-flow" in entry.tags &&
                 "if" in entry.tags &&
                 "for" in entry.tags &&
                 "branch" in entry.tags &&
                 "loop" in entry.tags &&
                 "macro" in entry.tags,
        entries,
    )
    @test any(
        entry -> entry.kind == "function" &&
                 entry.name == "scan" &&
                 "control-flow" in entry.tags &&
                 "loop" in entry.tags &&
                 "nested-loop" in entry.tags,
        entries,
    )
    @test any(
        entry -> entry.kind == "argument" &&
                 entry.name == "run.value" &&
                 "argument" in entry.tags &&
                 "positional" in entry.tags &&
                 occursin("run.value positional::T", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "argument" &&
                 entry.name == "run.verbose" &&
                 "argument" in entry.tags &&
                 "keyword" in entry.tags &&
                 "bool" in entry.tags &&
                 occursin("run.verbose keyword default bool", entry.detail),
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
    argument_results = search_julia_project(root, "verbose"; tags=["argument"], limit=1)
    @test length(argument_results) == 1
    @test only(argument_results).entry.kind == "argument"
    @test only(argument_results).entry.name == "run.verbose"
    binding_results = search_julia_project(root, "DEFAULT_LIMIT"; tags=["binding"], limit=1)
    @test length(binding_results) == 1
    @test only(binding_results).entry.kind == "const"
    moshi_results = search_julia_project(root, "Mode"; tags=["moshi"], limit=1)
    @test length(moshi_results) == 1
    @test only(moshi_results).entry.kind == "moshi"
    @test only(moshi_results).entry.name == "Mode"
    shape_results = search_julia_project(root, "scan"; tags=["nested-loop"], limit=1)
    @test length(shape_results) == 1
    @test only(shape_results).entry.kind == "function"
    @test only(shape_results).entry.name == "scan"
    owner_results = search_julia_project(root, "helper run"; tags=["owner"], limit=1)
    @test length(owner_results) == 1
    @test only(owner_results).entry.kind == "owner"
    @test only(owner_results).entry.name == "src/api.jl"
    @test isempty(search_julia_index(entries, "run"; limit=0))
end

@testset "project search index includes workspace owner entries" begin
    root = mktempdir()
    write(
        joinpath(root, "Project.toml"),
        """
        name = "Root"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"

        [workspace]
        projects = ["packages/Member"]
        """,
    )
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "packages", "Member", "src"))
    write(joinpath(root, "src", "Root.jl"), "module Root\nend\n")
    write(
        joinpath(root, "packages", "Member", "Project.toml"),
        """
        name = "Member"
        uuid = "22222222-2222-2222-2222-222222222222"
        version = "0.1.0"
        """,
    )
    write(joinpath(root, "packages", "Member", "src", "Member.jl"), "module Member\nend\n")

    entries = julia_project_search_index(root)

    @test any(
        entry -> entry.kind == "owner" &&
                 entry.name == "src/Root.jl" &&
                 "entry" in entry.tags &&
                 occursin("modules=Root", entry.detail),
        entries,
    )
    @test any(
        entry -> entry.kind == "owner" &&
                 entry.name == "src/Member.jl" &&
                 "entry" in entry.tags &&
                 occursin("modules=Member", entry.detail),
        entries,
    )
end

@testset "path search index" begin
    root = mktempdir()
    source = joinpath(root, "standalone.jl")
    write(source, "module Standalone\nanswer() = 42\nend\n")

    entries = julia_lang_search_index([root])

    @test any(entry -> entry.kind == "module" && entry.name == "Standalone", entries)
    @test any(entry -> entry.kind == "function" && entry.name == "answer", entries)
    @test !any(entry -> entry.kind == "owner", entries)

    results = search_julia_lang([root], "answer"; tags=["method"], limit=1)

    @test length(results) == 1
    @test only(results).entry.name == "answer"
end

@testset "search index rejects invalid inputs" begin
    missing = joinpath(mktempdir(), "missing")

    @test_throws ErrorException julia_lang_search_index([missing])
    @test_throws ErrorException julia_project_search_index(missing)
    @test_throws ErrorException search_julia_index(JuliaSearchIndexEntry[], "run"; limit=-1)
end
