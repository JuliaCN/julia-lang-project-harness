@testset "project search index tags package auxiliary syntax entries" begin
    root = mktempdir()
    write(
        joinpath(root, "Project.toml"),
        """
        name = "Example"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"
        """,
    )
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "docs"))
    mkpath(joinpath(root, "examples"))
    mkpath(joinpath(root, "benchmark"))
    write(joinpath(root, "src", "Example.jl"), "module Example\nexport run\nrun(x) = x\nend\n")
    write(
        joinpath(root, "docs", "Project.toml"),
        """
        [deps]
        Documenter = "e30172f5-a6a5-5a46-863b-614d45cd2de4"
        Example = "11111111-1111-1111-1111-111111111111"
        """,
    )
    write(joinpath(root, "docs", "make.jl"), "using Documenter\nmakedocs()\n")
    write(
        joinpath(root, "examples", "Project.toml"),
        """
        [deps]
        Example = "11111111-1111-1111-1111-111111111111"
        """,
    )
    write(
        joinpath(root, "examples", "runexamples.jl"),
        "using Example\nscripted_example() = run(1)\nscripted_example()\n",
    )
    write(
        joinpath(root, "benchmark", "runbenchmarks.jl"),
        "using Example\nfunction run_benchmark()\n    run(1)\nend\n",
    )

    entries = julia_project_search_index(root)
    docs_results = search_julia_project(root, "makedocs"; tags=["docs", "call"], limit=1)
    example_results = search_julia_project(
        root,
        "scripted_example";
        tags=["example", "method"],
        limit=1,
    )
    benchmark_results = search_julia_project(
        root,
        "run_benchmark";
        tags=["benchmark", "method"],
        limit=1,
    )

    @test any(
        entry -> entry.kind == "owner" &&
                 entry.name == "docs/make.jl" &&
                 "docs" in entry.tags,
        entries,
    )
    @test only(docs_results).entry.name == "makedocs"
    @test "docs" in only(docs_results).entry.tags
    @test only(example_results).entry.name == "scripted_example"
    @test "example" in only(example_results).entry.tags
    @test only(benchmark_results).entry.name == "run_benchmark"
    @test "benchmark" in only(benchmark_results).entry.tags
end
