@testset "agent snapshot" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "test"))
    write(
        joinpath(root, "src", "Example.jl"),
        "module Example\nexport run\nusing JSON3\ninclude(\"api.jl\")\nrun(value) = value\nend\n",
    )
    write(joinpath(root, "src", "api.jl"), "run() = 1\n")
    write(
        joinpath(root, "test", "runtests.jl"),
        "using Test\n@testset \"core\" begin\n@test run() == 1\nend\n",
    )

    rendered = render_julia_project_harness_agent_snapshot(root)

    @test occursin("Package: Example", rendered)
    @test occursin("Files: source=2 test=1", rendered)
    @test occursin("Entry: src/Example.jl", rendered)
    @test occursin("Modules:", rendered)
    @test occursin("src/Example.jl module=Example", rendered)
    @test occursin("Public:", rendered)
    @test occursin("export=run", rendered)
    @test occursin("Imports:", rendered)
    @test occursin("using=JSON3", rendered)
    @test occursin("Methods:", rendered)
    @test occursin("function=run/1", rendered)
    @test occursin("Tests:", rendered)
    @test occursin("test/runtests.jl testsets=\"core\" test=1", rendered)
    @test occursin("Includes:", rendered)
    @test occursin("src/Example.jl -> src/api.jl", rendered)
    @test !occursin("FindingGroups:", rendered)
end

@testset "agent snapshot finding groups" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "Example.jl"), "module Example\ninclude(path)\nend\n")

    rendered = render_julia_project_harness_agent_snapshot(root)

    @test occursin("DynamicIncludes:", rendered)
    @test occursin("include(path)", rendered)
    @test occursin("FindingGroups:", rendered)
    @test occursin("JULIA-MOD-R003 count=1", rendered)
end
