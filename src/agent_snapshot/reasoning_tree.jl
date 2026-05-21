const MAX_AGENT_REASONING_TREE_LINES = 32
const MAX_AGENT_REASONING_TREE_ITEMS = 8

function snapshot_reasoning_tree_lines(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
)
    lines = ["- root $(reasoning_tree_root_detail(scope))"]
    sorted_files = sort!(copy(parsed_files); by=parsed -> display_project_path(scope, parsed.report.path))
    append!(lines, reasoning_tree_owner_line.(Ref(scope), sorted_files))
    filter!(!isempty, lines)
    compact_reasoning_tree_lines(lines)
end

function reasoning_tree_root_detail(scope::JuliaProjectHarnessScope)
    segments = ["package=$(something(scope.package_name, "<unknown>"))"]
    !isnothing(scope.package_entry_path) &&
        push!(segments, "entry=$(display_project_path(scope, scope.package_entry_path))")
    !isempty(scope.workspace_projects) &&
        push!(segments, "workspace=$(length(scope.workspace_projects))")
    !isempty(scope.source_dependency_projects) &&
        push!(segments, "source-deps=$(length(scope.source_dependency_projects))")
    join(segments, " ")
end

function reasoning_tree_owner_line(
    scope::JuliaProjectHarnessScope,
    parsed::ParsedJuliaFile,
)
    segments = reasoning_tree_owner_segments(scope, parsed)
    isempty(segments) && return ""
    "- owner $(display_project_path(scope, parsed.report.path)) $(join(segments, " "))"
end

function reasoning_tree_owner_segments(
    scope::JuliaProjectHarnessScope,
    parsed::ParsedJuliaFile,
)
    parsed.report.is_valid || return ["role=$(reasoning_tree_owner_role(scope, parsed.report.path))", "parse=invalid"]
    segments = ["role=$(reasoning_tree_owner_role(scope, parsed.report.path))"]
    append_reasoning_tree_segment!(segments, "modules", reasoning_tree_module_names(parsed))
    append_reasoning_tree_segment!(segments, "public", reasoning_tree_public_names(parsed))
    append_reasoning_tree_segment!(segments, "imports", reasoning_tree_import_roots(parsed))
    append_reasoning_tree_segment!(segments, "includes", reasoning_tree_include_targets(scope, parsed))
    append_reasoning_tree_segment!(segments, "types", reasoning_tree_type_names(parsed))
    append_reasoning_tree_segment!(segments, "bindings", reasoning_tree_binding_names(parsed))
    append_reasoning_tree_segment!(segments, "methods", reasoning_tree_method_names(parsed))
    append_reasoning_tree_segment!(segments, "tests", reasoning_tree_test_labels(parsed))
    segments
end

function reasoning_tree_owner_role(scope::JuliaProjectHarnessScope, path::AbstractString)
    !isnothing(scope.package_entry_path) && path == scope.package_entry_path && return "entry"
    is_test_path(scope, path) && return "test"
    any(extension_path -> is_path_under(path, extension_path), scope.extension_paths) && return "extension"
    any(source_path -> is_path_under(path, source_path), scope.source_paths) && return "source"
    "owner"
end

function append_reasoning_tree_segment!(
    segments::Vector{String},
    label::AbstractString,
    values::Vector{String},
)
    detail = compact_reasoning_tree_items(values)
    isempty(detail) || push!(segments, "$(label)=$(detail)")
    segments
end

reasoning_tree_module_names(parsed::ParsedJuliaFile) =
    [module_fact.name for module_fact in parsed.syntax_facts.modules]

function reasoning_tree_public_names(parsed::ParsedJuliaFile)
    names = String[]
    for exported in parsed.syntax_facts.exports
        append!(names, exported.names)
    end
    names
end

reasoning_tree_import_roots(parsed::ParsedJuliaFile) =
    [imported.root for imported in parsed.syntax_facts.imports]

function reasoning_tree_include_targets(
    scope::JuliaProjectHarnessScope,
    parsed::ParsedJuliaFile,
)
    [
        display_project_path(scope, include.resolved_target) for include in parsed.syntax_facts.includes
        if include.is_literal && !isnothing(include.resolved_target)
    ]
end

reasoning_tree_type_names(parsed::ParsedJuliaFile) =
    [type_fact.name for type_fact in parsed.syntax_facts.types]

reasoning_tree_binding_names(parsed::ParsedJuliaFile) =
    [binding_fact.terminal_name for binding_fact in parsed.syntax_facts.bindings]

reasoning_tree_method_names(parsed::ParsedJuliaFile) =
    [function_fact.terminal_name for function_fact in parsed.syntax_facts.functions]

function reasoning_tree_test_labels(parsed::ParsedJuliaFile)
    labels = String[
        display_test_label(test_fact.label) for test_fact in parsed.syntax_facts.tests
        if test_fact.kind == "testset" && !isnothing(test_fact.label)
    ]
    direct_count = count(test_fact -> test_fact.kind != "testset", parsed.syntax_facts.tests)
    direct_count == 0 ? labels : vcat(labels, ["direct=$(direct_count)"])
end

function compact_reasoning_tree_items(values::Vector{String})
    compact_values = sort!(unique(filter(value -> !isempty(value), values)))
    isempty(compact_values) && return ""
    length(compact_values) <= MAX_AGENT_REASONING_TREE_ITEMS &&
        return join(compact_values, ",")
    kept = compact_values[1:MAX_AGENT_REASONING_TREE_ITEMS]
    push!(kept, "+$(length(compact_values) - MAX_AGENT_REASONING_TREE_ITEMS)")
    join(kept, ",")
end

function compact_reasoning_tree_lines(lines::Vector{String})
    length(lines) <= MAX_AGENT_REASONING_TREE_LINES && return lines
    kept = lines[1:MAX_AGENT_REASONING_TREE_LINES]
    push!(kept, "... $(length(lines) - MAX_AGENT_REASONING_TREE_LINES) more reasoning owners")
    kept
end
