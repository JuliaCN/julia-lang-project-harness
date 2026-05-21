const JULIA_EXAMPLE_ENTRY_CANDIDATES = [
    "runexamples.jl",
    "runtests.jl",
    "examples.jl",
]

function example_verification_tasks(scope::JuliaProjectHarnessScope)
    examples_root = joinpath(scope.project_root, "examples")
    isfile(joinpath(examples_root, "Project.toml")) || return JuliaVerificationTaskRecord[]
    entry_path = example_entry_path(examples_root)
    isnothing(entry_path) && return JuliaVerificationTaskRecord[]
    [example_verification_task(scope, examples_root, entry_path)]
end

function example_entry_path(examples_root::AbstractString)
    for entry_name in JULIA_EXAMPLE_ENTRY_CANDIDATES
        candidate = joinpath(examples_root, entry_name)
        isfile(candidate) && return candidate
    end
    nothing
end

function example_verification_task(
    scope::JuliaProjectHarnessScope,
    examples_root::AbstractString,
    entry_path::AbstractString,
)
    command = example_verification_command(scope, examples_root, entry_path)
    JuliaVerificationTaskRecord(
        verification_fingerprint(
            "example_run",
            verification_scope_fingerprint(scope),
            verification_owner_fingerprint_part(scope, entry_path),
        ),
        "example_run",
        "pending",
        "after_unit_tests_pass",
        scope.project_root,
        entry_path,
        nothing,
        command,
        example_verification_evidence(scope, examples_root, entry_path, command),
        "Run the package-owned Julia examples project so agent edits keep documented usage executable.",
    )
end

function example_verification_command(
    scope::JuliaProjectHarnessScope,
    examples_root::AbstractString,
    entry_path::AbstractString,
)
    relative_entry = verification_owner_fingerprint_part(scope, entry_path)
    [
        "julia",
        "--project=$(examples_root)",
        "-e",
        "cd($(repr(scope.project_root))) do; include($(repr(relative_entry))); end",
    ]
end

function example_verification_evidence(
    scope::JuliaProjectHarnessScope,
    examples_root::AbstractString,
    entry_path::AbstractString,
    command::Vector{String},
)
    verification_evidence(
        "package" => something(scope.package_name, "<unnamed>"),
        "example_project" => verification_owner_fingerprint_part(
            scope,
            joinpath(examples_root, "Project.toml"),
        ),
        "entry" => verification_owner_fingerprint_part(scope, entry_path),
        "activation" => "examples_project",
        "example_command" => join(shell_quote_arg.(command), " "),
    )
end
