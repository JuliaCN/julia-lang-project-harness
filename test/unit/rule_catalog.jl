@testset "rule catalog" begin
    descriptors = julia_rule_pack_descriptors()
    @test [descriptor.id for descriptor in descriptors] == [
        "julia.syntax",
        "julia.project_policy",
        "julia.modularity",
        "julia.agent_policy",
    ]

    syntax_rules = julia_syntax_rules()
    @test length(syntax_rules) == 1
    @test only(syntax_rules).rule_id == "JULIA-SYN-R001"
    @test only(syntax_rules).severity == JuliaLangProjectHarness.Error
    @test [rule.rule_id for rule in julia_project_policy_rules()] == [
        "JULIA-PROJ-R001",
        "JULIA-PROJ-R002",
        "JULIA-PROJ-R007",
    ]
    @test [rule.rule_id for rule in julia_modularity_rules()] == [
        "JULIA-MOD-R003",
        "JULIA-MOD-R004",
        "JULIA-MOD-R005",
        "JULIA-MOD-R006",
    ]
    @test isempty(julia_agent_policy_rules())
end

@testset "self apply public api" begin
    @test isdefined(JuliaLangProjectHarness, :assert_julia_project_harness_pkg_test_clean)
    @test isdefined(JuliaLangProjectHarness, :render_julia_project_harness_agent_snapshot)
end
