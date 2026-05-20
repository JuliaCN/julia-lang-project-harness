const JULIA_SYNTAX_PACK_ID = "julia.syntax"
const JULIA_PROJECT_POLICY_PACK_ID = "julia.project_policy"
const JULIA_MODULARITY_PACK_ID = "julia.modularity"
const JULIA_AGENT_POLICY_PACK_ID = "julia.agent_policy"
const JULIA_SYN_R001 = "JULIA-SYN-R001"
const JULIA_PROJ_R001 = "JULIA-PROJ-R001"
const JULIA_PROJ_R002 = "JULIA-PROJ-R002"
const JULIA_MOD_R003 = "JULIA-MOD-R003"
const JULIA_MOD_R004 = "JULIA-MOD-R004"
const JULIA_MOD_R006 = "JULIA-MOD-R006"

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
]

julia_modularity_rules() = [
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
        JULIA_MOD_R006,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Source file is orphaned from package entry",
        "Julia source files under `src/` should be reachable from the package entry include graph, unless project config records a reason.",
        labels("modularity"),
    ),
]

julia_agent_policy_rules() = JuliaHarnessRule[]

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

function evaluate_syntax_rules(parsed_files::Vector{ParsedJuliaFile})
    rules = syntax_rule_by_id()
    syntax_rule = rules[JULIA_SYN_R001]
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        parsed.report.is_valid && continue
        push!(
            findings,
            finding_from_rule(
                syntax_rule;
                summary=isnothing(parsed.report.parse_error) ? "JuliaSyntax rejected the file." :
                        parsed.report.parse_error,
                location=SourceLocation(parsed.report.path, 1, 0),
                source_line=source_line(parsed.source, 1),
                label="repair Julia syntax until JuliaSyntax can parse this file",
            ),
        )
    end
    findings
end

function apply_config_to_findings(findings::Vector{JuliaHarnessFinding}, config::JuliaHarnessConfig)
    selected = JuliaHarnessFinding[]
    for finding in findings
        finding.rule_id in config.disabled_rules && continue
        severity = get(config.rule_severity_overrides, finding.rule_id, finding.severity)
        if severity == finding.severity
            push!(selected, finding)
        else
            push!(
                selected,
                JuliaHarnessFinding(
                    finding.rule_id,
                    finding.pack_id,
                    severity,
                    finding.title,
                    finding.summary,
                    finding.location,
                    finding.requirement,
                    finding.source_line,
                    finding.label,
                    copy(finding.labels),
                ),
            )
        end
    end
    selected
end

function evaluate_project_policy_rules(
    scope::Union{Nothing,JuliaProjectHarnessScope},
    parsed_files::Vector{ParsedJuliaFile},
)
    isnothing(scope) && return JuliaHarnessFinding[]
    rules = rules_by_id()
    findings = JuliaHarnessFinding[]
    if isnothing(scope.package_name)
        push!(
            findings,
            finding_from_rule(
                rules[JULIA_PROJ_R001];
                summary="Project.toml was not found or did not define a `name` field.",
                location=SourceLocation(scope.project_toml_path, 1, 0),
                label="add a package name to Project.toml before running package policy",
            ),
        )
    elseif isnothing(scope.package_entry_path)
        push!(
            findings,
            finding_from_rule(
                rules[JULIA_PROJ_R002];
                summary="Package `$(scope.package_name)` does not expose `src/$(scope.package_name).jl`.",
                location=SourceLocation(scope.project_toml_path, 1, 0),
                label="add the package entry module or configure an explicit source-scope exception",
            ),
        )
    end
    findings
end

function evaluate_modularity_rules(
    scope::Union{Nothing,JuliaProjectHarnessScope},
    parsed_files::Vector{ParsedJuliaFile},
)
    isnothing(scope) && return JuliaHarnessFinding[]
    rules = rules_by_id()
    findings = JuliaHarnessFinding[]
    parsed_by_path = Dict(parsed.report.path => parsed for parsed in parsed_files)
    for parsed in parsed_files
        parsed.report.is_valid || continue
        for include in parsed.syntax_facts.includes
            if !include.is_literal
                push!(
                    findings,
                    finding_from_rule(
                        rules[JULIA_MOD_R003];
                        summary="Parser facts found `$(include.expression)`, whose target is not statically known.",
                        location=SourceLocation(parsed.report.path, include.line, include.column),
                        source_line=source_line(parsed.source, include.line),
                        label="replace dynamic include with a literal include or document the exception",
                    ),
                )
            elseif !isfile(include.resolved_target)
                push!(
                    findings,
                    finding_from_rule(
                        rules[JULIA_MOD_R004];
                        summary="`$(include.expression)` resolves to missing file `$(include.resolved_target)`.",
                        location=SourceLocation(parsed.report.path, include.line, include.column),
                        source_line=source_line(parsed.source, include.line),
                        label="create the included file or update the literal include path",
                    ),
                )
            end
        end
    end
    append!(findings, orphan_source_findings(scope, parsed_files, parsed_by_path, rules))
    findings
end

function orphan_source_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    parsed_by_path::Dict{String,ParsedJuliaFile},
    rules::Dict{String,JuliaHarnessRule},
)
    isnothing(scope.package_entry_path) && return JuliaHarnessFinding[]
    source_files = Set(
        parsed.report.path for parsed in parsed_files if any(
            source_path -> is_path_under(parsed.report.path, source_path),
            scope.source_paths,
        )
    )
    reachable = reachable_source_files(scope.package_entry_path, parsed_by_path)
    orphaned = sort!(collect(setdiff(source_files, reachable)))
    findings = JuliaHarnessFinding[]
    for path in orphaned
        push!(
            findings,
            finding_from_rule(
                rules[JULIA_MOD_R006];
                summary="`$(path)` is under `src/` but is not reachable from `$(scope.package_entry_path)` through literal includes.",
                location=SourceLocation(path, 1, 0),
                source_line=source_line(parsed_by_path[path].source, 1),
                label="include this source from the package entry graph or document why it is intentionally separate",
            ),
        )
    end
    findings
end

function reachable_source_files(entry_path::String, parsed_by_path::Dict{String,ParsedJuliaFile})
    reachable = Set{String}()
    pending = [entry_path]
    while !isempty(pending)
        path = pop!(pending)
        path in reachable && continue
        push!(reachable, path)
        parsed = get(parsed_by_path, path, nothing)
        isnothing(parsed) && continue
        for include in parsed.syntax_facts.includes
            include.is_literal || continue
            isnothing(include.resolved_target) && continue
            include.resolved_target in reachable && continue
            haskey(parsed_by_path, include.resolved_target) && push!(pending, include.resolved_target)
        end
    end
    reachable
end

function is_path_under(path::AbstractString, root::AbstractString)
    relative = relpath(path, root)
    relative == "." || (!startswith(relative, "..") && !isabspath(relative))
end

function evaluate_default_rule_packs(
    scope::Union{Nothing,JuliaProjectHarnessScope},
    parsed_files::Vector{ParsedJuliaFile},
    config::JuliaHarnessConfig,
)
    findings = vcat(
        evaluate_syntax_rules(parsed_files),
        evaluate_project_policy_rules(scope, parsed_files),
        evaluate_modularity_rules(scope, parsed_files),
    )
    apply_config_to_findings(findings, config)
end
