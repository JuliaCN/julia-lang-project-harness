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
