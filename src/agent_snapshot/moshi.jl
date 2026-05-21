function snapshot_moshi_lines(scope::JuliaProjectHarnessScope, parsed_files::Vector{ParsedJuliaFile})
    lines = moshi_extension_snapshot_lines(scope)
    for parsed in parsed_files
        isempty(parsed.syntax_facts.moshi) && continue
        facts = [display_moshi_syntax(fact) for fact in parsed.syntax_facts.moshi]
        push!(lines, "- $(display_project_path(scope, parsed.report.path)) $(join(facts, "; "))")
    end
    lines
end

function display_moshi_syntax(fact::JuliaMoshiSyntax)
    target_suffix = isnothing(fact.target_name) ? "" : "=$(fact.target_name)"
    variant_suffix = isempty(fact.variant_names) ? "" : ";variants=$(join(fact.variant_names, ","))"
    case_suffix = isempty(fact.case_names) ? "" : ";cases=$(join(fact.case_names, ","))"
    pattern_suffix = isempty(fact.case_patterns) ? "" :
                     ";patterns=$(join(fact.case_patterns, ","))"
    "@$(fact.kind)$(target_suffix)$(variant_suffix)$(case_suffix)$(pattern_suffix)"
end
