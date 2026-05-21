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
    findings = verification_test_profile_findings(scope, parsed_files, rules)
    public_names = package_public_names(parsed_files)
    function_docs_by_name = Dict{String,Vector{String}}()
    if !isempty(public_names)
        documented_names = package_documented_public_names(parsed_files)
        function_docs_by_name = package_function_docstrings_by_public_name(parsed_files)
        type_docs_by_name = package_type_docstrings_by_public_name(parsed_files)
        append!(findings, public_api_doc_findings(parsed_files, public_names, documented_names, rules))
        append!(findings, public_type_field_shape_findings(parsed_files, public_names, rules))
        append!(findings, public_type_stringly_field_findings(parsed_files, public_names, rules))
        append!(findings, public_mutable_type_contract_findings(
            parsed_files,
            public_names,
            type_docs_by_name,
            rules,
        ))
        append!(findings, public_mutating_method_contract_findings(
            parsed_files,
            public_names,
            function_docs_by_name,
            rules,
        ))
        append!(findings, public_return_contract_findings(
            parsed_files,
            public_names,
            function_docs_by_name,
            rules,
        ))
        append!(findings, public_api_owner_conflict_findings(scope, parsed_files, public_names, rules))
        append!(findings, public_method_family_scattering_findings(
            scope,
            parsed_files,
            public_names,
            function_docs_by_name,
            rules,
        ))
        append!(findings, public_generic_type_coverage_findings(
            scope,
            parsed_files,
            public_names,
            rules,
        ))
        append!(findings, public_documenter_example_findings(scope, public_names, rules))
        append!(findings, moshi_domain_model_findings(scope, parsed_files, public_names, rules))
        append!(findings, moshi_domain_bridge_findings(scope, parsed_files, public_names, rules))
    end
    append!(findings, module_owner_fanout_findings(scope, parsed_files, rules))
    append!(findings, unsafe_construct_findings(scope, parsed_files, rules))
    append!(findings, external_method_extension_findings(scope, parsed_files, rules))
    append!(findings, mutable_global_state_findings(scope, parsed_files, rules))
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
                        summary="Exported/public method `$(function_fact.terminal_name)` has control-flow depth $(function_fact.control_flow_depth): $(join(function_fact.control_flow_kinds, ", ")). $(julia_algorithm_shape_summary(function_fact))",
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
    append!(findings, internal_traversal_shape_findings(scope, parsed_files, public_names, rules))
    findings
end

const MAX_PUBLIC_METHOD_CONTROL_FLOW_DEPTH = 4
const MAX_PUBLIC_METHOD_BODY_STATEMENTS = 8
const MIN_PUBLIC_METHOD_PIPELINE_STEPS = 3
const MAX_PUBLIC_METHOD_MACRO_INVOCATIONS = 3
const MAX_INTERNAL_TRAVERSAL_CONTROL_FLOW_DEPTH = 4
const MAX_INTERNAL_TRAVERSAL_LOOP_NESTING_DEPTH = 2
const MIN_INTERNAL_TRAVERSAL_BRANCH_COUNT = 2
const MAX_UNDOCUMENTED_MODULE_OWNER_INCLUDES = 4

function internal_traversal_shape_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        parsed.report.is_valid || continue
        is_test_path(scope, parsed.report.path) && continue
        for function_fact in parsed.syntax_facts.functions
            function_fact.kind == "function" || continue
            function_fact.terminal_name in public_names && continue
            is_nested_internal_traversal(function_fact) || continue
            push!(
                findings,
                finding_from_rule(
                    rules[AGENT_JL_R015];
                    summary="Internal method `$(function_fact.terminal_name)` nests traversal shape: $(julia_algorithm_shape_summary(function_fact))",
                    location=SourceLocation(parsed.report.path, function_fact.line, function_fact.column),
                    source_line=source_line(parsed.source, function_fact.line),
                    label="extract traversal into named iterator, predicate, or data-processing helpers",
                ),
            )
        end
    end
    findings
end

function is_nested_internal_traversal(function_fact::JuliaFunctionSyntax)
    function_fact.control_flow_depth >= MAX_INTERNAL_TRAVERSAL_CONTROL_FLOW_DEPTH &&
        function_fact.loop_nesting_depth >= MAX_INTERNAL_TRAVERSAL_LOOP_NESTING_DEPTH &&
        function_fact.branch_count >= MIN_INTERNAL_TRAVERSAL_BRANCH_COUNT
end

function julia_algorithm_shape_summary(function_fact::JuliaFunctionSyntax)
    "branches=$(function_fact.branch_count), loops=$(function_fact.loop_count), loop_depth=$(function_fact.loop_nesting_depth)"
end

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
        syntax_families == ["function"] && continue
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
        for binding_fact in parsed.syntax_facts.bindings
            name = binding_fact.terminal_name
            name in public_names || continue
            push_public_api_definition!(
                records,
                name,
                binding_fact.kind,
                parsed,
                binding_fact.line,
                binding_fact.column,
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

terminal_public_name(name::AbstractString) = last(split(String(name), "."))
