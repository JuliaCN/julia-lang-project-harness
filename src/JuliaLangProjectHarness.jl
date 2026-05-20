module JuliaLangProjectHarness

include("model.jl")
include("parser.jl")
include("rules.jl")
include("render.jl")
include("runner.jl")

export JuliaDiagnosticSeverity,
    JuliaHarnessConfig,
    JuliaHarnessFinding,
    JuliaHarnessReport,
    JuliaHarnessRule,
    JuliaFileReport,
    RulePackDescriptor,
    SourceLocation,
    assert_julia_lang_harness_clean,
    assert_julia_project_harness_clean,
    default_julia_harness_config,
    julia_agent_policy_rules,
    julia_modularity_rules,
    julia_project_policy_rules,
    julia_rule_pack_descriptors,
    julia_syntax_rules,
    render_julia_project_harness,
    render_julia_project_harness_advice,
    render_julia_project_harness_json,
    run_julia_lang_harness,
    run_julia_project_harness

end
