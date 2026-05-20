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
    @test isempty(julia_project_policy_rules())
    @test isempty(julia_modularity_rules())
    @test isempty(julia_agent_policy_rules())
end
