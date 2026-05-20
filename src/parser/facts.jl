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
    JuliaFunctionSyntax(
        location[1],
        location[2] - 1,
        syntax_kind(node),
        name,
        last(split(name, ".")),
        function_positional_args(signature),
        function_bool_positional_args(signature),
        function_keyword_args(signature),
        String(JuliaSyntax.sourcetext(node)),
    )
end

function type_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    location = JuliaSyntax.source_location(node)
    head = type_head_node(node)
    isnothing(head) && return nothing
    name = type_name_text(head)
    isnothing(name) && return nothing
    JuliaTypeSyntax(
        location[1],
        location[2] - 1,
        syntax_kind(node),
        name,
        type_parameter_texts(head),
        type_supertype_text(head),
        type_field_names(node),
        JuliaSyntax.has_flags(node, JuliaSyntax.MUTABLE_FLAG),
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

function terminal_macro_name(node::JuliaSyntax.SyntaxNode)
    names = identifier_texts(node)
    isempty(names) ? nothing : last(names)
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

function type_head_node(node::JuliaSyntax.SyntaxNode)
    for child in syntax_children(node)
        syntax_kind(child) in ("block", "Integer") && continue
        return child
    end
    nothing
end

function type_name_text(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif kind == "curly"
        children = syntax_children(node)
        isempty(children) && return nothing
        return type_name_text(first(children))
    elseif kind == "<:"
        children = syntax_children(node)
        isempty(children) && return nothing
        return type_name_text(first(children))
    end
    nothing
end

function type_parameter_texts(node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "<:"
        children = syntax_children(node)
        isempty(children) && return String[]
        head = first(children)
    else
        head = node
    end
    syntax_kind(head) == "curly" || return String[]
    children = syntax_children(head)
    length(children) <= 1 && return String[]
    [compact_syntax_text(child) for child in children[2:end]]
end

function type_supertype_text(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "<:" || return nothing
    children = syntax_children(node)
    length(children) >= 2 || return nothing
    compact_syntax_text(children[2])
end

function type_field_names(node::JuliaSyntax.SyntaxNode)
    block = first_child_with_kind(node, "block")
    isnothing(block) && return String[]
    fields = String[]
    for child in syntax_children(block)
        name = field_name_text(child)
        !isnothing(name) && push!(fields, name)
    end
    fields
end

function field_name_text(node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif syntax_kind(node) == "::"
        children = syntax_children(node)
        isempty(children) && return nothing
        return field_name_text(first(children))
    end
    nothing
end

function first_child_with_kind(node::JuliaSyntax.SyntaxNode, kind::AbstractString)
    for child in syntax_children(node)
        syntax_kind(child) == kind && return child
    end
    nothing
end

function first_call_child(node::JuliaSyntax.SyntaxNode)
    for child in syntax_children(node)
        syntax_kind(child) == "call" && return child
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

function function_positional_args(signature::JuliaSyntax.SyntaxNode)
    args = String[]
    for argument in call_arguments(signature)
        syntax_kind(argument) == "parameters" && continue
        name = argument_name(argument)
        !isnothing(name) && push!(args, name)
    end
    args
end

function function_bool_positional_args(signature::JuliaSyntax.SyntaxNode)
    args = String[]
    for argument in call_arguments(signature)
        syntax_kind(argument) == "parameters" && continue
        is_bool_argument(argument) || continue
        name = argument_name(argument)
        !isnothing(name) && push!(args, name)
    end
    args
end

function is_bool_argument(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "::"
        children = syntax_children(node)
        length(children) >= 2 || return false
        return terminal_type_name(children[2]) == "Bool"
    elseif kind == "="
        children = syntax_children(node)
        isempty(children) && return false
        typed_name = is_bool_argument(first(children))
        bool_default = any(child -> syntax_kind(child) == "Bool", children[2:end])
        return typed_name || bool_default
    end
    false
end

function terminal_type_name(node::JuliaSyntax.SyntaxNode)
    names = identifier_texts(node)
    isempty(names) ? nothing : last(names)
end

function function_keyword_args(signature::JuliaSyntax.SyntaxNode)
    arguments = call_arguments(signature)
    keyword_index = findfirst(node -> syntax_kind(node) == "parameters", arguments)
    isnothing(keyword_index) && return String[]
    keyword_node = arguments[keyword_index]
    names = String[]
    for argument in syntax_children(keyword_node)
        name = argument_name(argument)
        !isnothing(name) && push!(names, name)
    end
    names
end

function argument_name(node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    end
    identifiers = identifier_texts(node)
    isempty(identifiers) ? nothing : first(identifiers)
end
