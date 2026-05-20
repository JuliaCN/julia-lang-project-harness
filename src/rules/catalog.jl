const JULIA_SYNTAX_PACK_ID = "julia.syntax"
const JULIA_PROJECT_POLICY_PACK_ID = "julia.project_policy"
const JULIA_MODULARITY_PACK_ID = "julia.modularity"
const JULIA_AGENT_POLICY_PACK_ID = "julia.agent_policy"
const JULIA_SYN_R001 = "JULIA-SYN-R001"
const JULIA_PROJ_R001 = "JULIA-PROJ-R001"
const JULIA_PROJ_R002 = "JULIA-PROJ-R002"
const JULIA_PROJ_R003 = "JULIA-PROJ-R003"
const JULIA_PROJ_R004 = "JULIA-PROJ-R004"
const JULIA_PROJ_R005 = "JULIA-PROJ-R005"
const JULIA_PROJ_R006 = "JULIA-PROJ-R006"
const JULIA_PROJ_R007 = "JULIA-PROJ-R007"
const JULIA_PROJ_R008 = "JULIA-PROJ-R008"
const JULIA_MOD_R001 = "JULIA-MOD-R001"
const JULIA_MOD_R002 = "JULIA-MOD-R002"
const JULIA_MOD_R003 = "JULIA-MOD-R003"
const JULIA_MOD_R004 = "JULIA-MOD-R004"
const JULIA_MOD_R005 = "JULIA-MOD-R005"
const JULIA_MOD_R006 = "JULIA-MOD-R006"
const JULIA_MOD_R007 = "JULIA-MOD-R007"
const AGENT_JL_R002 = "AGENT-JL-R002"
const AGENT_JL_R003 = "AGENT-JL-R003"

const GENERIC_SOURCE_OWNER_SEGMENTS = Set(["common", "helper", "helpers", "misc", "util", "utils"])
const MAX_ENTRY_FACADE_NONBLANK_LINES = 120
const MAX_SOURCE_FILE_NONBLANK_LINES = 400
const MAX_THIN_RUNTESTS_NONBLANK_LINES = 80

function julia_rule_pack_descriptors()
    [
        RulePackDescriptor(JULIA_SYNTAX_PACK_ID, "1", ["julia", "syntax"], "blocking"),
        RulePackDescriptor(
            JULIA_PROJECT_POLICY_PACK_ID,
            "1",
            ["julia", "project-policy", "tests"],
            "blocking",
        ),
        RulePackDescriptor(JULIA_MODULARITY_PACK_ID, "1", ["julia", "modularity"], "blocking"),
        RulePackDescriptor(JULIA_AGENT_POLICY_PACK_ID, "1", ["julia", "agent-policy"], "advisory"),
    ]
end

function labels(label::AbstractString)
    Dict("domain" => String(label))
end

function julia_syntax_rules()
    [
        JuliaHarnessRule(
            JULIA_SYN_R001,
            JULIA_SYNTAX_PACK_ID,
            Error,
            "Julia source does not parse",
            "Julia source files must parse through `JuliaSyntax.jl` before project policy runs.",
            labels("syntax"),
        ),
    ]
end

julia_project_policy_rules() = [
    JuliaHarnessRule(
        JULIA_PROJ_R001,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Project.toml lacks a package name",
        "Package project runners must parse `Project.toml` and find a concrete package name before package policy runs.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R002,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Package entry module is missing",
        "Julia packages should expose a parser-stable entry file at `src/<PackageName>.jl`, unless project config records a reason.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R003,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Pkg.test entrypoint is missing",
        "Julia package test scopes should mount the `Pkg.test` entrypoint at `test/runtests.jl`.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R004,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Pkg.test entrypoint is no longer a thin aggregate",
        "`test/runtests.jl` should stay a compact `Pkg.test` aggregate and move larger test bodies into included test files.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R005,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Custom source or test scope lacks explanation",
        "Custom Julia source or test scope paths must carry a non-empty project-local explanation.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R006,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Conventional source or test scope was excluded",
        "Excluding conventional Julia `src` or `test` scopes must carry a non-empty project-local explanation.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R007,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Package entry file lacks package module declaration",
        "The package entry file should declare a top-level module matching the `Project.toml` package name.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R008,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Imported package is missing from Project.toml",
        "External Julia package imports should be declared in `Project.toml` as deps, weakdeps, or test extras according to their source scope.",
        labels("project-policy"),
    ),
]

julia_modularity_rules() = [
    JuliaHarnessRule(
        JULIA_MOD_R001,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Package entry file is too large for a facade",
        "Julia package entry files should stay compact facades that include named owner files and expose the public module surface.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R002,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Source file exceeds the owner budget",
        "Julia source files should stay within a bounded responsibility budget so agents can repair one owner at a time.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R003,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Dynamic include hides source graph",
        "Keep Julia package source graphs parser-stable with literal `include(...)` targets, or record a project-local exception.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R004,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Literal include target is missing",
        "Every literal Julia `include(...)` target must resolve to an existing source file.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R005,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Literal include graph contains a cycle",
        "Julia package source graphs should stay acyclic so agents can follow one repair ownership path.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R006,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Source file is orphaned from package entry",
        "Julia source files under `src/` should be reachable from the package entry include graph, unless project config records a reason.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R007,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Source path uses a generic owner bucket",
        "Julia source path segments should name domain ownership instead of generic buckets such as `utils`, `common`, `helpers`, or `misc`.",
        labels("modularity"),
    ),
]

julia_agent_policy_rules() = [
    JuliaHarnessRule(
        AGENT_JL_R002,
        JULIA_AGENT_POLICY_PACK_ID,
        Info,
        "Public method has a broad positional surface",
        "Prefer keyword options or a named config object when exported Julia methods need many arguments.",
        labels("agent-policy"),
    ),
    JuliaHarnessRule(
        AGENT_JL_R003,
        JULIA_AGENT_POLICY_PACK_ID,
        Info,
        "Public method exposes positional Bool flags",
        "Prefer keyword Bool options or a named config object when exported Julia methods need multiple flags.",
        labels("agent-policy"),
    ),
]

function syntax_rule_by_id()
    Dict(rule.rule_id => rule for rule in julia_syntax_rules())
end

function rules_by_id()
    Dict(
        rule.rule_id => rule for rule in vcat(
            julia_syntax_rules(),
            julia_project_policy_rules(),
            julia_modularity_rules(),
            julia_agent_policy_rules(),
        )
    )
end

function finding_from_rule(rule::JuliaHarnessRule; summary, location, source_line=nothing, label)
    JuliaHarnessFinding(
        rule.rule_id,
        rule.pack_id,
        rule.severity,
        rule.title,
        summary,
        location,
        rule.requirement,
        source_line,
        label,
        copy(rule.labels),
    )
end
