const MAX_AGENT_SNAPSHOT_INCLUDE_LINES = 24

function render_julia_project_harness_agent_snapshot(
    project_root::AbstractString;
    config=default_julia_harness_config(),
)
    isdir(project_root) || error("project root does not exist: $(project_root)")
    scope = julia_project_harness_scope(project_root, config)
    parsed_files = [parse_julia_file(path) for path in discover_julia_files(scope_monitored_paths(scope), config)]
    findings = evaluate_default_rule_packs(scope, parsed_files, config)
    render_julia_package_snapshot(scope, parsed_files, findings)
end

function render_julia_package_snapshot(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    findings::Vector{JuliaHarnessFinding},
)
    source_count = count(
        parsed -> any(source_path -> is_path_under(parsed.report.path, source_path), scope.source_paths),
        parsed_files,
    )
    test_count = count(
        parsed -> any(test_path -> is_path_under(parsed.report.path, test_path), scope.test_paths),
        parsed_files,
    )
    rendered = "Package: $(something(scope.package_name, "<unknown>"))\n"
    rendered *= "Files: source=$(source_count) test=$(test_count)\n"
    if !isnothing(scope.package_entry_path)
        rendered *= "Entry: $(display_project_path(scope, scope.package_entry_path))\n"
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
