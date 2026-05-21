function moshi_search_entries(parsed::ParsedJuliaFile)
    [
        search_index_entry(
            parsed,
            moshi_fact.line,
            moshi_fact.column,
            "moshi",
            something(moshi_fact.target_name, moshi_fact.kind);
            detail=display_moshi_search_detail(moshi_fact),
            tags=["macro", "moshi", moshi_fact.kind],
        ) for moshi_fact in parsed.syntax_facts.moshi
    ]
end

function display_moshi_search_detail(moshi_fact::JuliaMoshiSyntax)
    target_suffix = isnothing(moshi_fact.target_name) ? "" : " target=$(moshi_fact.target_name)"
    variant_suffix = isempty(moshi_fact.variant_names) ? "" :
                     " variants=$(join(moshi_fact.variant_names, ","))"
    case_suffix = isempty(moshi_fact.case_names) ? "" :
                  " cases=$(join(moshi_fact.case_names, ","))"
    pattern_suffix = isempty(moshi_fact.case_patterns) ? "" :
                     " patterns=$(join(moshi_fact.case_patterns, ","))"
    "Moshi @$(moshi_fact.kind)$(target_suffix)$(variant_suffix)$(case_suffix)$(pattern_suffix)"
end
