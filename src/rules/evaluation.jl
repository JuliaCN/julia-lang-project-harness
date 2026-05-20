function evaluate_default_rule_packs(
    scope::Union{Nothing,JuliaProjectHarnessScope},
    parsed_files::Vector{ParsedJuliaFile},
    config::JuliaHarnessConfig,
    ;
    workspace_member_scopes=JuliaProjectHarnessScope[],
)
    findings = evaluate_syntax_rules(parsed_files)
    if !isnothing(scope)
        for scoped in vcat([scope], workspace_member_scopes)
            scoped_files = parsed_files_for_scope(scoped, parsed_files)
            append!(findings, evaluate_project_policy_rules(scoped, scoped_files, config))
            append!(findings, evaluate_modularity_rules(scoped, scoped_files))
            append!(findings, evaluate_agent_policy_rules(scoped, scoped_files))
        end
    end
    apply_config_to_findings(findings, config)
end

function parsed_files_for_scope(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
)
    [
        parsed for parsed in parsed_files if any(
            path -> is_path_under(parsed.report.path, path),
            scope_monitored_paths(scope),
        )
    ]
end

function evaluate_agent_policy_rules(
    scope::Union{Nothing,JuliaProjectHarnessScope},
    parsed_files::Vector{ParsedJuliaFile},
)
    isnothing(scope) && return JuliaHarnessFinding[]
    rules = rules_by_id()
    public_names = package_public_names(parsed_files)
    isempty(public_names) && return JuliaHarnessFinding[]
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        parsed.report.is_valid || continue
        for function_fact in parsed.syntax_facts.functions
            function_fact.terminal_name in public_names || continue
            if length(function_fact.positional_args) >= 5
                push!(
                    findings,
                    finding_from_rule(
                        rules[AGENT_JL_R002];
                        summary="Exported/public method `$(function_fact.terminal_name)` has $(length(function_fact.positional_args)) positional arguments: $(join(function_fact.positional_args, ", ")).",
                        location=SourceLocation(parsed.report.path, function_fact.line, function_fact.column),
                        source_line=source_line(parsed.source, function_fact.line),
                        label="move optional modes into keywords or a named config surface",
                    ),
                )
            end
            if length(function_fact.bool_positional_args) >= 2
                push!(
                    findings,
                    finding_from_rule(
                        rules[AGENT_JL_R003];
                        summary="Exported/public method `$(function_fact.terminal_name)` has positional Bool flags: $(join(function_fact.bool_positional_args, ", ")).",
                        location=SourceLocation(parsed.report.path, function_fact.line, function_fact.column),
                        source_line=source_line(parsed.source, function_fact.line),
                        label="move Bool flags into keywords or a named options object",
                    ),
                )
            end
        end
    end
    findings
end

function package_public_names(parsed_files::Vector{ParsedJuliaFile})
    names = Set{String}()
    for parsed in parsed_files
        for export_fact in parsed.syntax_facts.exports
            union!(names, export_fact.names)
        end
    end
    names
end
