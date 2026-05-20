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
