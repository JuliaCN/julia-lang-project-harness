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
    "@$(fact.kind)$(target_suffix)"
end
