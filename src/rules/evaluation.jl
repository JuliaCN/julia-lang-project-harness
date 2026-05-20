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
    function_docs_by_name = package_function_docstrings_by_public_name(parsed_files)
    append!(findings, public_api_doc_findings(parsed_files, public_names, documented_names, rules))
    append!(findings, public_api_owner_conflict_findings(scope, parsed_files, public_names, rules))
    append!(findings, module_owner_fanout_findings(scope, parsed_files, rules))
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
            if function_fact.kind == "function" &&
               function_fact.control_flow_depth >= MAX_PUBLIC_METHOD_CONTROL_FLOW_DEPTH
                push!(
                    findings,
                    finding_from_rule(
                        rules[AGENT_JL_R007];
                        summary="Exported/public method `$(function_fact.terminal_name)` has control-flow depth $(function_fact.control_flow_depth): $(join(function_fact.control_flow_kinds, ", ")).",
                        location=SourceLocation(parsed.report.path, function_fact.line, function_fact.column),
                        source_line=source_line(parsed.source, function_fact.line),
                        label="extract nested branches and loops into named pipeline steps",
                    ),
                )
            end
            if function_fact.kind == "function" &&
               function_fact.body_statement_count >= MAX_PUBLIC_METHOD_BODY_STATEMENTS &&
               length(function_fact.body_named_calls) < MIN_PUBLIC_METHOD_PIPELINE_STEPS
                push!(
                    findings,
                    finding_from_rule(
                        rules[AGENT_JL_R008];
                        summary="Exported/public method `$(function_fact.terminal_name)` has $(function_fact.body_statement_count) top-level body statements but only $(length(function_fact.body_named_calls)) named body calls.",
                        location=SourceLocation(parsed.report.path, function_fact.line, function_fact.column),
                        source_line=source_line(parsed.source, function_fact.line),
                        label="split the broad public body into named pipeline helper functions",
                    ),
                )
            end
            if function_fact.kind == "function" &&
               haskey(function_docs_by_name, function_fact.terminal_name) &&
               function_fact.macro_invocation_count >= MAX_PUBLIC_METHOD_MACRO_INVOCATIONS &&
               !has_syntax_contract_doc(function_docs_by_name, function_fact.terminal_name)
                push!(
                    findings,
                    finding_from_rule(
                        rules[AGENT_JL_R010];
                        summary="Exported/public method `$(function_fact.terminal_name)` uses $(function_fact.macro_invocation_count) macro invocations without a syntax contract doc: $(join(function_fact.macro_invocation_names, ", ")).",
                        location=SourceLocation(parsed.report.path, function_fact.line, function_fact.column),
                        source_line=source_line(parsed.source, function_fact.line),
                        label="document the syntax or macro-expansion contract for this public method",
                    ),
                )
            end
        end
    end
    findings
end

const MAX_PUBLIC_METHOD_CONTROL_FLOW_DEPTH = 4
const MAX_PUBLIC_METHOD_BODY_STATEMENTS = 8
const MIN_PUBLIC_METHOD_PIPELINE_STEPS = 3
const MAX_PUBLIC_METHOD_MACRO_INVOCATIONS = 3
const MAX_UNDOCUMENTED_MODULE_OWNER_INCLUDES = 4
const SYNTAX_CONTRACT_DOC_TOKENS = ("syntax", "macro", "expansion", "generated", "contract")

function module_owner_fanout_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        parsed.report.is_valid || continue
        isempty(parsed.syntax_facts.modules) && continue
        literal_local_includes = [
            include for include in parsed.syntax_facts.includes if is_local_owner_include(scope, include)
        ]
        length(literal_local_includes) >= MAX_UNDOCUMENTED_MODULE_OWNER_INCLUDES || continue
        has_module_intent_doc(parsed) && continue
        module_fact = first(parsed.syntax_facts.modules)
        owner_targets = [
            display_public_owner_path(scope, include.resolved_target) for include in
            literal_local_includes
        ]
        push!(
            findings,
            finding_from_rule(
                rules[AGENT_JL_R006];
                summary="Module owner `$(module_fact.name)` includes $(length(literal_local_includes)) local owners without a Julia docstring: $(join(owner_targets, ", ")).",
                location=SourceLocation(parsed.report.path, module_fact.line, module_fact.column),
                source_line=source_line(parsed.source, module_fact.line),
                label="add a module docstring that explains the include owner boundary",
            ),
        )
    end
    findings
end

function is_local_owner_include(scope::JuliaProjectHarnessScope, include::JuliaIncludeSyntax)
    include.is_literal || return false
    isnothing(include.resolved_target) && return false
    any(root -> is_path_under(include.resolved_target, root), scope.source_paths)
end

function has_module_intent_doc(parsed::ParsedJuliaFile)
    module_names = Set(module_fact.name for module_fact in parsed.syntax_facts.modules)
    any(
        docstring_fact -> docstring_fact.target_kind == "module" &&
                          docstring_fact.target_name in module_names,
        parsed.syntax_facts.docstrings,
    )
end

function public_api_owner_conflict_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    rules::Dict{String,JuliaHarnessRule},
)
    records = public_api_definition_records(parsed_files, public_names)
    findings = JuliaHarnessFinding[]
    for (name, definitions) in sort(collect(records); by=first)
        owner_paths = sort(unique(definition.path for definition in definitions))
        syntax_families = sort(unique(definition.kind for definition in definitions))
        length(owner_paths) > 1 || length(syntax_families) > 1 || continue
        first_definition = first(sort(definitions; by=definition -> (
            definition.path,
            definition.line,
            definition.column,
        )))
        owner_summary = join(display_public_owner_path.(Ref(scope), owner_paths), ", ")
        family_summary = join(syntax_families, ", ")
        push!(
            findings,
            finding_from_rule(
                rules[AGENT_JL_R005];
                summary="Exported/public API `$(name)` spans owners: $(owner_summary); syntax families: $(family_summary).",
                location=SourceLocation(
                    first_definition.path,
                    first_definition.line,
                    first_definition.column,
                ),
                source_line=first_definition.source_line,
                label="move the public API family behind one owner file or document the extension pattern",
            ),
        )
    end
    findings
end

function public_api_definition_records(
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
)
    records = Dict{String,Vector{NamedTuple}}()
    for parsed in parsed_files
        parsed.report.is_valid || continue
        for type_fact in parsed.syntax_facts.types
            name = terminal_public_name(type_fact.name)
            name in public_names || continue
            push_public_api_definition!(
                records,
                name,
                type_fact.kind,
                parsed,
                type_fact.line,
                type_fact.column,
            )
        end
        for function_fact in parsed.syntax_facts.functions
            name = function_fact.terminal_name
            name in public_names || continue
            push_public_api_definition!(
                records,
                name,
                function_fact.kind,
                parsed,
                function_fact.line,
                function_fact.column,
            )
        end
    end
    records
end

function push_public_api_definition!(
    records::Dict{String,Vector{NamedTuple}},
    name::AbstractString,
    kind::AbstractString,
    parsed::ParsedJuliaFile,
    line::Int,
    column::Int,
)
    definitions = get!(records, String(name), NamedTuple[])
    push!(
        definitions,
        (
            kind=String(kind),
            path=parsed.report.path,
            line=line,
            column=column,
            source_line=source_line(parsed.source, line),
        ),
    )
end

function display_public_owner_path(scope::JuliaProjectHarnessScope, path::AbstractString)
    relative_path = relpath(path, scope.project_root)
    parts = splitpath(relative_path)
    if !isabspath(relative_path) && (isempty(parts) || first(parts) != "..")
        return replace(relative_path, '\\' => '/')
    end
    replace(String(path), '\\' => '/')
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

function package_function_docstrings_by_public_name(parsed_files::Vector{ParsedJuliaFile})
    docs = Dict{String,Vector{String}}()
    for parsed in parsed_files
        parsed.report.is_valid || continue
        for docstring_fact in parsed.syntax_facts.docstrings
            docstring_fact.target_kind == "function" || continue
            name = terminal_public_name(docstring_fact.target_name)
            push!(get!(docs, name, String[]), docstring_fact.text)
        end
    end
    docs
end

function has_syntax_contract_doc(
    docs_by_name::Dict{String,Vector{String}},
    name::AbstractString,
)
    any(get(docs_by_name, String(name), String[])) do text
        lower_text = lowercase(text)
        any(token -> occursin(token, lower_text), SYNTAX_CONTRACT_DOC_TOKENS)
    end
end

terminal_public_name(name::AbstractString) = last(split(String(name), "."))
