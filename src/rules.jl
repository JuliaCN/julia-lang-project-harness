const JULIA_SYNTAX_PACK_ID = "julia.syntax"
const JULIA_PROJECT_POLICY_PACK_ID = "julia.project_policy"
const JULIA_MODULARITY_PACK_ID = "julia.modularity"
const JULIA_AGENT_POLICY_PACK_ID = "julia.agent_policy"
const JULIA_SYN_R001 = "JULIA-SYN-R001"

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

julia_project_policy_rules() = JuliaHarnessRule[]
julia_modularity_rules() = JuliaHarnessRule[]
julia_agent_policy_rules() = JuliaHarnessRule[]

function syntax_rule_by_id()
    Dict(rule.rule_id => rule for rule in julia_syntax_rules())
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

function evaluate_default_rule_packs(parsed_files::Vector{ParsedJuliaFile}, config::JuliaHarnessConfig)
    apply_config_to_findings(evaluate_syntax_rules(parsed_files), config)
end
