@testset "agent snapshot" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "Example.jl"), "module Example\ninclude(\"api.jl\")\nend\n")
    write(joinpath(root, "src", "api.jl"), "run() = 1\n")

    rendered = render_julia_project_harness_agent_snapshot(root)

    @test occursin("Package: Example", rendered)
    @test occursin("Files: source=2 test=0", rendered)
    @test occursin("Entry: src/Example.jl", rendered)
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
