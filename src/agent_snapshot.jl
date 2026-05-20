const MAX_AGENT_SNAPSHOT_INCLUDE_LINES = 24
const MAX_AGENT_SNAPSHOT_METHODS_PER_FILE = 12
const MAX_AGENT_SNAPSHOT_TESTSETS_PER_FILE = 8

function render_julia_project_harness_agent_snapshot(
    project_root::AbstractString;
    config=default_julia_harness_config(),
)
    isdir(project_root) || error("project root does not exist: $(project_root)")
    scope = julia_project_harness_scope(project_root, config)
    workspace_member_scopes = julia_workspace_member_scopes(scope, config)
    monitored_paths = vcat(
        scope_monitored_paths(scope),
        mapreduce(scope_monitored_paths, vcat, workspace_member_scopes; init=String[]),
    )
    parsed_files = [parse_julia_file(path) for path in discover_julia_files(monitored_paths, config)]
    findings = evaluate_default_rule_packs(
        scope,
        parsed_files,
        config;
        workspace_member_scopes=workspace_member_scopes,
    )
    render_julia_package_snapshot(
        scope,
        parsed_files_for_scope(scope, parsed_files),
        findings;
        workspace_member_scopes,
    )
end

function render_julia_package_snapshot(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    findings::Vector{JuliaHarnessFinding},
    ;
    workspace_member_scopes=JuliaProjectHarnessScope[],
)
    source_count = count(
        parsed -> any(source_path -> is_path_under(parsed.report.path, source_path), scope.source_paths),
        parsed_files,
    )
    test_count = count(
        parsed -> any(test_path -> is_path_under(parsed.report.path, test_path), scope.test_paths),
        parsed_files,
    )
    uuid_suffix = isnothing(scope.package_uuid) ? "" : " uuid=$(scope.package_uuid)"
    rendered = "Package: $(something(scope.package_name, "<unknown>"))$(uuid_suffix)\n"
    rendered *= "Files: source=$(source_count) test=$(test_count)\n"
    if !isnothing(scope.package_entry_path)
        rendered *= "Entry: $(display_project_path(scope, scope.package_entry_path))\n"
    end
    project_lines = snapshot_project_lines(scope)
    if !isempty(project_lines)
        rendered *= "Project:\n"
        rendered *= join(project_lines, "\n") * "\n"
    end
    workspace_lines = snapshot_workspace_lines(scope, workspace_member_scopes)
    if !isempty(workspace_lines)
        rendered *= "Workspace:\n"
        rendered *= join(workspace_lines, "\n") * "\n"
    end
    module_lines = snapshot_module_lines(scope, parsed_files)
    if !isempty(module_lines)
        rendered *= "Modules:\n"
        rendered *= join(module_lines, "\n") * "\n"
    end
    public_lines = snapshot_public_lines(scope, parsed_files)
    if !isempty(public_lines)
        rendered *= "Public:\n"
        rendered *= join(public_lines, "\n") * "\n"
    end
    import_lines = snapshot_import_lines(scope, parsed_files)
    if !isempty(import_lines)
        rendered *= "Imports:\n"
        rendered *= join(import_lines, "\n") * "\n"
    end
    type_lines = snapshot_type_lines(scope, parsed_files)
    if !isempty(type_lines)
        rendered *= "Types:\n"
        rendered *= join(type_lines, "\n") * "\n"
    end
    method_lines = snapshot_method_lines(scope, parsed_files)
    if !isempty(method_lines)
        rendered *= "Methods:\n"
        rendered *= join(method_lines, "\n") * "\n"
    end
    test_lines = snapshot_test_lines(scope, parsed_files)
    if !isempty(test_lines)
        rendered *= "Tests:\n"
        rendered *= join(test_lines, "\n") * "\n"
    end
    include_lines = compact_include_lines(scope, parsed_files)
    if !isempty(include_lines)
        rendered *= "Includes:\n"
        rendered *= join(include_lines, "\n") * "\n"
    end
    dynamic_lines = dynamic_include_lines(scope, parsed_files)
    if !isempty(dynamic_lines)
        rendered *= "DynamicIncludes:\n"
        rendered *= join(dynamic_lines, "\n") * "\n"
    end
    finding_lines = snapshot_finding_lines(scope, findings)
    if !isempty(finding_lines)
        rendered *= "FindingGroups:\n"
        rendered *= join(finding_lines, "\n") * "\n"
    end
    rendered
end

function snapshot_project_lines(scope::JuliaProjectHarnessScope)
    lines = String[]
    !isnothing(scope.project_entryfile) && push!(lines, "- entryfile=$(scope.project_entryfile)")
    !isempty(scope.workspace_projects) &&
        push!(lines, "- workspace=$(join(scope.workspace_projects, ","))")
    dependency_line = compact_project_dependency_line(scope)
    !isempty(dependency_line) && push!(lines, "- $(dependency_line)")
    target_line = compact_project_targets_line(scope)
    !isempty(target_line) && push!(lines, "- $(target_line)")
    source_line = compact_project_sources_line(scope)
    !isempty(source_line) && push!(lines, "- $(source_line)")
    lines
end

function snapshot_workspace_lines(
    scope::JuliaProjectHarnessScope,
    workspace_member_scopes::Vector{JuliaProjectHarnessScope},
)
    lines = String[]
    for member in workspace_member_scopes
        label = something(member.package_name, "<unknown>")
        root = display_project_path(scope, member.project_root)
        entry = isnothing(member.package_entry_path) ? "" :
                " entry=$(display_project_path(scope, member.package_entry_path))"
        push!(lines, "- $(label) root=$(root)$(entry)")
    end
    lines
end

function compact_project_dependency_line(scope::JuliaProjectHarnessScope)
    segments = String[]
    !isempty(scope.direct_dependencies) &&
        push!(segments, "deps=$(join(sort!(collect(keys(scope.direct_dependencies))), ","))")
    !isempty(scope.weak_dependencies) &&
        push!(segments, "weakdeps=$(join(sort!(collect(keys(scope.weak_dependencies))), ","))")
    !isempty(scope.extra_dependencies) &&
        push!(segments, "extras=$(join(sort!(collect(keys(scope.extra_dependencies))), ","))")
    join(segments, " ")
end

function compact_project_targets_line(scope::JuliaProjectHarnessScope)
    isempty(scope.targets) && return ""
    target_segments = [
        "$(target)=$(join(sort!(copy(names)), ","))" for (target, names) in sort!(collect(scope.targets))
    ]
    "targets=$(join(target_segments, ";"))"
end

function compact_project_sources_line(scope::JuliaProjectHarnessScope)
    isempty(scope.sources) && return ""
    source_segments = String[]
    for (name, source) in sort!(collect(scope.sources))
        attrs = ["$(key)=$(value)" for (key, value) in sort!(collect(source))]
        push!(source_segments, "$(name)($(join(attrs, ",")))")
    end
    "sources=$(join(source_segments, ";"))"
end

function snapshot_module_lines(scope::JuliaProjectHarnessScope, parsed_files::Vector{ParsedJuliaFile})
    lines = String[]
    for parsed in parsed_files
        isempty(parsed.syntax_facts.modules) && continue
        labels = [
            mod.is_bare ? "baremodule=$(mod.name)" : "module=$(mod.name)"
            for mod in parsed.syntax_facts.modules
        ]
        push!(lines, "- $(display_project_path(scope, parsed.report.path)) $(join(labels, ", "))")
    end
    lines
end

function snapshot_public_lines(scope::JuliaProjectHarnessScope, parsed_files::Vector{ParsedJuliaFile})
    lines = String[]
    for parsed in parsed_files
        isempty(parsed.syntax_facts.exports) && continue
        groups = [
            "$(exported.kind)=$(join(exported.names, ","))" for exported in parsed.syntax_facts.exports
        ]
        push!(lines, "- $(display_project_path(scope, parsed.report.path)) $(join(groups, " "))")
    end
    lines
end

function snapshot_import_lines(scope::JuliaProjectHarnessScope, parsed_files::Vector{ParsedJuliaFile})
    lines = String[]
    for parsed in parsed_files
        isempty(parsed.syntax_facts.imports) && continue
        imports = [display_import_syntax(imported) for imported in parsed.syntax_facts.imports]
        push!(lines, "- $(display_project_path(scope, parsed.report.path)) $(join(imports, "; "))")
    end
    lines
end

function display_import_syntax(imported::JuliaImportSyntax)
    suffix = isempty(imported.names) ? "" : ":$(join(imported.names, ","))"
    "$(imported.kind)=$(imported.root)$(suffix)"
end

function snapshot_type_lines(scope::JuliaProjectHarnessScope, parsed_files::Vector{ParsedJuliaFile})
    lines = String[]
    for parsed in parsed_files
        isempty(parsed.syntax_facts.types) && continue
        types = [display_type_syntax(type_fact) for type_fact in parsed.syntax_facts.types]
        push!(lines, "- $(display_project_path(scope, parsed.report.path)) $(join(types, "; "))")
    end
    lines
end

function display_type_syntax(type_fact::JuliaTypeSyntax)
    kind = type_fact.kind == "struct" && type_fact.is_mutable ? "mutable struct" :
           type_fact.kind
    parameter_suffix = isempty(type_fact.parameters) ? "" : "{$(join(type_fact.parameters, ","))}"
    supertype_suffix = isnothing(type_fact.supertype) ? "" : "<:$(type_fact.supertype)"
    field_suffix = isempty(type_fact.fields) ? "" : " fields=$(length(type_fact.fields))"
    "$(kind)=$(type_fact.name)$(parameter_suffix)$(supertype_suffix)$(field_suffix)"
end

function snapshot_method_lines(scope::JuliaProjectHarnessScope, parsed_files::Vector{ParsedJuliaFile})
    lines = String[]
    for parsed in parsed_files
        isempty(parsed.syntax_facts.functions) && continue
        methods = compact_snapshot_methods([
            display_function_syntax(function_fact) for function_fact in parsed.syntax_facts.functions
        ])
        push!(lines, "- $(display_project_path(scope, parsed.report.path)) $(join(methods, "; "))")
    end
    lines
end

function compact_snapshot_methods(methods::Vector{String})
    length(methods) <= MAX_AGENT_SNAPSHOT_METHODS_PER_FILE && return methods
    kept = methods[1:MAX_AGENT_SNAPSHOT_METHODS_PER_FILE]
    push!(kept, "... $(length(methods) - MAX_AGENT_SNAPSHOT_METHODS_PER_FILE) more methods")
    kept
end

function display_function_syntax(function_fact::JuliaFunctionSyntax)
    keyword_suffix = isempty(function_fact.keyword_args) ? "" :
                     ";kw=$(length(function_fact.keyword_args))"
    "$(function_fact.kind)=$(function_fact.name)/$(length(function_fact.positional_args))$(keyword_suffix)"
end

function snapshot_test_lines(scope::JuliaProjectHarnessScope, parsed_files::Vector{ParsedJuliaFile})
    lines = String[]
    for parsed in parsed_files
        isempty(parsed.syntax_facts.tests) && continue
        testsets = compact_snapshot_testsets(String[
            test_fact.label for test_fact in parsed.syntax_facts.tests
            if test_fact.kind == "testset" && !isnothing(test_fact.label)
        ])
        counts = test_counts(parsed.syntax_facts.tests)
        segments = String[]
        if !isempty(testsets)
            push!(segments, "testsets=$(join(display_test_label.(testsets), ","))")
        end
        for (kind, count) in sort!(collect(counts))
            kind == "testset" && continue
            push!(segments, "$(kind)=$(count)")
        end
        isempty(segments) && push!(segments, "testset=$(get(counts, "testset", 0))")
        push!(lines, "- $(display_project_path(scope, parsed.report.path)) $(join(segments, " "))")
    end
    lines
end

function compact_snapshot_testsets(testsets::Vector{String})
    length(testsets) <= MAX_AGENT_SNAPSHOT_TESTSETS_PER_FILE && return testsets
    kept = testsets[1:MAX_AGENT_SNAPSHOT_TESTSETS_PER_FILE]
    push!(kept, "... $(length(testsets) - MAX_AGENT_SNAPSHOT_TESTSETS_PER_FILE) more testsets")
    kept
end

function test_counts(tests::Vector{JuliaTestSyntax})
    counts = Dict{String,Int}()
    for test_fact in tests
        counts[test_fact.kind] = get(counts, test_fact.kind, 0) + 1
    end
    counts
end

function display_test_label(label::AbstractString)
    "\"$(replace(String(label), "\"" => "\\\"", "\n" => " "))\""
end

function compact_include_lines(scope::JuliaProjectHarnessScope, parsed_files::Vector{ParsedJuliaFile})
    lines = String[]
    for parsed in parsed_files
        targets = [
            display_project_path(scope, include.resolved_target) for include in parsed.syntax_facts.includes
            if include.is_literal && !isnothing(include.resolved_target)
        ]
        isempty(targets) && continue
        push!(lines, "- $(display_project_path(scope, parsed.report.path)) -> $(join(targets, ", "))")
    end
    if length(lines) > MAX_AGENT_SNAPSHOT_INCLUDE_LINES
        kept = lines[1:MAX_AGENT_SNAPSHOT_INCLUDE_LINES]
        push!(kept, "... $(length(lines) - MAX_AGENT_SNAPSHOT_INCLUDE_LINES) more include owners")
        return kept
    end
    lines
end

function dynamic_include_lines(scope::JuliaProjectHarnessScope, parsed_files::Vector{ParsedJuliaFile})
    lines = String[]
    for parsed in parsed_files
        for include in parsed.syntax_facts.includes
            include.is_literal && continue
            push!(
                lines,
                "- $(display_project_path(scope, parsed.report.path)):$(include.line) $(include.expression)",
            )
        end
    end
    lines
end

function snapshot_finding_lines(scope::JuliaProjectHarnessScope, findings::Vector{JuliaHarnessFinding})
    grouped = Dict{String,Int}()
    for finding in findings
        grouped[finding.rule_id] = get(grouped, finding.rule_id, 0) + 1
    end
    ["- $(rule_id) count=$(count)" for (rule_id, count) in sort!(collect(grouped))]
end

function display_project_path(scope::JuliaProjectHarnessScope, path::AbstractString)
    slash_path(relpath(path, scope.project_root))
end
