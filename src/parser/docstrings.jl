function docstring_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    children = syntax_children(node)
    length(children) >= 2 || return nothing
    text = string_literal_value(first(children))
    isnothing(text) && return nothing
    target = documented_syntax_target(children[2])
    isnothing(target) && return nothing
    location = JuliaSyntax.source_location(node)
    JuliaDocstringSyntax(
        location[1],
        location[2] - 1,
        target[1],
        target[2],
        text,
        String(JuliaSyntax.sourcetext(first(children))),
    )
end

function documented_syntax_target(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "module"
        name = first_identifier_text(node)
        return isnothing(name) ? nothing : ("module", name)
    elseif kind in ("function", "macro")
        function_fact = function_syntax_from_node(node)
        return isnothing(function_fact) ? nothing : (function_fact.kind, function_fact.name)
    elseif kind in ("struct", "abstract", "primitive")
        type_fact = type_syntax_from_node(node)
        return isnothing(type_fact) ? nothing : (type_fact.kind, type_fact.name)
    elseif kind == "const"
        name = const_binding_name(node)
        return isnothing(name) ? nothing : ("const", name)
    end
    nothing
end

function const_binding_name(node::JuliaSyntax.SyntaxNode)
    children = syntax_children(node)
    isempty(children) && return nothing
    binding_name_text(first(children))
end

function binding_name_text(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif kind in ("=", "::")
        children = syntax_children(node)
        isempty(children) && return nothing
        return binding_name_text(first(children))
    end
    nothing
end
