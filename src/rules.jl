using Pkg

const JULIA_SYNTAX_PACK_ID = "julia.syntax"
const JULIA_PROJECT_POLICY_PACK_ID = "julia.project_policy"
const JULIA_MODULARITY_PACK_ID = "julia.modularity"
const JULIA_AGENT_POLICY_PACK_ID = "julia.agent_policy"
const JULIA_SYN_R001 = "JULIA-SYN-R001"
const JULIA_PROJ_R001 = "JULIA-PROJ-R001"
const JULIA_PROJ_R002 = "JULIA-PROJ-R002"
const JULIA_PROJ_R003 = "JULIA-PROJ-R003"
const JULIA_PROJ_R005 = "JULIA-PROJ-R005"
const JULIA_PROJ_R006 = "JULIA-PROJ-R006"
const JULIA_PROJ_R007 = "JULIA-PROJ-R007"
const JULIA_PROJ_R008 = "JULIA-PROJ-R008"
const JULIA_MOD_R003 = "JULIA-MOD-R003"
const JULIA_MOD_R004 = "JULIA-MOD-R004"
const JULIA_MOD_R005 = "JULIA-MOD-R005"
const JULIA_MOD_R006 = "JULIA-MOD-R006"
const JULIA_MOD_R007 = "JULIA-MOD-R007"
const AGENT_JL_R002 = "AGENT-JL-R002"

const GENERIC_SOURCE_OWNER_SEGMENTS = Set(["common", "helper", "helpers", "misc", "util", "utils"])

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

julia_project_policy_rules() = [
    JuliaHarnessRule(
        JULIA_PROJ_R001,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Project.toml lacks a package name",
        "Package project runners must parse `Project.toml` and find a concrete package name before package policy runs.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R002,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Package entry module is missing",
        "Julia packages should expose a parser-stable entry file at `src/<PackageName>.jl`, unless project config records a reason.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R003,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Pkg.test entrypoint is missing",
        "Julia package test scopes should mount the `Pkg.test` entrypoint at `test/runtests.jl`.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R005,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Custom source or test scope lacks explanation",
        "Custom Julia source or test scope paths must carry a non-empty project-local explanation.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R006,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Conventional source or test scope was excluded",
        "Excluding conventional Julia `src` or `test` scopes must carry a non-empty project-local explanation.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R007,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Package entry file lacks package module declaration",
        "The package entry file should declare a top-level module matching the `Project.toml` package name.",
        labels("project-policy"),
    ),
    JuliaHarnessRule(
        JULIA_PROJ_R008,
        JULIA_PROJECT_POLICY_PACK_ID,
        Warning,
        "Imported package is missing from Project.toml",
        "External Julia package imports should be declared in `Project.toml` as deps, weakdeps, or test extras according to their source scope.",
        labels("project-policy"),
    ),
]

julia_modularity_rules() = [
    JuliaHarnessRule(
        JULIA_MOD_R003,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Dynamic include hides source graph",
        "Keep Julia package source graphs parser-stable with literal `include(...)` targets, or record a project-local exception.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R004,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Literal include target is missing",
        "Every literal Julia `include(...)` target must resolve to an existing source file.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R005,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Literal include graph contains a cycle",
        "Julia package source graphs should stay acyclic so agents can follow one repair ownership path.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R006,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Source file is orphaned from package entry",
        "Julia source files under `src/` should be reachable from the package entry include graph, unless project config records a reason.",
        labels("modularity"),
    ),
    JuliaHarnessRule(
        JULIA_MOD_R007,
        JULIA_MODULARITY_PACK_ID,
        Warning,
        "Source path uses a generic owner bucket",
        "Julia source path segments should name domain ownership instead of generic buckets such as `utils`, `common`, `helpers`, or `misc`.",
        labels("modularity"),
    ),
]

julia_agent_policy_rules() = [
    JuliaHarnessRule(
        AGENT_JL_R002,
        JULIA_AGENT_POLICY_PACK_ID,
        Info,
        "Public method has a broad positional surface",
        "Prefer keyword options or a named config object when exported Julia methods need many arguments.",
        labels("agent-policy"),
    ),
]

function syntax_rule_by_id()
    Dict(rule.rule_id => rule for rule in julia_syntax_rules())
end

function rules_by_id()
    Dict(
        rule.rule_id => rule for rule in vcat(
            julia_syntax_rules(),
            julia_project_policy_rules(),
            julia_modularity_rules(),
            julia_agent_policy_rules(),
        )
    )
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

function evaluate_project_policy_rules(
    scope::Union{Nothing,JuliaProjectHarnessScope},
    parsed_files::Vector{ParsedJuliaFile},
    config::JuliaHarnessConfig,
)
    isnothing(scope) && return JuliaHarnessFinding[]
    rules = rules_by_id()
    findings = JuliaHarnessFinding[]
    if isnothing(scope.package_name)
        push!(
            findings,
            finding_from_rule(
                rules[JULIA_PROJ_R001];
                summary="Project.toml was not found or did not define a `name` field.",
                location=SourceLocation(scope.project_toml_path, 1, 0),
                label="add a package name to Project.toml before running package policy",
            ),
        )
    elseif isnothing(scope.package_entry_path)
        push!(
            findings,
            finding_from_rule(
                rules[JULIA_PROJ_R002];
                summary="Package `$(scope.package_name)` does not expose entry file `$(expected_entry_file(scope))`.",
                location=SourceLocation(scope.project_toml_path, 1, 0),
                label="add the package entry module or configure an explicit source-scope exception",
            ),
        )
    else
        entry = findfirst(parsed -> parsed.report.path == scope.package_entry_path, parsed_files)
        if !isnothing(entry)
            parsed = parsed_files[entry]
            module_names = [mod.name for mod in parsed.syntax_facts.modules]
            if !(scope.package_name in module_names)
                push!(
                    findings,
                    finding_from_rule(
                        rules[JULIA_PROJ_R007];
                        summary="`$(scope.package_entry_path)` does not declare module `$(scope.package_name)`.",
                        location=SourceLocation(scope.package_entry_path, 1, 0),
                        source_line=source_line(parsed.source, 1),
                        label="declare the package module in the entry file so Pkg and syntax facts agree",
                    ),
                )
            end
        end
    end
    append!(findings, scope_explanation_findings(scope, config, rules))
    append!(findings, test_entrypoint_findings(scope, rules))
    append!(findings, undeclared_import_findings(scope, parsed_files, rules))
    findings
end

function expected_entry_file(scope::JuliaProjectHarnessScope)
    if !isnothing(scope.project_entryfile)
        return scope.project_entryfile
    end
    isnothing(scope.package_name) ? "src/<PackageName>.jl" : "src/$(scope.package_name).jl"
end

function scope_explanation_findings(
    scope::JuliaProjectHarnessScope,
    config::JuliaHarnessConfig,
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    append!(
        findings,
        custom_scope_explanation_findings(
            scope,
            config.source_dir_names,
            config.source_path_explanations,
            Set(["src"]),
            "source",
            rules,
        ),
    )
    if config.include_tests
        append!(
            findings,
            custom_scope_explanation_findings(
                scope,
                config.test_dir_names,
                config.test_path_explanations,
                Set(["test"]),
                "test",
                rules,
            ),
        )
    end
    append!(
        findings,
        conventional_scope_exclusion_findings(
            scope,
            config.source_dir_names,
            config.source_path_exclusion_explanations,
            "src",
            "source",
            rules,
        ),
    )
    append!(
        findings,
        conventional_scope_exclusion_findings(
            scope,
            config.include_tests ? config.test_dir_names : String[],
            config.test_path_exclusion_explanations,
            "test",
            "test",
            rules,
        ),
    )
    findings
end

function custom_scope_explanation_findings(
    scope::JuliaProjectHarnessScope,
    path_names::Vector{String},
    explanations::Dict{String,String},
    conventional_names::Set{String},
    label::AbstractString,
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    for path_name in path_names
        path_name in conventional_names && continue
        full_path = joinpath(scope.project_root, path_name)
        ispath(full_path) || continue
        has_path_explanation(explanations, scope.project_root, path_name) && continue
        push!(
            findings,
            finding_from_rule(
                rules[JULIA_PROJ_R005];
                summary="Configured $(label) scope `$(path_name)` exists but has no explanation.",
                location=SourceLocation(scope.project_toml_path, 1, 0),
                label="add a non-empty scope explanation or use the conventional Julia path",
            ),
        )
    end
    findings
end

function conventional_scope_exclusion_findings(
    scope::JuliaProjectHarnessScope,
    configured_names::Vector{String},
    explanations::Dict{String,String},
    conventional_name::AbstractString,
    label::AbstractString,
    rules::Dict{String,JuliaHarnessRule},
)
    full_path = joinpath(scope.project_root, conventional_name)
    ispath(full_path) || return JuliaHarnessFinding[]
    conventional_name in configured_names && return JuliaHarnessFinding[]
    has_path_explanation(explanations, scope.project_root, conventional_name) &&
        return JuliaHarnessFinding[]
    [
        finding_from_rule(
            rules[JULIA_PROJ_R006];
            summary="Conventional Julia $(label) scope `$(conventional_name)` exists but is not monitored.",
            location=SourceLocation(scope.project_toml_path, 1, 0),
            label="add a non-empty exclusion explanation or restore the conventional scope",
        ),
    ]
end

function has_path_explanation(
    explanations::Dict{String,String},
    project_root::AbstractString,
    path_name::AbstractString,
)
    full_path = normpath(joinpath(project_root, path_name))
    any(
        key -> !isempty(strip(get(explanations, key, ""))),
        [String(path_name), slash_path(path_name), full_path, slash_path(full_path)],
    )
end

function test_entrypoint_findings(
    scope::JuliaProjectHarnessScope,
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    for test_path in scope.test_paths
        isdir(test_path) || continue
        entrypoint = joinpath(test_path, "runtests.jl")
        isfile(entrypoint) && continue
        push!(
            findings,
            finding_from_rule(
                rules[JULIA_PROJ_R003];
                summary="Test scope `$(test_path)` exists, but `$(entrypoint)` is missing.",
                location=SourceLocation(entrypoint, 1, 0),
                label="add test/runtests.jl so Pkg.test has a stable package test entrypoint",
            ),
        )
    end
    findings
end

function undeclared_import_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    stdlib_roots = julia_stdlib_import_roots()
    for parsed in parsed_files
        parsed.report.is_valid || continue
        allowed = allowed_import_roots(scope, parsed.report.path, stdlib_roots)
        for imported in parsed.syntax_facts.imports
            is_relative_import(imported) && continue
            imported.root in allowed && continue
            push!(
                findings,
                finding_from_rule(
                    rules[JULIA_PROJ_R008];
                    summary="`$(imported.expression)` imports `$(imported.root)`, but `$(imported.root)` is not declared for this project scope.",
                    location=SourceLocation(parsed.report.path, imported.line, imported.column),
                    source_line=source_line(parsed.source, imported.line),
                    label="add the package to Project.toml or make the import relative if it is project-local",
                ),
            )
        end
    end
    findings
end

function allowed_import_roots(
    scope::JuliaProjectHarnessScope,
    path::AbstractString,
    stdlib_roots::Set{String},
)
    allowed = union(
        Set(["Base", "Core", "Main"]),
        stdlib_roots,
        Set(keys(scope.direct_dependencies)),
        Set(keys(scope.weak_dependencies)),
    )
    !isnothing(scope.package_name) && push!(allowed, scope.package_name)
    if is_test_path(scope, path)
        union!(allowed, keys(scope.extra_dependencies))
    end
    allowed
end

function is_relative_import(imported::JuliaImportSyntax)
    expression = strip(imported.expression)
    startswith(expression, "using .") || startswith(expression, "import .")
end

function is_test_path(scope::JuliaProjectHarnessScope, path::AbstractString)
    any(test_path -> is_path_under(path, test_path), scope.test_paths)
end

function julia_stdlib_import_roots()
    roots = Set{String}()
    for (_, info) in Pkg.Types.stdlibs()
        push!(roots, String(info[1]))
    end
    roots
end

function evaluate_modularity_rules(
    scope::Union{Nothing,JuliaProjectHarnessScope},
    parsed_files::Vector{ParsedJuliaFile},
)
    isnothing(scope) && return JuliaHarnessFinding[]
    rules = rules_by_id()
    findings = JuliaHarnessFinding[]
    parsed_by_path = Dict(parsed.report.path => parsed for parsed in parsed_files)
    for parsed in parsed_files
        parsed.report.is_valid || continue
        for include in parsed.syntax_facts.includes
            if !include.is_literal
                push!(
                    findings,
                    finding_from_rule(
                        rules[JULIA_MOD_R003];
                        summary="Parser facts found `$(include.expression)`, whose target is not statically known.",
                        location=SourceLocation(parsed.report.path, include.line, include.column),
                        source_line=source_line(parsed.source, include.line),
                        label="replace dynamic include with a literal include or document the exception",
                    ),
                )
            elseif !isfile(include.resolved_target)
                push!(
                    findings,
                    finding_from_rule(
                        rules[JULIA_MOD_R004];
                        summary="`$(include.expression)` resolves to missing file `$(include.resolved_target)`.",
                        location=SourceLocation(parsed.report.path, include.line, include.column),
                        source_line=source_line(parsed.source, include.line),
                        label="create the included file or update the literal include path",
                    ),
                )
            end
        end
    end
    append!(findings, include_cycle_findings(parsed_by_path, rules))
    append!(findings, orphan_source_findings(scope, parsed_files, parsed_by_path, rules))
    append!(findings, generic_owner_bucket_findings(scope, parsed_files, rules))
    findings
end

function include_cycle_findings(
    parsed_by_path::Dict{String,ParsedJuliaFile},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    states = Dict{String,Symbol}()
    reported_cycles = Set{String}()
    for path in sort!(collect(keys(parsed_by_path)))
        get(states, path, :unseen) == :unseen || continue
        visit_include_graph!(
            findings,
            states,
            reported_cycles,
            String[],
            path,
            parsed_by_path,
            rules,
        )
    end
    findings
end

function visit_include_graph!(
    findings::Vector{JuliaHarnessFinding},
    states::Dict{String,Symbol},
    reported_cycles::Set{String},
    stack::Vector{String},
    path::String,
    parsed_by_path::Dict{String,ParsedJuliaFile},
    rules::Dict{String,JuliaHarnessRule},
)
    states[path] = :visiting
    push!(stack, path)
    parsed = parsed_by_path[path]
    for include in parsed.syntax_facts.includes
        include.is_literal || continue
        target = include.resolved_target
        isnothing(target) && continue
        haskey(parsed_by_path, target) || continue
        target_index = findfirst(==(target), stack)
        if !isnothing(target_index)
            cycle_paths = vcat(stack[target_index:end], [target])
            cycle_key = join(sort(unique(cycle_paths)), "\0")
            if !(cycle_key in reported_cycles)
                push!(reported_cycles, cycle_key)
                push!(
                    findings,
                    finding_from_rule(
                        rules[JULIA_MOD_R005];
                        summary="Literal include cycle detected: $(join(cycle_paths, " -> ")).",
                        location=SourceLocation(parsed.report.path, include.line, include.column),
                        source_line=source_line(parsed.source, include.line),
                        label="break the include cycle by moving shared declarations behind one acyclic owner",
                    ),
                )
            end
            continue
        end
        get(states, target, :unseen) == :unseen || continue
        visit_include_graph!(findings, states, reported_cycles, stack, target, parsed_by_path, rules)
    end
    pop!(stack)
    states[path] = :visited
end

function orphan_source_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    parsed_by_path::Dict{String,ParsedJuliaFile},
    rules::Dict{String,JuliaHarnessRule},
)
    isnothing(scope.package_entry_path) && return JuliaHarnessFinding[]
    source_files = Set(
        parsed.report.path for parsed in parsed_files if any(
            source_path -> is_path_under(parsed.report.path, source_path),
            scope.source_paths,
        )
    )
    reachable = reachable_source_files(scope.package_entry_path, parsed_by_path)
    orphaned = sort!(collect(setdiff(source_files, reachable)))
    findings = JuliaHarnessFinding[]
    for path in orphaned
        push!(
            findings,
            finding_from_rule(
                rules[JULIA_MOD_R006];
                summary="`$(path)` is under `src/` but is not reachable from `$(scope.package_entry_path)` through literal includes.",
                location=SourceLocation(path, 1, 0),
                source_line=source_line(parsed_by_path[path].source, 1),
                label="include this source from the package entry graph or document why it is intentionally separate",
            ),
        )
    end
    findings
end

function reachable_source_files(entry_path::String, parsed_by_path::Dict{String,ParsedJuliaFile})
    reachable = Set{String}()
    pending = [entry_path]
    while !isempty(pending)
        path = pop!(pending)
        path in reachable && continue
        push!(reachable, path)
        parsed = get(parsed_by_path, path, nothing)
        isnothing(parsed) && continue
        for include in parsed.syntax_facts.includes
            include.is_literal || continue
            isnothing(include.resolved_target) && continue
            include.resolved_target in reachable && continue
            haskey(parsed_by_path, include.resolved_target) && push!(pending, include.resolved_target)
        end
    end
    reachable
end

function is_path_under(path::AbstractString, root::AbstractString)
    relative = relpath(path, root)
    relative == "." || (!startswith(relative, "..") && !isabspath(relative))
end

function generic_owner_bucket_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        source_root = first_source_root(scope, parsed.report.path)
        isnothing(source_root) && continue
        generic_segment = first_generic_owner_segment(source_root, parsed.report.path)
        isnothing(generic_segment) && continue
        push!(
            findings,
            finding_from_rule(
                rules[JULIA_MOD_R007];
                summary="`$(parsed.report.path)` is under generic source owner `$(generic_segment)`.",
                location=SourceLocation(parsed.report.path, 1, 0),
                source_line=source_line(parsed.source, 1),
                label="rename the source directory to the domain owner it represents",
            ),
        )
    end
    findings
end

function first_source_root(scope::JuliaProjectHarnessScope, path::AbstractString)
    for source_path in scope.source_paths
        is_path_under(path, source_path) && return source_path
    end
    nothing
end

function first_generic_owner_segment(source_root::AbstractString, path::AbstractString)
    relative = relpath(dirname(path), source_root)
    relative == "." && return nothing
    for segment in splitpath(relative)
        normalized = lowercase(String(segment))
        normalized in GENERIC_SOURCE_OWNER_SEGMENTS && return segment
    end
    nothing
end

function evaluate_default_rule_packs(
    scope::Union{Nothing,JuliaProjectHarnessScope},
    parsed_files::Vector{ParsedJuliaFile},
    config::JuliaHarnessConfig,
)
    findings = vcat(
        evaluate_syntax_rules(parsed_files),
        evaluate_project_policy_rules(scope, parsed_files, config),
        evaluate_modularity_rules(scope, parsed_files),
        evaluate_agent_policy_rules(scope, parsed_files),
    )
    apply_config_to_findings(findings, config)
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
            length(function_fact.positional_args) >= 5 || continue
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
