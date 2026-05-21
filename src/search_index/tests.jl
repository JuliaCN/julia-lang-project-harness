function test_search_entries(parsed::ParsedJuliaFile)
    [
        search_index_entry(
            parsed,
            test_fact.line,
            test_fact.column,
            test_fact.kind,
            something(test_fact.label, test_fact.name);
            detail=display_test_search_detail(test_fact),
            tags=test_search_tags(test_fact),
        ) for test_fact in parsed.syntax_facts.tests
    ]
end

function test_search_tags(test_fact::JuliaTestSyntax)
    tags = ["test", test_fact.kind]
    if test_fact.control_flow_depth > 0
        push!(tags, "control-flow")
        append!(tags, test_fact.control_flow_kinds)
    end
    test_fact.branch_count > 0 && push!(tags, "branch")
    test_fact.branch_count >= 2 && push!(tags, "branchy")
    test_fact.loop_count > 0 && push!(tags, "loop")
    test_fact.loop_nesting_depth >= 2 && push!(tags, "nested-loop")
    unique(tags)
end

function display_test_search_detail(test_fact::JuliaTestSyntax)
    flow_suffix = test_fact.control_flow_depth == 0 ? "" :
                  " flow=$(test_fact.control_flow_depth):$(join(test_fact.control_flow_kinds, ","))"
    branch_suffix = test_fact.branch_count == 0 ? "" :
                    " branches=$(test_fact.branch_count)"
    loop_suffix = test_fact.loop_count == 0 ? "" :
                  " loops=$(test_fact.loop_count)"
    loop_depth_suffix = test_fact.loop_nesting_depth == 0 ? "" :
                        " loop_depth=$(test_fact.loop_nesting_depth)"
    "$(test_fact.expression)$(flow_suffix)$(branch_suffix)$(loop_suffix)$(loop_depth_suffix)"
end
