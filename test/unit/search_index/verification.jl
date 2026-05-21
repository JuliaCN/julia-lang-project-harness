@testset "project search index includes verification tasks" begin
    root = mktempdir()
    write(
        joinpath(root, "Project.toml"),
        """
        name = "VerifySearchExample"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"
        """,
    )
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "benchmark"))
    write(
        joinpath(root, "src", "VerifySearchExample.jl"),
        """
        module VerifySearchExample
        export run
        \"\"\"Run a value.\"\"\"
        run(value) = value
        end
        """,
    )
    write(
        joinpath(root, "benchmark", "Project.toml"),
        """
        [deps]
        BenchmarkTools = "6e4b80f9-dd2c-5a6d-8f14-7f3c1d9e8f4a"
        """,
    )
    write(joinpath(root, "benchmark", "runbenchmarks.jl"), "println(\"benchmark\")\n")

    entries = julia_project_search_index(root)
    benchmark_entry = only(
        entry for entry in entries if
        entry.kind == "verification" &&
        entry.name == "performance benchmark/runbenchmarks.jl"
    )

    @test "verification" in benchmark_entry.tags
    @test "performance" in benchmark_entry.tags
    @test "benchmark" in benchmark_entry.tags
    @test "runnable" in benchmark_entry.tags
    @test "receipt" in benchmark_entry.tags
    @test occursin("command=julia --project=benchmark -e", benchmark_entry.detail)
    @test occursin("benchmark_project=benchmark/Project.toml", benchmark_entry.detail)
    @test occursin("requires=benchmark_command,baseline,regression_threshold", benchmark_entry.detail)

    results = search_julia_project(
        root,
        "benchmark threshold";
        tags=["verification", "performance"],
        limit=2,
    )

    @test !isempty(results)
    @test first(results).entry.kind == benchmark_entry.kind
    @test first(results).entry.name == benchmark_entry.name
    @test first(results).entry.detail == benchmark_entry.detail
    @test all(result -> "verification" in result.entry.tags, results)
end

@testset "project search index tags examples verification tasks" begin
    root = mktempdir()
    write(
        joinpath(root, "Project.toml"),
        """
        name = "ExampleSearch"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"
        """,
    )
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "examples"))
    write(joinpath(root, "src", "ExampleSearch.jl"), "module ExampleSearch\nend\n")
    write(joinpath(root, "examples", "Project.toml"), "[deps]\n")
    write(joinpath(root, "examples", "runexamples.jl"), "println(\"example\")\n")

    results = search_julia_project(root, "runexamples"; tags=["verification", "example"], limit=1)

    @test length(results) == 1
    entry = only(results).entry
    @test entry.kind == "verification"
    @test entry.name == "example_run examples/runexamples.jl"
    @test "example" in entry.tags
    @test "runnable" in entry.tags
    @test occursin("example_project=examples/Project.toml", entry.detail)
    @test occursin("command=julia --project=examples -e", entry.detail)
end
