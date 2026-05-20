function write_config_project(root::AbstractString)
    write(
        joinpath(root, "Project.toml"),
        """
        name = "ConfigExample"
        uuid = "11111111-1111-1111-1111-111111111111"
        version = "0.1.0"
        """,
    )
    mkpath(joinpath(root, "src"))
    write(joinpath(root, "src", "ConfigExample.jl"), "module ConfigExample\nend\n")
end

function config_with_agent_advice_allow_explanation(explanation::Union{Nothing,String})
    config = default_julia_harness_config()
    JuliaHarnessConfig(
        copy(config.ignored_dir_names),
        copy(config.blocking_severities),
        copy(config.disabled_rules),
        copy(config.disabled_rule_explanations),
        copy(config.rule_severity_overrides),
        copy(config.rule_severity_override_explanations),
        copy(config.blocking_severity_explanations),
        config.include_tests,
        copy(config.source_dir_names),
        copy(config.test_dir_names),
        copy(config.source_path_explanations),
        copy(config.test_path_explanations),
        copy(config.source_path_exclusion_explanations),
        copy(config.test_path_exclusion_explanations),
        explanation,
    )
end

@testset "config escape requires disabled rule explanation" begin
    root = mktempdir()
    write_config_project(root)
    config = default_julia_harness_config()
    push!(config.disabled_rules, "JULIA-PROJ-R014")

    report = run_julia_project_harness(root; config)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R014", rendered)
    @test occursin("disabled without a non-empty explanation", rendered)

    config.disabled_rule_explanations["JULIA-PROJ-R014"] = "local policy migration under review"
    clean_report = run_julia_project_harness(root; config)

    @test JuliaLangProjectHarness.is_clean(clean_report)
end

@testset "config escape requires severity override explanation" begin
    root = mktempdir()
    write_config_project(root)
    config = default_julia_harness_config()
    config.rule_severity_overrides["JULIA-PROJ-R002"] = JuliaLangProjectHarness.Info

    report = run_julia_project_harness(root; config)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R014", rendered)
    @test occursin("severity is overridden", rendered)

    config.rule_severity_override_explanations["JULIA-PROJ-R002"] =
        "temporary package layout migration"
    clean_report = run_julia_project_harness(root; config)

    @test JuliaLangProjectHarness.is_clean(clean_report)
end

@testset "config escape requires blocking severity explanation" begin
    root = mktempdir()
    write_config_project(root)
    config = default_julia_harness_config()
    delete!(config.blocking_severities, JuliaLangProjectHarness.Warning)

    report = run_julia_project_harness(root; config)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R014", rendered)
    @test occursin("Blocking severity `warning` is removed", rendered)

    config.blocking_severity_explanations["warning"] = "collect warnings during staged rollout"
    clean_report = run_julia_project_harness(root; config)

    @test JuliaLangProjectHarness.is_clean(clean_report)
end

@testset "config escape rejects blank advisory allow explanation" begin
    root = mktempdir()
    write_config_project(root)
    config = config_with_agent_advice_allow_explanation("   ")

    report = run_julia_project_harness(root; config)
    rendered = render_julia_project_harness(report)

    @test !JuliaLangProjectHarness.is_clean(report)
    @test occursin("JULIA-PROJ-R014", rendered)
    @test occursin("empty after trimming whitespace", rendered)
end
