const EXTENSION_PATTERN_DOC_TOKENS = (
    "dispatch",
    "extension",
    "extensions",
    "fallback",
    "fallbacks",
    "method family",
    "overload",
    "overloads",
)

function public_method_family_scattering_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    function_docs_by_name::Dict{String,Vector{String}},
    rules::Dict{String,JuliaHarnessRule},
)
    records = public_api_definition_records(parsed_files, public_names)
    findings = JuliaHarnessFinding[]
    for (name, definitions) in sort(collect(records); by=first)
        method_definitions = [
            definition for definition in definitions if definition.kind == "function"
        ]
        length(method_definitions) >= 2 || continue
        owner_paths = sort(unique(definition.path for definition in method_definitions))
        length(owner_paths) >= 2 || continue
        has_extension_pattern_doc(function_docs_by_name, name) && continue
        first_definition = first(sort(method_definitions; by=definition -> (
            definition.path,
            definition.line,
            definition.column,
        )))
        owner_summary = join(display_public_owner_path.(Ref(scope), owner_paths), ", ")
        push!(
            findings,
            finding_from_rule(
                rules[AGENT_JL_R009];
                summary="Exported/public method family `$(name)` is implemented across $(length(owner_paths)) owner files without a documented dispatch pattern: $(owner_summary).",
                location=SourceLocation(
                    first_definition.path,
                    first_definition.line,
                    first_definition.column,
                ),
                source_line=first_definition.source_line,
                label="document the Julia dispatch or extension pattern for this public method family",
            ),
        )
    end
    findings
end

function has_extension_pattern_doc(
    docs_by_name::Dict{String,Vector{String}},
    name::AbstractString,
)
    any(get(docs_by_name, String(name), String[])) do text
        lower_text = lowercase(text)
        any(token -> occursin(token, lower_text), EXTENSION_PATTERN_DOC_TOKENS)
    end
end
