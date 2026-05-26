function moshi_policy_labels(
    scope::JuliaProjectHarnessScope,
    application,
    repair_target::AbstractString,
)
    labels = Dict(
        "capability_source" => "Moshi",
        "configured_policy" => "enable",
        "moshi_extension_state" => moshi_extension_repair_state(scope),
        "moshi_repair_shape" => moshi_source_repair_shape(scope; repair_target),
        "moshi_repair_target" => repair_target,
    )
    isnothing(application) && return labels

    labels["moshi_nearest_application_path"] = repair_target
    labels["moshi_nearest_application_line"] = string(application.line)
    labels["moshi_nearest_application_function"] = application.function_name
    labels["moshi_nearest_application_args"] = join(application.domain_args, ",")
    labels["moshi_nearest_application_literals"] = join(application.branch_literals, ",")
    labels
end

function moshi_nearest_application(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
)
    candidates = []
    for parsed in parsed_files
        parsed.report.is_valid || continue
        is_test_path(scope, parsed.report.path) && continue
        for function_fact in parsed.syntax_facts.functions
            is_stringly_branch_dispatch(function_fact) || continue
            push!(
                candidates,
                (
                    path = parsed.report.path,
                    line = function_fact.line,
                    function_name = function_fact.terminal_name,
                    domain_args = function_fact.stringly_domain_args,
                    branch_literals = function_fact.stringly_branch_literals,
                    branch_count = function_fact.branch_count,
                ),
            )
        end
    end
    isempty(candidates) && return nothing
    first(sort(candidates; by = moshi_application_rank_key))
end

function moshi_application_rank_key(application)
    (
        -length(application.branch_literals),
        -application.branch_count,
        application.path,
        application.line,
        application.function_name,
    )
end
