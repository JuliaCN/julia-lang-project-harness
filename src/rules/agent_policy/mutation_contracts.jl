function public_mutating_method_contract_findings(
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    function_docs_by_name::Dict{String,Vector{String}},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    reported = Set{String}()
    for parsed in parsed_files
        parsed.report.is_valid || continue
        append!(
            findings,
            public_mutating_method_contract_findings(
                parsed,
                public_names,
                function_docs_by_name,
                rules,
                reported,
            ),
        )
    end
    findings
end

function public_mutating_method_contract_findings(
    parsed::ParsedJuliaFile,
    public_names::Set{String},
    function_docs_by_name::Dict{String,Vector{String}},
    rules::Dict{String,JuliaHarnessRule},
    reported::Set{String},
)
    findings = JuliaHarnessFinding[]
    for function_fact in parsed.syntax_facts.functions
        name = function_fact.terminal_name
        name in public_names || continue
        endswith(name, "!") || continue
        haskey(function_docs_by_name, name) || continue
        name in reported && continue
        has_mutation_contract_doc(function_docs_by_name, name) && continue
        push!(reported, name)
        push!(
            findings,
            finding_from_rule(
                rules[AGENT_JL_R016];
                summary="Exported/public mutating method `$(name)` is documented without a mutation contract.",
                location=SourceLocation(parsed.report.path, function_fact.line, function_fact.column),
                source_line=source_line(parsed.source, function_fact.line),
                label="document which arguments or state this public mutating method changes",
            ),
        )
    end
    findings
end
