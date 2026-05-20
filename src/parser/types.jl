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

function type_field_facts(node::JuliaSyntax.SyntaxNode, owner_name::AbstractString)
    fields = JuliaTypeFieldSyntax[]
    for child in type_field_nodes(node)
        name = field_name_text(child)
        isnothing(name) && continue
        location = JuliaSyntax.source_location(child)
        push!(
            fields,
            JuliaTypeFieldSyntax(
                location[1],
                location[2] - 1,
                String(owner_name),
                name,
                field_type_annotation(child),
                syntax_kind(child) == "=",
                String(JuliaSyntax.sourcetext(child)),
            ),
        )
    end
    fields
end

function type_field_names(fields::Vector{JuliaTypeFieldSyntax})
    [field.name for field in fields]
end

function type_typed_fields(fields::Vector{JuliaTypeFieldSyntax})
    ["$(field.name)::$(field.type_annotation)" for field in fields if !isnothing(field.type_annotation)]
end

function type_defaulted_fields(fields::Vector{JuliaTypeFieldSyntax})
    [field.name for field in fields if field.has_default]
end

function type_field_nodes(node::JuliaSyntax.SyntaxNode)
    block = first_child_with_kind(node, "block")
    isnothing(block) ? JuliaSyntax.SyntaxNode[] : syntax_children(block)
end

function field_name_text(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif kind in ("::", "=")
        children = syntax_children(node)
        isempty(children) && return nothing
        return field_name_text(first(children))
    end
    nothing
end

function field_type_annotation(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "::"
        children = syntax_children(node)
        length(children) >= 2 || return nothing
        return compact_syntax_text(children[2])
    elseif kind == "="
        children = syntax_children(node)
        isempty(children) && return nothing
        return field_type_annotation(first(children))
    end
    nothing
end
