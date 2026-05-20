function write_project(root::AbstractString, name::AbstractString)
    write(
        joinpath(root, "Project.toml"),
        """
        name = "$(name)"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"

        [extras]
        Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

        [targets]
        test = ["Test"]
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

@testset "project runner honors Project.toml entryfile" begin
    root = mktempdir()
    write(
        joinpath(root, "Project.toml"),
        """
        name = "Example"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"
        entryfile = "src/Entry.jl"
        """,
    )
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "Entry.jl"), "module Example\nend\n")

    report = run_julia_project_harness(root)
    snapshot = render_julia_project_harness_agent_snapshot(root)

    @test JuliaLangProjectHarness.is_clean(report)
    @test report.project_scope.project_entryfile == "src/Entry.jl"
    @test report.project_scope.package_entry_path == joinpath(root, "src", "Entry.jl")
    @test occursin("Entry: src/Entry.jl", snapshot)
    @test occursin("entryfile=src/Entry.jl", snapshot)
end

@testset "project runner captures Project.toml dependency facts" begin
    root = mktempdir()
    write(
        joinpath(root, "Project.toml"),
        """
        name = "Example"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"

        [deps]
        JSON3 = "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
        JuliaSyntax = "70703baa-626e-46a2-a12c-08ffd08c73b4"

        [weakdeps]
        WeakThing = "22222222-2222-2222-2222-222222222222"

        [extras]
        Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

        [targets]
        test = ["Test"]

        [compat]
        JSON3 = "1"

        [sources]
        JuliaSyntax = {url = "https://github.com/JuliaLang/JuliaSyntax.jl", rev = "main"}
        """,
    )
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "Example.jl"), "module Example\nend\n")

    report = run_julia_project_harness(root)
    scope = report.project_scope

    @test JuliaLangProjectHarness.is_clean(report)
    @test scope.package_uuid == "11111111-1111-1111-1111-111111111111"
    @test scope.direct_dependencies["JSON3"] == "0f8b85d8-7281-11e9-16c2-39a750bddbf1"
    @test scope.direct_dependencies["JuliaSyntax"] == "70703baa-626e-46a2-a12c-08ffd08c73b4"
    @test scope.weak_dependencies["WeakThing"] == "22222222-2222-2222-2222-222222222222"
    @test scope.extra_dependencies["Test"] == "8dfed614-e22c-5e08-85e1-65c5234f0b40"
    @test scope.targets["test"] == ["Test"]
    @test scope.compat["JSON3"] == "1"
    @test scope.sources["JuliaSyntax"]["rev"] == "main"
end

@testset "project runner reports undeclared source imports" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    write(
        joinpath(root, "src", "Example.jl"),
        """
        module Example
        using JSON3
        using .Local
        import Base: show
        end
        """,
    )

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R008", rendered)
    @test occursin("Imported package is missing from Project.toml", rendered)
    @test count(finding -> finding.rule_id == "JULIA-PROJ-R008", report.findings) == 1
end

@testset "project runner reports missing Pkg.test entrypoint" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "test"))
    write(joinpath(root, "src", "Example.jl"), "module Example\nend\n")
    write(joinpath(root, "test", "helpers.jl"), "value = 1\n")

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R003", rendered)
    @test occursin("Pkg.test entrypoint is missing", rendered)
    @test occursin("test/runtests.jl", rendered)
    @test count(finding -> finding.rule_id == "JULIA-PROJ-R003", report.findings) == 1
end

@testset "project runner reports large inline runtests entrypoint" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "test"))
    write(joinpath(root, "src", "Example.jl"), "module Example\nend\n")
    tests = join(fill("@test true", 81), "\n")
    write(joinpath(root, "test", "runtests.jl"), "using Test\n$(tests)\n")

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R004", rendered)
    @test occursin("Pkg.test entrypoint is no longer a thin aggregate", rendered)
    @test count(finding -> finding.rule_id == "JULIA-PROJ-R004", report.findings) == 1
end

@testset "project runner reports custom source scope without explanation" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "lib"))
    write(joinpath(root, "src", "Example.jl"), "module Example\nend\n")
    config = default_julia_harness_config()
    push!(config.source_dir_names, "lib")

    report = run_julia_project_harness(root; config)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R005", rendered)
    @test occursin("Custom source or test scope lacks explanation", rendered)
    @test count(finding -> finding.rule_id == "JULIA-PROJ-R005", report.findings) == 1
end

@testset "project runner reports conventional source scope exclusion" begin
    root = mktempdir()
    write(
        joinpath(root, "Project.toml"),
        """
        name = "Example"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"
        entryfile = "lib/Example.jl"
        """,
    )
    mkpath(joinpath(root, "src"))
    mkpath(joinpath(root, "lib"))
    write(joinpath(root, "lib", "Example.jl"), "module Example\nend\n")
    config = default_julia_harness_config()
    empty!(config.source_dir_names)
    push!(config.source_dir_names, "lib")
    config.source_path_explanations["lib"] = "project uses a package-local lib source root"

    report = run_julia_project_harness(root; config)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R006", rendered)
    @test occursin("Conventional source or test scope was excluded", rendered)
    @test count(finding -> finding.rule_id == "JULIA-PROJ-R006", report.findings) == 1
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

@testset "project runner reports generic source owner buckets" begin
    root = mktempdir()
    write_project(root, "Example")
    mkpath(joinpath(root, "src", "utils"))
    write(joinpath(root, "src", "Example.jl"), "module Example\ninclude(\"utils/helpers.jl\")\nend\n")
    write(joinpath(root, "src", "utils", "helpers.jl"), "value() = 1\n")

    report = run_julia_project_harness(root)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-MOD-R007", rendered)
    @test occursin("Source path uses a generic owner bucket", rendered)
    @test count(finding -> finding.rule_id == "JULIA-MOD-R007", report.findings) == 1
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
