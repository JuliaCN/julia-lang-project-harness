@testset "rule catalog" begin
    descriptors = julia_rule_pack_descriptors()
    @test [descriptor.id for descriptor in descriptors] == [
        "julia.syntax",
        "julia.project_policy",
        "julia.modularity",
        "julia.agent_policy",
    ]
    @test [descriptor.default_mode for descriptor in descriptors] == [
        :blocking,
        :blocking,
        :blocking,
        :advisory,
    ]

    syntax_rules = julia_syntax_rules()
    @test length(syntax_rules) == 1
    @test only(syntax_rules).rule_id == "JULIA-SYN-R001"
    @test only(syntax_rules).severity == JuliaLangProjectHarness.Error
    @test [rule.rule_id for rule in julia_project_policy_rules()] == [
        "JULIA-PROJ-R001",
        "JULIA-PROJ-R002",
        "JULIA-PROJ-R003",
        "JULIA-PROJ-R004",
        "JULIA-PROJ-R005",
        "JULIA-PROJ-R006",
        "JULIA-PROJ-R007",
        "JULIA-PROJ-R008",
        "JULIA-PROJ-R009",
        "JULIA-PROJ-R010",
        "JULIA-PROJ-R011",
        "JULIA-PROJ-R012",
        "JULIA-PROJ-R013",
    ]
    @test [rule.rule_id for rule in julia_modularity_rules()] == [
        "JULIA-MOD-R001",
        "JULIA-MOD-R002",
        "JULIA-MOD-R003",
        "JULIA-MOD-R004",
        "JULIA-MOD-R005",
        "JULIA-MOD-R006",
        "JULIA-MOD-R007",
    ]
    @test [rule.rule_id for rule in julia_agent_policy_rules()] == [
        "AGENT-JL-R001",
        "AGENT-JL-R002",
        "AGENT-JL-R003",
        "AGENT-JL-R004",
        "AGENT-JL-R005",
        "AGENT-JL-R006",
        "AGENT-JL-R007",
        "AGENT-JL-R008",
        "AGENT-JL-R009",
        "AGENT-JL-R010",
        "AGENT-JL-R011",
        "AGENT-JL-R012",
        "AGENT-JL-R013",
        "AGENT-JL-R014",
    ]
end

@testset "self apply public api" begin
    @test isdefined(JuliaLangProjectHarness, :assert_julia_project_harness_pkg_test_clean)
    @test isdefined(JuliaLangProjectHarness, :assert_julia_project_harness_test_profile_clean)
    @test isdefined(JuliaLangProjectHarness, :build_julia_project_verification_profile)
    @test isdefined(JuliaLangProjectHarness, :render_julia_project_harness_agent_snapshot)
end
