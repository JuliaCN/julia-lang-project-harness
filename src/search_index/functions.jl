function function_argument_search_entries(parsed::ParsedJuliaFile)
    entries = JuliaSearchIndexEntry[]
    for function_fact in parsed.syntax_facts.functions
        for argument_fact in function_fact.argument_facts
            push!(
                entries,
                search_index_entry(
                    parsed,
                    argument_fact.line,
                    argument_fact.column,
                    "argument",
                    "$(function_fact.name).$(argument_fact.name)";
                    detail=display_function_argument_search_detail(
                        function_fact,
                        argument_fact,
                    ),
                    tags=function_argument_search_tags(function_fact, argument_fact),
                ),
            )
        end
    end
    entries
end

function function_argument_search_tags(
    function_fact::JuliaFunctionSyntax,
    argument_fact::JuliaFunctionArgumentSyntax,
)
    tags = [
        "method",
        "argument",
        argument_fact.is_keyword ? "keyword" : "positional",
        function_fact.kind,
        function_fact.terminal_name,
    ]
    argument_fact.is_bool && push!(tags, "bool")
    argument_fact.is_stringly_domain && push!(tags, "stringly")
    tags
end

function function_search_tags(function_fact::JuliaFunctionSyntax)
    tags = ["method", function_fact.kind, function_fact.terminal_name]
    if function_fact.control_flow_depth > 0
        push!(tags, "control-flow")
        append!(tags, function_fact.control_flow_kinds)
    end
    function_fact.branch_count > 0 && push!(tags, "branch")
    function_fact.branch_count >= 2 && push!(tags, "branchy")
    function_fact.loop_count > 0 && push!(tags, "loop")
    function_fact.loop_nesting_depth >= 2 && push!(tags, "nested-loop")
    function_fact.macro_invocation_count > 0 && push!(tags, "macro")
    function_fact.body_statement_count >= 8 && push!(tags, "broad-body")
    length(function_fact.body_named_calls) >= 3 && push!(tags, "pipeline")
    unique(tags)
end

function display_function_argument_search_detail(
    function_fact::JuliaFunctionSyntax,
    argument_fact::JuliaFunctionArgumentSyntax,
)
    role = argument_fact.is_keyword ? "keyword" : "positional"
    type_suffix = isnothing(argument_fact.type_annotation) ? "" :
                  "::$(argument_fact.type_annotation)"
    default_suffix = argument_fact.has_default ? " default" : ""
    bool_suffix = argument_fact.is_bool ? " bool" : ""
    stringly_suffix = argument_fact.is_stringly_domain ? " stringly" : ""
    "$(function_fact.kind) $(argument_fact.owner_name).$(argument_fact.name) $(role)$(type_suffix)$(default_suffix)$(bool_suffix)$(stringly_suffix)"
end
