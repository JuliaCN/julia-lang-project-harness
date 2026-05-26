function snapshot_project_lines(scope::JuliaProjectHarnessScope)
    lines = String[]
    !isnothing(scope.project_parse_error) &&
        push!(lines, "- project_error=$(scope.project_parse_error)")
    !isnothing(scope.project_entryfile) && push!(lines, "- entryfile=$(scope.project_entryfile)")
    !isempty(scope.workspace_projects) &&
        push!(lines, "- workspace=$(join(scope.workspace_projects, ","))")
    !isempty(scope.source_dependency_projects) &&
        push!(lines, "- source-deps=$(join(scope.source_dependency_projects, ","))")
    dependency_line = compact_project_dependency_line(scope)
    !isempty(dependency_line) && push!(lines, "- $(dependency_line)")
    target_line = compact_project_targets_line(scope)
    !isempty(target_line) && push!(lines, "- $(target_line)")
    compat_line = compact_project_compat_line(scope)
    !isempty(compat_line) && push!(lines, "- $(compat_line)")
    source_line = compact_project_sources_line(scope)
    !isempty(source_line) && push!(lines, "- $(source_line)")
    extension_line = compact_project_extensions_line(scope)
    !isempty(extension_line) && push!(lines, "- $(extension_line)")
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
        "$(target)=$(join(sort!(copy(names)), ","))" for
        (target, names) in sort!(collect(scope.targets); by = first)
    ]
    "targets=$(join(target_segments, ";"))"
end

function compact_project_compat_line(scope::JuliaProjectHarnessScope)
    isempty(scope.compat) && return ""
    compat_segments = [
        "$(name)=$(value)" for (name, value) in sort!(collect(scope.compat); by = first)
    ]
    "compat=$(join(compat_segments, ";"))"
end

function compact_project_sources_line(scope::JuliaProjectHarnessScope)
    isempty(scope.sources) && return ""
    source_segments = String[]
    for (name, source) in sort!(collect(scope.sources); by = first)
        attrs = ["$(key)=$(value)" for (key, value) in sort!(collect(source); by = first)]
        push!(source_segments, "$(name)($(join(attrs, ",")))")
    end
    "sources=$(join(source_segments, ";"))"
end

function compact_project_extensions_line(scope::JuliaProjectHarnessScope)
    isempty(scope.extensions) && return ""
    extension_segments = [
        "$(name)=$(join(sort!(copy(dependencies)), ","))" for
        (name, dependencies) in sort!(collect(scope.extensions); by = first)
    ]
    "extensions=$(join(extension_segments, ";"))"
end
