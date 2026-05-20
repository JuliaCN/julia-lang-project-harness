@testset "agent snapshot" begin
    root = mktempdir()
    write_project(root, "Example")
    open(joinpath(root, "Project.toml"), "a") do io
        write(
            io,
            """

        [deps]
        JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"

        [compat]
        JSON3 = "1"
        """,
        )
    end
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "test"))
    write(
        joinpath(root, "src", "Example.jl"),
        "module Example\nexport run, Config, DEFAULT_LIMIT\nusing JSON3\ninclude(\"api.jl\")\n\"\"\"Runtime configuration.\"\"\"\nstruct Config\nvalue::Int\nmode::Symbol = :fast\nend\n\"\"\"Default limit.\"\"\"\nconst DEFAULT_LIMIT::Int = 8\n\"\"\"Run a value.\"\"\"\nfunction run(value::T)::T where {T}\n@alpha value\nend\nend\n",
    )
    write(joinpath(root, "src", "api.jl"), "internal_api() = 1\n")
    write(
        joinpath(root, "test", "runtests.jl"),
        "using Test\n@testset \"core\" begin\n@test run(1) == 1\nend\n",
    )

    rendered = render_julia_project_harness_agent_snapshot(root)

    @test occursin("Package: Example", rendered)
    @test occursin("Files: source=2 test=1", rendered)
    @test occursin("Entry: src/Example.jl", rendered)
    @test occursin("Project:", rendered)
    @test occursin("extras=Test", rendered)
    @test occursin("targets=test=Test", rendered)
    @test occursin("compat=JSON3=1", rendered)
    @test occursin("Modules:", rendered)
    @test occursin("src/Example.jl module=Example", rendered)
    @test occursin("Public:", rendered)
    @test occursin("export=run", rendered)
    @test occursin("Imports:", rendered)
    @test occursin("using=JSON3", rendered)
    @test occursin("Types:", rendered)
    @test occursin("struct=Config fields=2 typed=2 defaults=1", rendered)
    @test occursin("Bindings:", rendered)
    @test occursin("const=DEFAULT_LIMIT::Int", rendered)
    @test occursin("Methods:", rendered)
    @test occursin("function=run/1", rendered)
    @test occursin("typed=1", rendered)
    @test occursin("returns=T", rendered)
    @test occursin("where=1", rendered)
    @test occursin("macros=1", rendered)
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
