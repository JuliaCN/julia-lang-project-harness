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
        export run, Config
        using Dates
        include("api.jl")
        struct Config
            value::Int
        end
        end
        """,
    )
    write(joinpath(root, "src", "api.jl"), "run(value; verbose=false) = value\n")
    write(
        joinpath(root, "test", "runtests.jl"),
        "using Test\n@testset \"search\" begin\n@test run(1) == 1\nend\n",
    )

    entries = julia_project_search_index(root)

    @test any(entry -> entry.kind == "module" && entry.name == "Example", entries)
    @test any(entry -> entry.kind == "export" && entry.name == "run", entries)
    @test any(entry -> entry.kind == "using" && entry.name == "Dates", entries)
    @test any(entry -> entry.kind == "struct" && entry.name == "Config", entries)
    @test any(
        entry -> entry.kind == "function" &&
                 entry.name == "run" &&
                 occursin("verbose", entry.search_text) &&
                 "method" in entry.tags,
        entries,
    )
    @test any(entry -> entry.kind == "include" && entry.name == "api.jl", entries)
    @test any(entry -> entry.kind == "testset" && entry.name == "search", entries)
    @test all(entry -> !isnothing(entry.location.path), entries)
end

@testset "path search index" begin
    root = mktempdir()
    source = joinpath(root, "standalone.jl")
    write(source, "module Standalone\nanswer() = 42\nend\n")

    entries = julia_lang_search_index([root])

    @test any(entry -> entry.kind == "module" && entry.name == "Standalone", entries)
    @test any(entry -> entry.kind == "function" && entry.name == "answer", entries)
end
