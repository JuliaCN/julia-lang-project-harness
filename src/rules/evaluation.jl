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
    documented_names = package_documented_public_names(parsed_files)
    append!(findings, public_api_doc_findings(parsed_files, public_names, documented_names, rules))
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
            if !isempty(function_fact.stringly_domain_args)
                push!(
                    findings,
                    finding_from_rule(
                        rules[AGENT_JL_R004];
                        summary="Exported/public method `$(function_fact.terminal_name)` exposes stringly domain arguments: $(join(function_fact.stringly_domain_args, ", ")).",
                        location=SourceLocation(parsed.report.path, function_fact.line, function_fact.column),
                        source_line=source_line(parsed.source, function_fact.line),
                        label="replace stringly domain arguments with a named enum, value type, or config carrier",
                    ),
                )
            end
        end
    end
    findings
end

function public_api_doc_findings(
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    documented_names::Set{String},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    reported = Set{Tuple{String,String}}()
    for parsed in parsed_files
        parsed.report.is_valid || continue
        for type_fact in parsed.syntax_facts.types
            name = terminal_public_name(type_fact.name)
            name in public_names || continue
            name in documented_names && continue
            key = ("type", name)
            key in reported && continue
            push!(reported, key)
            push!(
                findings,
                finding_from_rule(
                    rules[AGENT_JL_R001];
                    summary="Exported/public type `$(name)` lacks a Julia docstring that states its agent-facing intent.",
                    location=SourceLocation(parsed.report.path, type_fact.line, type_fact.column),
                    source_line=source_line(parsed.source, type_fact.line),
                    label="add a Julia docstring before the public type definition",
                ),
            )
        end
        for function_fact in parsed.syntax_facts.functions
            name = function_fact.terminal_name
            name in public_names || continue
            name in documented_names && continue
            key = ("function", name)
            key in reported && continue
            push!(reported, key)
            push!(
                findings,
                finding_from_rule(
                    rules[AGENT_JL_R001];
                    summary="Exported/public function `$(name)` lacks a Julia docstring that states its agent-facing intent.",
                    location=SourceLocation(parsed.report.path, function_fact.line, function_fact.column),
                    source_line=source_line(parsed.source, function_fact.line),
                    label="add a Julia docstring before the public function definition",
                ),
            )
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

function package_documented_public_names(parsed_files::Vector{ParsedJuliaFile})
    names = Set{String}()
    for parsed in parsed_files
        parsed.report.is_valid || continue
        for docstring_fact in parsed.syntax_facts.docstrings
            push!(names, terminal_public_name(docstring_fact.target_name))
        end
    end
    names
end

terminal_public_name(name::AbstractString) = last(split(String(name), "."))
