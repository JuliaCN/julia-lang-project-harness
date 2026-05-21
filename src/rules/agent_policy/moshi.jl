const MOSHI_DOMAIN_BRANCH_THRESHOLD = 2

function moshi_domain_model_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    rules::Dict{String,JuliaHarnessRule},
)
    modeling_facts = moshi_modeling_facts(parsed_files)
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        parsed.report.is_valid || continue
        is_test_path(scope, parsed.report.path) && continue
        for function_fact in parsed.syntax_facts.functions
            function_fact.terminal_name in public_names || continue
            is_stringly_branch_dispatch(function_fact) || continue
            moshi_domain_model_satisfied(function_fact, modeling_facts) && continue
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
                    extra_labels=moshi_domain_model_labels(
                        scope,
                        function_fact,
                        modeling_facts,
                    ),
                ),
            )
        end
    end
    findings
end

function moshi_modeling_facts(parsed_files::Vector{ParsedJuliaFile})
    [
        fact for parsed in parsed_files for fact in parsed.syntax_facts.moshi if
        is_moshi_modeling_fact(fact)
    ]
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

function moshi_domain_model_satisfied(
    function_fact::JuliaFunctionSyntax,
    modeling_facts::Vector{JuliaMoshiSyntax},
)
    isempty(modeling_facts) && return false
    isempty(function_fact.stringly_branch_literals) && return true
    literal_tokens = normalized_domain_tokens(function_fact.stringly_branch_literals)
    isempty(literal_tokens) && return true
    modeled_tokens = moshi_modeling_tokens(modeling_facts)
    !isempty(modeled_tokens) && all(token -> token in modeled_tokens, literal_tokens)
end

function moshi_domain_model_summary(
    scope::JuliaProjectHarnessScope,
    function_fact::JuliaFunctionSyntax,
)
    literal_suffix = isempty(function_fact.stringly_branch_literals) ? "" :
                     " Branch literals: $(join(function_fact.stringly_branch_literals, ", "))."
    "Exported/public method `$(function_fact.terminal_name)` branches over stringly domain arguments: $(join(function_fact.stringly_domain_args, ", ")).$(literal_suffix) Prefer a typed domain carrier. $(moshi_domain_model_repair_path(scope))"
end

function moshi_domain_model_label(scope::JuliaProjectHarnessScope)
    state = moshi_extension_repair_state(scope)
    state == "extension_without_model" &&
        return "add Moshi @data/@match domain modeling in `$(moshi_extension_repair_target(scope))`"
    state == "weakdep_without_extension" &&
        return "add `$(moshi_extension_repair_target(scope))` and model this domain with Moshi @data/@match"
    state == "direct_dep_without_extension" &&
        return "move Moshi behind weakdeps/extensions or document why it is core API"
    "model the domain with a package-owned value type, or add a Moshi weakdep extension first"
end

function moshi_domain_model_repair_path(scope::JuliaProjectHarnessScope)
    state = moshi_extension_repair_state(scope)
    if state == "extension_without_model"
        return "Moshi is already configured as an optional extension; add parser-visible `@data` variants that cover the branch literals, plus a `@match` branch surface in `$(moshi_extension_repair_target(scope))` instead of treating the config as the model."
    elseif state == "weakdep_without_extension"
        return "Moshi is already a weak dependency; add an `[extensions]` entry such as `$(moshi_extension_repair_name(scope))` and place the ADT/pattern-match surface in `$(moshi_extension_repair_target(scope))`."
    elseif state == "direct_dep_without_extension"
        return "Moshi is a direct dependency; keep it only if it is core API, otherwise move the modeling surface behind `[weakdeps]` and `[extensions]`."
    end
    "If Moshi is chosen, add it through `[weakdeps]`, `[compat]`, and `[extensions]`; otherwise use a package-owned enum, Symbol, or value type."
end

function moshi_domain_model_labels(
    scope::JuliaProjectHarnessScope,
    function_fact::JuliaFunctionSyntax,
    modeling_facts::Vector{JuliaMoshiSyntax},
)
    labels = Dict(
        "capability_source" => "Moshi",
        "capabilities" => join(moshi_extension_capability_names(), ","),
        "moshi_extension_state" => moshi_extension_repair_state(scope),
        "moshi_extension_target" => moshi_extension_repair_target(scope),
    )
    if !isempty(function_fact.stringly_branch_literals)
        labels["stringly_branch_literals"] = join(function_fact.stringly_branch_literals, ",")
        labels["moshi_model_coverage"] = moshi_model_coverage_label(
            function_fact,
            modeling_facts,
        )
    end
    labels
end

function moshi_model_coverage_label(
    function_fact::JuliaFunctionSyntax,
    modeling_facts::Vector{JuliaMoshiSyntax},
)
    isempty(modeling_facts) && return "missing_model"
    literal_tokens = normalized_domain_tokens(function_fact.stringly_branch_literals)
    modeled_tokens = moshi_modeling_tokens(modeling_facts)
    missing = [token for token in literal_tokens if !(token in modeled_tokens)]
    isempty(missing) ? "covered" : "missing=$(join(missing, ","))"
end

function moshi_modeling_tokens(modeling_facts::Vector{JuliaMoshiSyntax})
    tokens = Set{String}()
    for fact in modeling_facts
        for variant_name in fact.variant_names
            token = normalized_domain_token(variant_name)
            isempty(token) && continue
            push!(tokens, token)
        end
    end
    tokens
end

function normalized_domain_tokens(values::Vector{String})
    tokens = String[]
    seen = Set{String}()
    for value in values
        token = normalized_domain_token(value)
        isempty(token) && continue
        token in seen && continue
        push!(seen, token)
        push!(tokens, token)
    end
    tokens
end

function normalized_domain_token(value::AbstractString)
    buffer = IOBuffer()
    for character in value
        if isletter(character) || isdigit(character)
            print(buffer, lowercase(character))
        end
    end
    String(take!(buffer))
end

function moshi_extension_repair_state(scope::JuliaProjectHarnessScope)
    has_moshi_optional_extension(scope) && return "extension_without_model"
    haskey(scope.weak_dependencies, "Moshi") && return "weakdep_without_extension"
    haskey(scope.direct_dependencies, "Moshi") && return "direct_dep_without_extension"
    "missing_weakdep"
end

function moshi_extension_repair_name(scope::JuliaProjectHarnessScope)
    entries = moshi_optional_extension_entries(scope)
    !isempty(entries) && return first(first(entries))
    "$(something(scope.package_name, "<PackageName>"))MoshiExt"
end

function moshi_extension_repair_target(scope::JuliaProjectHarnessScope)
    "ext/$(moshi_extension_repair_name(scope)).jl"
end
