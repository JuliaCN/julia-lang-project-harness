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
                    summary=moshi_domain_model_summary(function_fact),
                    location=SourceLocation(
                        parsed.report.path,
                        function_fact.line,
                        function_fact.column,
                    ),
                    source_line=source_line(parsed.source, function_fact.line),
                    label="model the domain with a typed carrier, or make Moshi an optional extension",
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

function moshi_domain_model_summary(function_fact::JuliaFunctionSyntax)
    "Exported/public method `$(function_fact.terminal_name)` branches over stringly domain arguments: $(join(function_fact.stringly_domain_args, ", ")). Prefer a typed domain carrier; Moshi `@data`/`@match` is optional and should stay behind `[weakdeps]`/`[extensions]` when it is not required by core API."
end
