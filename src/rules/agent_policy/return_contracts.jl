const RETURN_CONTRACT_DOC_TOKENS = (
    "conversion",
    "converts",
    "return contract",
    "return type",
    "returns",
    "type stability",
    "type-stable",
)

const BROAD_RETURN_ANNOTATIONS = Set(["Any", "Missing", "Nothing"])

function public_return_contract_findings(
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    function_docs_by_name::Dict{String,Vector{String}},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        parsed.report.is_valid || continue
        for function_fact in parsed.syntax_facts.functions
            function_fact.kind == "function" || continue
            function_fact.terminal_name in public_names || continue
            haskey(function_docs_by_name, function_fact.terminal_name) || continue
            is_narrow_public_return_annotation(function_fact) || continue
            has_return_contract_doc(function_docs_by_name, function_fact.terminal_name) &&
                continue
            push!(
                findings,
                finding_from_rule(
                    rules[AGENT_JL_R023];
                    summary="Exported/public method `$(function_fact.terminal_name)` has concrete return annotation `::$(function_fact.return_type)` without a return contract doc.",
                    location=SourceLocation(
                        parsed.report.path,
                        function_fact.line,
                        function_fact.column,
                    ),
                    source_line=source_line(parsed.source, function_fact.line),
                    label="document the return/type-stability contract or remove the narrow return annotation",
                ),
            )
        end
    end
    findings
end

function is_narrow_public_return_annotation(function_fact::JuliaFunctionSyntax)
    isnothing(function_fact.return_type) && return false
    return_type = strip(function_fact.return_type)
    isempty(return_type) && return false
    return_type in BROAD_RETURN_ANNOTATIONS && return false
    startswith(return_type, "Abstract") && return false
    startswith(return_type, "Union{") && return false
    any(
        parameter -> return_annotation_mentions_type_parameter(return_type, parameter),
        where_parameter_names(function_fact.where_parameters),
    ) && return false
    true
end

function where_parameter_names(parameters::Vector{String})
    names = String[]
    for parameter in parameters
        name = first(split(String(parameter), r"\s*(<:|>:|=)\s*"))
        isempty(name) || push!(names, name)
    end
    names
end

function return_annotation_mentions_type_parameter(
    return_type::AbstractString,
    parameter::AbstractString,
)
    tokens = split(replace(String(return_type), r"[^A-Za-z0-9_]+" => " "))
    String(parameter) in tokens
end

function has_return_contract_doc(
    docs_by_name::Dict{String,Vector{String}},
    name::AbstractString,
)
    any(get(docs_by_name, String(name), String[])) do text
        lower_text = lowercase(text)
        any(token -> occursin(token, lower_text), RETURN_CONTRACT_DOC_TOKENS)
    end
end
