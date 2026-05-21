const MOSHI_DOMAIN_BRANCH_THRESHOLD = 2

function moshi_domain_model_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    rules::Dict{String,JuliaHarnessRule},
)
    moshi_modeling_surface_exists(scope, parsed_files) && return JuliaHarnessFinding[]
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        parsed.report.is_valid || continue
        is_test_path(scope, parsed.report.path) && continue
        for function_fact in parsed.syntax_facts.functions
            function_fact.terminal_name in public_names || continue
            is_stringly_branch_dispatch(function_fact) || continue
            push!(
                findings,
                finding_from_rule(
                    rules[AGENT_JL_R020];
                    summary=moshi_domain_model_summary(scope, function_fact),
                    location=SourceLocation(
                        parsed.report.path,
                        function_fact.line,
                        function_fact.column,
                    ),
                    source_line=source_line(parsed.source, function_fact.line),
                    label=moshi_domain_model_label(scope),
                    extra_labels=moshi_domain_model_labels(scope),
                ),
            )
        end
    end
    findings
end

function moshi_modeling_surface_exists(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
)
    any(parsed -> any(is_moshi_modeling_fact, parsed.syntax_facts.moshi), parsed_files) &&
        return true
    has_moshi_optional_extension(scope)
end

function is_moshi_modeling_fact(fact::JuliaMoshiSyntax)
    fact.kind in ("data", "match")
end

function has_moshi_optional_extension(scope::JuliaProjectHarnessScope)
    haskey(scope.weak_dependencies, "Moshi") || return false
    any(dependencies -> "Moshi" in dependencies, values(scope.extensions))
end

function is_stringly_branch_dispatch(function_fact::JuliaFunctionSyntax)
    !isempty(function_fact.stringly_domain_args) &&
        function_fact.branch_count >= MOSHI_DOMAIN_BRANCH_THRESHOLD
end

function moshi_domain_model_summary(
    scope::JuliaProjectHarnessScope,
    function_fact::JuliaFunctionSyntax,
)
    "Exported/public method `$(function_fact.terminal_name)` branches over stringly domain arguments: $(join(function_fact.stringly_domain_args, ", ")). Prefer a typed domain carrier. $(moshi_domain_model_repair_path(scope))"
end

function moshi_domain_model_label(scope::JuliaProjectHarnessScope)
    state = moshi_extension_repair_state(scope)
    state == "weakdep_without_extension" &&
        return "add `$(moshi_extension_repair_target(scope))` and model this domain with Moshi @data/@match"
    state == "direct_dep_without_extension" &&
        return "move Moshi behind weakdeps/extensions or document why it is core API"
    "model the domain with a package-owned value type, or add a Moshi weakdep extension first"
end

function moshi_domain_model_repair_path(scope::JuliaProjectHarnessScope)
    state = moshi_extension_repair_state(scope)
    if state == "weakdep_without_extension"
        return "Moshi is already a weak dependency; add an `[extensions]` entry such as `$(moshi_extension_repair_name(scope))` and place the ADT/pattern-match surface in `$(moshi_extension_repair_target(scope))`."
    elseif state == "direct_dep_without_extension"
        return "Moshi is a direct dependency; keep it only if it is core API, otherwise move the modeling surface behind `[weakdeps]` and `[extensions]`."
    end
    "If Moshi is chosen, add it through `[weakdeps]`, `[compat]`, and `[extensions]`; otherwise use a package-owned enum, Symbol, or value type."
end

function moshi_domain_model_labels(scope::JuliaProjectHarnessScope)
    Dict(
        "capability_source" => "Moshi",
        "capabilities" => join(moshi_extension_capability_names(), ","),
        "moshi_extension_state" => moshi_extension_repair_state(scope),
        "moshi_extension_target" => moshi_extension_repair_target(scope),
    )
end

function moshi_extension_repair_state(scope::JuliaProjectHarnessScope)
    has_moshi_optional_extension(scope) && return "configured"
    haskey(scope.weak_dependencies, "Moshi") && return "weakdep_without_extension"
    haskey(scope.direct_dependencies, "Moshi") && return "direct_dep_without_extension"
    "missing_weakdep"
end

function moshi_extension_repair_name(scope::JuliaProjectHarnessScope)
    "$(something(scope.package_name, "<PackageName>"))MoshiExt"
end

function moshi_extension_repair_target(scope::JuliaProjectHarnessScope)
    "ext/$(moshi_extension_repair_name(scope)).jl"
end
