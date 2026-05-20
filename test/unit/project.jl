function write_project(root::AbstractString, name::AbstractString)
    write(
        joinpath(root, "Project.toml"),
        """
        name = "$(name)"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"
        """,
    )
end

@testset "project runner accepts reachable literal include graph" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "Example.jl"), "module Example\ninclude(\"api.jl\")\nend\n")
    write(joinpath(root, "src", "api.jl"), "run() = 1\n")

    report = run_julia_project_harness(root)

    @test JuliaLangProjectHarness.is_clean(report)
    @test !isnothing(report.project_scope)
    @test report.project_scope.package_name == "Example"
    @test report.project_scope.package_entry_path == joinpath(root, "src", "Example.jl")
    @test render_julia_project_harness(report) == "[ok] julia\n"
end

@testset "project runner resolves root from Project.toml owner" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src", "internal"))
    write(joinpath(root, "src", "Example.jl"), "module Example\ninclude(\"internal/api.jl\")\nend\n")
    write(joinpath(root, "src", "internal", "api.jl"), "run() = 1\n")

    report = run_julia_project_harness(joinpath(root, "src", "internal"))

    @test JuliaLangProjectHarness.is_clean(report)
    @test report.project_scope.project_root == root
    @test report.project_scope.project_toml_path == joinpath(root, "Project.toml")
    @test report.project_scope.package_entry_path == joinpath(root, "src", "Example.jl")
end

@testset "project runner reports package policy facts" begin
    root = mktempdir()
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "Project.toml"), "version = \"0.1.0\"\n")
    write(joinpath(root, "src", "NoName.jl"), "value() = 1\n")

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R001", rendered)
    @test occursin("Project.toml lacks a package name", rendered)
end

@testset "project runner reports entry module mismatch" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "Example.jl"), "module Different\nend\n")

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R007", rendered)
    @test occursin("Package entry file lacks package module declaration", rendered)
end

@testset "project runner reports broad public method advice" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        export build
        build(a, b, c, d, e) = a
        end
        """,
    )

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test JuliaLangProjectHarness.is_clean(report)
    @test occursin("AGENT-JL-R002", rendered)
    @test occursin("Public method has a broad positional surface", rendered)
    @test length(JuliaLangProjectHarness.advisory_findings(report)) == 1
end

@testset "project runner reports include graph findings" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        include("missing.jl")
        include(path)
        end
        """,
    )
    write(joinpath(root, "src", "orphan.jl"), "value() = 1\n")

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-MOD-R003", rendered)
    @test occursin("Dynamic include hides source graph", rendered)
    @test occursin("JULIA-MOD-R004", rendered)
    @test occursin("Literal include target is missing", rendered)
    @test occursin("JULIA-MOD-R006", rendered)
    @test occursin("Source file is orphaned from package entry", rendered)
end

@testset "project runner reports literal include cycles" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "Example.jl"), "module Example\ninclude(\"a.jl\")\nend\n")
    write(joinpath(root, "src", "a.jl"), "include(\"b.jl\")\n")
    write(joinpath(root, "src", "b.jl"), "include(\"a.jl\")\n")

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-MOD-R005", rendered)
    @test occursin("Literal include graph contains a cycle", rendered)
    @test count(finding -> finding.rule_id == "JULIA-MOD-R005", report.findings) == 1
end
