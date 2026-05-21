function extension_verification_tasks(scope::JuliaProjectHarnessScope)
    records = JuliaVerificationTaskRecord[]
    for (extension_name, dependencies) in sort(collect(scope.extensions); by=first)
        owner_path = extension_owner_path(scope, extension_name)
        activation = extension_activation_state(scope, dependencies)
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
                extension_activation_command(scope, activation),
                verification_evidence(
                    "extension" => extension_name,
                    "weakdeps" => join(dependencies, ","),
                    "activation" => activation,
                    "test_target" => extension_test_target_summary(scope),
                ),
                extension_boundary_reason(activation),
            ),
        )
    end
    records
end

function extension_activation_state(
    scope::JuliaProjectHarnessScope,
    dependencies::Vector{String},
)
    test_roots = test_target_import_roots(scope)
    all(dependency -> dependency in test_roots, dependencies) && return "test_target"
    "missing_test_target"
end

function extension_activation_command(scope::JuliaProjectHarnessScope, activation::AbstractString)
    activation == "test_target" &&
        return ["julia", "--project=$(scope.project_root)", "-e", "using Pkg; Pkg.test()"]
    String[]
end

function extension_test_target_summary(scope::JuliaProjectHarnessScope)
    join(sort!(collect(test_target_import_roots(scope))), ",")
end

function extension_boundary_reason(activation::AbstractString)
    activation == "test_target" &&
        return "Run package tests with extension weakdeps activated through the test target."
    "Agent should add or run an extension activation test path for these weakdeps before treating the package test gate as complete."
end
