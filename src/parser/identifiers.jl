function identifier_syntax_from_node(
    node::JuliaSyntax.SyntaxNode,
    parent::Union{Nothing,JuliaSyntax.SyntaxNode},
)
    isnothing(parent) && return nothing
    name = String(JuliaSyntax.sourcetext(node))
    is_searchable_identifier_name(name) || return nothing
    location = JuliaSyntax.source_location(node)
    JuliaIdentifierSyntax(
        location[1],
        location[2] - 1,
        name,
        syntax_kind(parent),
        compact_syntax_text(parent),
    )
end

function is_searchable_identifier_name(name::AbstractString)
    !isnothing(match(r"^[A-Za-z_][A-Za-z0-9_!]*$", name))
end
