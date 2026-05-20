"""Build agent-runnable verification tasks for a Julia project root."""
function build_julia_verification_task_index(
    project_root::AbstractString;
    config=default_julia_harness_config(),
)
    scope = julia_project_harness_scope(project_root, config)
    workspace_scopes = julia_workspace_member_scopes(scope, config)
    records = JuliaVerificationTaskRecord[]
    for task_scope in vcat([scope], workspace_scopes)
        parsed_files = parsed_julia_files_for_scope(task_scope, config)
        append!(records, verification_task_records_for_scope(task_scope, config, parsed_files))
    end
    sort!(records; by=record -> (record.kind, record.owner_path, record.fingerprint))
    JuliaVerificationTaskIndex(scope.project_root, records)
end

"""Build the in-test verification profile that agents should keep green."""
function build_julia_project_verification_profile(
    project_root::AbstractString=pwd();
    config=default_julia_harness_config(),
)
    report = run_julia_project_harness(project_root; config)
    task_index = build_julia_verification_task_index(project_root; config)
    profile_index = build_julia_verification_profile_index(project_root; config)
    JuliaVerificationProfile(report, task_index, profile_index)
end

"""Assert the package's JuliaSyntax policy and verification profile from Pkg.test."""
function assert_julia_project_harness_test_profile_clean(
    project_root::AbstractString=pwd();
    config=default_julia_harness_config(),
)
    profile = build_julia_project_verification_profile(project_root; config)
    has_blocking = !is_clean(profile.report)
    has_advice = !has_agent_advice_allow_explanation(config) &&
                 !isempty(advisory_findings(profile.report))
    if has_blocking || has_advice
        error(render_julia_verification_profile(profile))
    end
    profile
end

function verification_task_records_for_scope(
    scope::JuliaProjectHarnessScope,
    config::JuliaHarnessConfig,
    parsed_files::Vector{ParsedJuliaFile}=parsed_julia_files_for_scope(scope, config),
)
    records = JuliaVerificationTaskRecord[]
    push!(records, pkg_test_verification_task(scope))
    if has_harness_dependency(scope)
        push!(records, harness_self_policy_verification_task(scope))
        push!(records, syntax_search_verification_task(scope))
    end
    append!(records, inferred_verification_task_records(scope, parsed_files))
    append!(records, extension_verification_tasks(scope))
    filter(!isnothing, records)
end

function parsed_julia_files_for_scope(scope::JuliaProjectHarnessScope, config::JuliaHarnessConfig)
    [
        parse_julia_file(path) for path in discover_julia_files(
            scope_monitored_paths(scope),
            config,
        )
    ]
end

function pkg_test_verification_task(scope::JuliaProjectHarnessScope)
    owner_path = preferred_test_owner_path(scope)
    JuliaVerificationTaskRecord(
        verification_fingerprint(
            "pkg_test",
            verification_scope_fingerprint(scope),
            verification_owner_fingerprint_part(scope, owner_path),
        ),
        "pkg_test",
        "pending",
        "after_unit_tests_pass",
        scope.project_root,
        owner_path,
        nothing,
        ["julia", "--project=$(scope.project_root)", "-e", "using Pkg; Pkg.test()"],
        verification_evidence(
            "package" => something(scope.package_name, "<unnamed>"),
            "targets" => verification_targets_summary(scope),
            "tests" => string(length(scope.test_paths)),
        ),
        "Run the Julia package test gate from the Project.toml root.",
    )
end

function harness_self_policy_verification_task(scope::JuliaProjectHarnessScope)
    owner_path = preferred_test_owner_path(scope)
    JuliaVerificationTaskRecord(
        verification_fingerprint(
            "harness_policy",
            verification_scope_fingerprint(scope),
            verification_owner_fingerprint_part(scope, owner_path),
        ),
        "harness_policy",
        "pending",
        "after_unit_tests_pass",
        scope.project_root,
        owner_path,
        nothing,
        [
            "julia",
            "--project=$(scope.project_root)",
            "-e",
            "using JuliaLangProjectHarness; assert_julia_project_harness_test_profile_clean(pwd())",
        ],
        verification_evidence(
            "package" => something(scope.package_name, "<unnamed>"),
            "dependency" => "JuliaLangProjectHarness",
            "profile" => "test",
        ),
        "Run the in-test harness verification profile that agents should keep green.",
    )
end

function syntax_search_verification_task(scope::JuliaProjectHarnessScope)
    owner_path = preferred_source_owner_path(scope)
    JuliaVerificationTaskRecord(
        verification_fingerprint(
            "syntax_search",
            verification_scope_fingerprint(scope),
            verification_owner_fingerprint_part(scope, owner_path),
        ),
        "syntax_search",
        "pending",
        "after_unit_tests_pass",
        scope.project_root,
        owner_path,
        nothing,
        [
            "julia",
            "--project=$(scope.project_root)",
            "-e",
            "using JuliaLangProjectHarness; julia_project_search_index(pwd())",
        ],
        verification_evidence(
            "sources" => string(length(scope.source_paths)),
            "extensions" => string(length(scope.extension_paths)),
        ),
        "Smoke the JuliaSyntax-derived search index for agent context selection.",
    )
end

function extension_verification_tasks(scope::JuliaProjectHarnessScope)
    records = JuliaVerificationTaskRecord[]
    for (extension_name, dependencies) in sort(collect(scope.extensions); by=first)
        owner_path = extension_owner_path(scope, extension_name)
        push!(
            records,
            JuliaVerificationTaskRecord(
                verification_fingerprint(
                    "extension",
                    verification_scope_fingerprint(scope),
                    verification_owner_fingerprint_part(scope, owner_path),
                ),
                "extension_boundary",
                "pending",
                "after_unit_tests_pass",
                scope.project_root,
                owner_path,
                nothing,
                ["julia", "--project=$(scope.project_root)", "-e", "using Pkg; Pkg.test()"],
                verification_evidence(
                    "extension" => extension_name,
                    "weakdeps" => join(dependencies, ","),
                ),
                "Run package tests with extension dependency boundaries in scope.",
            ),
        )
    end
    records
end

const JULIA_AGENT_VERIFICATION_TASK_KINDS = Set([
    "chaos",
    "performance",
    "security",
    "stress",
])

function inferred_verification_task_records(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
)
    candidate = project_responsibility_profile_candidate(scope, parsed_files)
    isnothing(candidate) && return JuliaVerificationTaskRecord[]
    [
        inferred_verification_task_record(scope, candidate, task_kind) for
        task_kind in candidate.task_kinds if task_kind in JULIA_AGENT_VERIFICATION_TASK_KINDS
    ]
end

function inferred_verification_task_record(
    scope::JuliaProjectHarnessScope,
    candidate::JuliaVerificationProfileCandidate,
    task_kind::AbstractString,
)
    evidence = copy(candidate.evidence)
    evidence["responsibilities"] = join(candidate.responsibilities, ",")
    JuliaVerificationTaskRecord(
        verification_fingerprint(
            String(task_kind),
            verification_scope_fingerprint(scope),
            verification_owner_fingerprint_part(scope, candidate.owner_path),
            join(candidate.responsibilities, ","),
        ),
        String(task_kind),
        "pending",
        inferred_verification_task_phase(task_kind),
        scope.project_root,
        candidate.owner_path,
        nothing,
        String[],
        evidence,
        inferred_verification_task_reason(task_kind),
    )
end

function inferred_verification_task_phase(task_kind::AbstractString)
    task_kind in ("stress", "performance") && return "after_unit_tests_pass"
    task_kind in ("chaos", "security") && return "before_release"
    "after_unit_tests_pass"
end

function inferred_verification_task_reason(task_kind::AbstractString)
    task_kind == "stress" &&
        return "Agent should add or run stress-style validation for this public Julia API surface."
    task_kind == "performance" &&
        return "Agent should add or run Julia-native performance evidence for this latency-sensitive owner."
    task_kind == "chaos" &&
        return "Agent should add or run dependency, persistence, or availability failure-mode verification."
    task_kind == "security" &&
        return "Agent should add or run security-boundary verification for this owner."
    "Agent should add or run verification evidence for this inferred responsibility."
end

function has_harness_dependency(scope::JuliaProjectHarnessScope)
    scope.package_name == "JuliaLangProjectHarness" ||
        haskey(scope.direct_dependencies, "JuliaLangProjectHarness") ||
        haskey(scope.extra_dependencies, "JuliaLangProjectHarness")
end

function preferred_test_owner_path(scope::JuliaProjectHarnessScope)
    runtests = joinpath(scope.project_root, "test", "runtests.jl")
    isfile(runtests) && return runtests
    !isempty(scope.test_paths) && return first(sort(scope.test_paths))
    something(scope.project_toml_path, scope.project_root)
end

function preferred_source_owner_path(scope::JuliaProjectHarnessScope)
    !isnothing(scope.package_entry_path) && return scope.package_entry_path
    !isempty(scope.source_paths) && return first(sort(scope.source_paths))
    something(scope.project_toml_path, scope.project_root)
end

function extension_owner_path(scope::JuliaProjectHarnessScope, extension_name::AbstractString)
    for root in scope.extension_paths
        candidate = joinpath(root, "$(extension_name).jl")
        isfile(candidate) && return candidate
    end
    joinpath(scope.project_root, "ext", "$(extension_name).jl")
end

function verification_targets_summary(scope::JuliaProjectHarnessScope)
    isempty(scope.targets) && return ""
    parts = ["$(name)=$(join(values, ","))" for (name, values) in sort(collect(scope.targets); by=first)]
    join(parts, ";")
end

function verification_evidence(pairs::Pair{String,String}...)
    Dict(key => value for (key, value) in pairs if !isempty(value))
end

function verification_fingerprint(parts::AbstractString...)
    join((compact_fingerprint_part(part) for part in parts), ":")
end

function verification_scope_fingerprint(scope::JuliaProjectHarnessScope)
    !isnothing(scope.package_uuid) && return scope.package_uuid
    !isnothing(scope.package_name) && return scope.package_name
    basename(scope.project_root)
end

function verification_owner_fingerprint_part(
    scope::JuliaProjectHarnessScope,
    owner_path::AbstractString,
)
    relative_path = relpath(owner_path, scope.project_root)
    parts = splitpath(relative_path)
    if !isabspath(relative_path) && (isempty(parts) || first(parts) != "..")
        return slash_path(relative_path)
    end
    slash_path(owner_path)
end

function compact_fingerprint_part(part::AbstractString)
    replace(slash_path(part), r"[^A-Za-z0-9_.=-]+" => "_")
end

"""Render verification tasks as compact text for agent execution."""
function render_julia_verification_task_index(index::JuliaVerificationTaskIndex)
    isempty(index.records) && return "[ok] julia verification tasks no-records\n"
    lines = ["VerificationTasks: count=$(length(index.records))"]
    for record in index.records
        push!(
            lines,
            "- kind=$(record.kind) state=$(record.state) phase=$(record.phase) owner=" *
            verification_owner_path(index, record),
        )
        push!(lines, "  fingerprint=$(record.fingerprint)")
        if !isempty(record.command)
            command = join(shell_quote_arg.(record.command), " ")
            push!(lines, "  command=$(command)")
        end
        if !isempty(record.evidence)
            evidence = [
                "$(key)=$(value)" for (key, value) in sort(collect(record.evidence); by=first)
            ]
            compact_evidence = join(evidence, ";")
            push!(lines, "  evidence=$(compact_evidence)")
        end
        push!(lines, "  reason=$(record.reason)")
    end
    join(lines, "\n") * "\n"
end

function shell_quote_arg(arg::AbstractString)
    text = String(arg)
    occursin(r"[\s;'\"$`\\]", text) || return text
    "'$(replace(text, "'" => "'\\''"))'"
end

"""Render verification tasks as JSON while preserving raw argv vectors."""
function render_julia_verification_task_index_json(index::JuliaVerificationTaskIndex)
    JSON3.write(verification_task_index_dict(index))
end

function verification_task_index_dict(index::JuliaVerificationTaskIndex)
    Dict(
        "project_root" => slash_path(index.project_root),
        "records" => map(verification_task_record_dict, index.records),
    )
end

function verification_task_record_dict(record::JuliaVerificationTaskRecord)
    Dict(
        "fingerprint" => record.fingerprint,
        "kind" => record.kind,
        "state" => record.state,
        "phase" => record.phase,
        "project_root" => slash_path(record.project_root),
        "owner_path" => slash_path(record.owner_path),
        "line" => record.line,
        "command" => record.command,
        "evidence" => record.evidence,
        "reason" => record.reason,
    )
end

function verification_owner_path(
    index::JuliaVerificationTaskIndex,
    record::JuliaVerificationTaskRecord,
)
    relative_path = relpath(record.owner_path, index.project_root)
    parts = splitpath(relative_path)
    if !isabspath(relative_path) && (isempty(parts) || first(parts) != "..")
        return slash_path(relative_path)
    end
    slash_path(record.owner_path)
end
