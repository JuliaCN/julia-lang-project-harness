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

const STRINGLY_DOMAIN_ARGUMENT_NAMES = Set([
    "kind",
    "mode",
    "phase",
    "state",
    "status",
    "tag",
    "type",
])
const STRINGLY_DOMAIN_TYPE_NAMES = Set(["AbstractString", "String"])

function function_stringly_domain_args(signature::JuliaSyntax.SyntaxNode)
    args = String[]
    for argument in function_argument_nodes(signature)
        name = argument_name(argument)
        isnothing(name) && continue
        name in STRINGLY_DOMAIN_ARGUMENT_NAMES || continue
        is_stringly_argument(argument) || continue
        push!(args, name)
    end
    unique(args)
end

function function_argument_nodes(signature::JuliaSyntax.SyntaxNode)
    nodes = JuliaSyntax.SyntaxNode[]
    for argument in call_arguments(signature)
        if syntax_kind(argument) == "parameters"
            append!(nodes, syntax_children(argument))
        else
            push!(nodes, argument)
        end
    end
    nodes
end

function is_stringly_argument(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "::"
        children = syntax_children(node)
        length(children) >= 2 || return false
        return terminal_type_name(children[2]) in STRINGLY_DOMAIN_TYPE_NAMES
    elseif kind == "="
        children = syntax_children(node)
        isempty(children) && return false
        typed_name = is_stringly_argument(first(children))
        string_default = any(child -> !isnothing(string_literal_value(child)), children[2:end])
        return typed_name || string_default
    end
    false
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
