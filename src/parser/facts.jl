function is_module_node(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "module"
end

function module_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    location = JuliaSyntax.source_location(node)
    name = first_identifier_text(node)
    JuliaModuleSyntax(
        location[1],
        location[2] - 1,
        something(name, "<anonymous>"),
        JuliaSyntax.has_flags(node, JuliaSyntax.BARE_MODULE_FLAG),
    )
end

function include_syntax_from_call(node::JuliaSyntax.SyntaxNode, source_path::AbstractString)
    location = JuliaSyntax.source_location(node)
    argument = call_arguments(node)
    target = length(argument) == 1 ? literal_path_argument(only(argument)) : nothing
    resolved_target = isnothing(target) ? nothing : normpath(joinpath(dirname(source_path), target))
    JuliaIncludeSyntax(
        location[1],
        location[2] - 1,
        String(JuliaSyntax.sourcetext(node)),
        target,
        resolved_target,
        !isnothing(target),
    )
end

function import_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    location = JuliaSyntax.source_location(node)
    import_paths = import_path_names(node)
    isempty(import_paths) && return JuliaImportSyntax[]
    if length(import_paths) == 1
        return [
            JuliaImportSyntax(
                location[1],
                location[2] - 1,
                kind,
                only(import_paths),
                String[],
                String(JuliaSyntax.sourcetext(node)),
            ),
        ]
    end
    [
        JuliaImportSyntax(
            location[1],
            location[2] - 1,
            kind,
            first(import_paths),
            import_paths[2:end],
            String(JuliaSyntax.sourcetext(node)),
        ),
    ]
end

function export_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    location = JuliaSyntax.source_location(node)
    JuliaExportSyntax(
        location[1],
        location[2] - 1,
        syntax_kind(node),
        identifier_texts(node),
        String(JuliaSyntax.sourcetext(node)),
    )
end

function function_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    signature = first_call_child(node)
    isnothing(signature) && return nothing
    location = JuliaSyntax.source_location(node)
    name_node = first(syntax_children(signature))
    name = function_name_text(name_node)
    isnothing(name) && return nothing
    macro_facts = function_macro_invocation_facts(node)
    JuliaFunctionSyntax(
        location[1],
        location[2] - 1,
        syntax_kind(node),
        name,
        last(split(name, ".")),
        function_positional_args(signature),
        function_typed_positional_args(signature),
        function_bool_positional_args(signature),
        function_stringly_domain_args(signature),
        function_keyword_args(signature),
        function_argument_facts(signature, name),
        function_return_type(node),
        function_where_parameters(node),
        function_control_flow_depth(node),
        function_branch_count(node),
        function_loop_count(node),
        function_loop_nesting_depth(node),
        function_control_flow_kinds(node),
        function_body_statement_count(node),
        function_body_named_calls(node),
        macro_facts.count,
        macro_facts.names,
        String(JuliaSyntax.sourcetext(node)),
    )
end

function type_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    location = JuliaSyntax.source_location(node)
    head = type_head_node(node)
    isnothing(head) && return nothing
    name = type_name_text(head)
    isnothing(name) && return nothing
    field_facts = type_field_facts(node, name)
    JuliaTypeSyntax(
        location[1],
        location[2] - 1,
        syntax_kind(node),
        name,
        type_parameter_texts(head),
        type_supertype_text(head),
        type_field_names(field_facts),
        type_typed_fields(field_facts),
        type_defaulted_fields(field_facts),
        field_facts,
        JuliaSyntax.has_flags(node, JuliaSyntax.MUTABLE_FLAG),
        String(JuliaSyntax.sourcetext(node)),
    )
end

function binding_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    kind in ("const", "global") || return nothing
    children = syntax_children(node)
    isempty(children) && return nothing
    name = binding_name_text(first(children))
    isnothing(name) && return nothing
    location = JuliaSyntax.source_location(node)
    JuliaBindingSyntax(
        location[1],
        location[2] - 1,
        kind,
        name,
        last(split(name, ".")),
        binding_type_annotation(first(children)),
        kind == "const",
        String(JuliaSyntax.sourcetext(node)),
    )
end

function macro_invocation_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    children = syntax_children(node)
    isempty(children) && return nothing
    name_node = first(children)
    terminal_name = terminal_macro_name(name_node)
    isnothing(terminal_name) && return nothing
    location = JuliaSyntax.source_location(node)
    JuliaMacroInvocationSyntax(
        location[1],
        location[2] - 1,
        compact_syntax_text(name_node),
        terminal_name,
        String(JuliaSyntax.sourcetext(node)),
    )
end

function call_syntax_from_node(
    node::JuliaSyntax.SyntaxNode,
    parent::Union{Nothing,JuliaSyntax.SyntaxNode},
)
    is_definition_signature_call(node, parent) && return nothing
    name = call_expression_name(node)
    isnothing(name) && return nothing
    terminal_name = last(split(name, "."))
    is_searchable_call_name(terminal_name) || return nothing
    location = JuliaSyntax.source_location(node)
    JuliaCallSyntax(
        location[1],
        location[2] - 1,
        name,
        terminal_name,
        call_argument_count(node),
        call_keyword_args(node),
        String(JuliaSyntax.sourcetext(node)),
    )
end

function test_syntax_from_macro_invocation(
    node::JuliaSyntax.SyntaxNode,
    invocation::JuliaMacroInvocationSyntax,
)
    invocation.terminal_name in TEST_MACRO_NAMES || return nothing
    location = JuliaSyntax.source_location(node)
    JuliaTestSyntax(
        location[1],
        location[2] - 1,
        invocation.terminal_name,
        invocation.name,
        first_string_literal_argument(node),
        invocation.expression,
    )
end

function moshi_syntax_from_macro_invocation(
    node::JuliaSyntax.SyntaxNode,
    invocation::JuliaMacroInvocationSyntax,
)
    invocation.terminal_name in MOSHI_MACRO_NAMES || return nothing
    location = JuliaSyntax.source_location(node)
    JuliaMoshiSyntax(
        location[1],
        location[2] - 1,
        invocation.terminal_name,
        invocation.name,
        moshi_macro_target_name(node, invocation.terminal_name),
        invocation.expression,
    )
end

const TEST_MACRO_NAMES = Set([
    "inferred",
    "test",
    "test_broken",
    "test_deprecated",
    "test_logs",
    "test_nowarn",
    "test_skip",
    "test_throws",
    "test_warn",
    "testset",
])

const MOSHI_MACRO_NAMES = Set(["data", "derive", "match"])

function moshi_macro_target_name(node::JuliaSyntax.SyntaxNode, kind::AbstractString)
    arguments = macro_arguments(node)
    isempty(arguments) && return nothing
    if kind in ("data", "derive")
        return syntax_identifier_text(first(arguments))
    elseif kind == "match"
        return compact_syntax_text(first(arguments))
    end
    nothing
end

function syntax_identifier_text(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "Identifier" && return String(JuliaSyntax.sourcetext(node))
    first_identifier_text(node)
end

function terminal_macro_name(node::JuliaSyntax.SyntaxNode)
    names = identifier_texts(node)
    isempty(names) ? nothing : last(names)
end

function binding_type_annotation(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "::"
        children = syntax_children(node)
        length(children) >= 2 || return nothing
        return compact_syntax_text(children[2])
    elseif kind == "="
        children = syntax_children(node)
        isempty(children) && return nothing
        return binding_type_annotation(first(children))
    end
    nothing
end

function is_definition_signature_call(
    node::JuliaSyntax.SyntaxNode,
    parent::Union{Nothing,JuliaSyntax.SyntaxNode},
)
    isnothing(parent) && return false
    syntax_kind(parent) in ("function", "macro") || return false
    signature = first_call_child(parent)
    isnothing(signature) && return false
    signature === node
end

function call_expression_name(node::JuliaSyntax.SyntaxNode)
    children = syntax_children(node)
    isempty(children) && return nothing
    head = call_head_node(children)
    call_name_text(head)
end

function call_head_node(children::Vector{JuliaSyntax.SyntaxNode})
    if length(children) >= 2 && is_operator_identifier(children[2])
        return children[2]
    end
    first(children)
end

function is_operator_identifier(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "Identifier" || return false
    text = String(JuliaSyntax.sourcetext(node))
    isnothing(match(r"^[A-Za-z_][A-Za-z0-9_!]*$", text))
end

function call_name_text(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif kind == "."
        names = identifier_texts(node)
        isempty(names) && return nothing
        return join(names, ".")
    elseif kind == "curly"
        children = syntax_children(node)
        isempty(children) && return nothing
        return call_name_text(first(children))
    end
    nothing
end

function is_searchable_call_name(name::AbstractString)
    !isnothing(match(r"^[A-Za-z_][A-Za-z0-9_!]*$", name))
end

function call_argument_count(node::JuliaSyntax.SyntaxNode)
    count(argument -> syntax_kind(argument) != "parameters", call_arguments(node))
end

function call_keyword_args(node::JuliaSyntax.SyntaxNode)
    arguments = call_arguments(node)
    keyword_index = findfirst(argument -> syntax_kind(argument) == "parameters", arguments)
    isnothing(keyword_index) && return String[]
    names = String[]
    for argument in syntax_children(arguments[keyword_index])
        name = argument_name(argument)
        !isnothing(name) && push!(names, name)
    end
    names
end

function first_string_literal_argument(node::JuliaSyntax.SyntaxNode)
    for argument in macro_arguments(node)
        label = string_literal_value(argument)
        !isnothing(label) && return label
    end
    nothing
end

function macro_arguments(node::JuliaSyntax.SyntaxNode)
    children = syntax_children(node)
    length(children) <= 1 ? JuliaSyntax.SyntaxNode[] : children[2:end]
end

function compact_syntax_text(node::JuliaSyntax.SyntaxNode)
    replace(String(JuliaSyntax.sourcetext(node)), r"\s+" => "")
end

function first_child_with_kind(node::JuliaSyntax.SyntaxNode, kind::AbstractString)
    for child in syntax_children(node)
        syntax_kind(child) == kind && return child
    end
    nothing
end

function first_call_child(node::JuliaSyntax.SyntaxNode)
    signature = function_signature_node(node)
    !isnothing(signature) && return first_call_child_in_signature(signature)
    first_call_child_in_signature(node)
end

function first_call_child_in_signature(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "call" && return node
    for child in syntax_children(node)
        kind = syntax_kind(child)
        kind == "call" && return child
        if kind in ("::", "where")
            found = first_call_child_in_signature(child)
            !isnothing(found) && return found
        end
    end
    nothing
end

function function_signature_node(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) in ("function", "macro") || return nothing
    for child in syntax_children(node)
        syntax_kind(child) == "block" && continue
        !isnothing(first_call_child_in_signature(child)) && return child
    end
    nothing
end

function function_name_text(node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif syntax_kind(node) == "."
        names = identifier_texts(node)
        isempty(names) && return nothing
        return join(names, ".")
    end
    nothing
end
