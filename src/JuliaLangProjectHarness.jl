module JuliaLangProjectHarness

include("model.jl")
include("parser.jl")
include("rules.jl")
include("render.jl")
include("runner.jl")
include("search_index.jl")
include("agent_snapshot.jl")

export JuliaDiagnosticSeverity,
    JuliaHarnessConfig,
    JuliaHarnessFinding,
    JuliaHarnessReport,
    JuliaHarnessRule,
    JuliaFileReport,
    JuliaSearchIndexEntry,
    JuliaSearchResult,
    RulePackDescriptor,
    SourceLocation,
    assert_julia_lang_harness_clean,
    assert_julia_project_harness_clean,
    assert_julia_project_harness_pkg_test_clean,
    default_julia_harness_config,
    julia_agent_policy_rules,
    julia_modularity_rules,
    julia_project_policy_rules,
    julia_project_search_index,
    julia_rule_pack_descriptors,
    julia_syntax_rules,
    julia_lang_search_index,
    render_julia_project_harness,
    render_julia_project_harness_advice,
    render_julia_project_harness_agent_snapshot,
    render_julia_project_harness_json,
    run_julia_lang_harness,
    run_julia_project_harness,
    search_julia_index,
    search_julia_lang,
    search_julia_project

end
