const JULIA_BENCHMARK_ENTRY_CANDIDATES = [
    ("benchmark", ["runbenchmarks.jl", "benchmarks.jl", "runtests.jl"]),
    ("benchmarks", ["runbenchmarks.jl", "benchmarks.jl", "runtests.jl"]),
    ("perf", ["runtests.jl", "runbenchmarks.jl", "benchmarks.jl"]),
    (joinpath("test", "perf"), ["runtests.jl", "runbenchmarks.jl", "benchmarks.jl"]),
]

function benchmark_verification_tasks(scope::JuliaProjectHarnessScope)
    records = JuliaVerificationTaskRecord[]
    for (relative_root, entry_names) in JULIA_BENCHMARK_ENTRY_CANDIDATES
        benchmark_root = joinpath(scope.project_root, relative_root)
        isdir(benchmark_root) || continue
        for entry_name in entry_names
            entry_path = joinpath(benchmark_root, entry_name)
            isfile(entry_path) || continue
            push!(records, benchmark_verification_task(scope, benchmark_root, entry_path))
            break
        end
    end
    records
end

function benchmark_verification_task(
    scope::JuliaProjectHarnessScope,
    benchmark_root::AbstractString,
    entry_path::AbstractString,
)
    command = benchmark_verification_command(scope, benchmark_root, entry_path)
    JuliaVerificationTaskRecord(
        verification_fingerprint(
            "performance",
            verification_scope_fingerprint(scope),
            verification_owner_fingerprint_part(scope, entry_path),
        ),
        "performance",
        "pending",
        "after_unit_tests_pass",
        scope.project_root,
        entry_path,
        nothing,
        command,
        benchmark_verification_evidence(scope, benchmark_root, entry_path, command),
        "Run the project-owned Julia benchmark or strict performance gate before treating latency-sensitive changes as verified.",
    )
end

function benchmark_verification_command(
    scope::JuliaProjectHarnessScope,
    benchmark_root::AbstractString,
    entry_path::AbstractString,
)
    activation_root = benchmark_activation_root(scope, benchmark_root)
    relative_entry = verification_owner_fingerprint_part(scope, entry_path)
    [
        "julia",
        "--project=$(activation_root)",
        "-e",
        "cd($(repr(scope.project_root))) do; include($(repr(relative_entry))); end",
    ]
end

function benchmark_activation_root(
    scope::JuliaProjectHarnessScope,
    benchmark_root::AbstractString,
)
    isfile(joinpath(benchmark_root, "Project.toml")) && return String(benchmark_root)
    scope.project_root
end

function benchmark_verification_evidence(
    scope::JuliaProjectHarnessScope,
    benchmark_root::AbstractString,
    entry_path::AbstractString,
    command::Vector{String},
)
    activation_root = benchmark_activation_root(scope, benchmark_root)
    verification_evidence(
        "package" => something(scope.package_name, "<unnamed>"),
        "benchmark_project" => benchmark_project_evidence(scope, activation_root),
        "entry" => verification_owner_fingerprint_part(scope, entry_path),
        "activation" => benchmark_activation_evidence(scope, activation_root),
        "benchmark_command" => join(shell_quote_arg.(command), " "),
    )
end

function benchmark_project_evidence(
    scope::JuliaProjectHarnessScope,
    activation_root::AbstractString,
)
    normpath(activation_root) == normpath(scope.project_root) && return "root"
    project_path = joinpath(activation_root, "Project.toml")
    verification_owner_fingerprint_part(scope, project_path)
end

function benchmark_activation_evidence(
    scope::JuliaProjectHarnessScope,
    activation_root::AbstractString,
)
    normpath(activation_root) == normpath(scope.project_root) && return "root_project"
    "local_project"
end
