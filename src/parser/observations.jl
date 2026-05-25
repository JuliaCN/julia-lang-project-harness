function source_observation_from_macro_invocation(
    node::JuliaSyntax.SyntaxNode,
    invocation::JuliaMacroInvocationSyntax,
)
    invocation.terminal_name == "test_throws" || return nothing
    children = syntax_children(node)
    shape, names = test_throws_observation_shape(children)
    location = JuliaSyntax.source_location(node)
    JuliaSourceObservation(
        location[1],
        location[2] - 1,
        "test_throws",
        shape,
        names,
        invocation.expression,
    )
end

function test_throws_observation_shape(children::Vector{JuliaSyntax.SyntaxNode})
    length(children) >= 3 || return ("malformed-missing-expression", String[])
    tested_expression = children[3]
    syntax_kind(tested_expression) == "call" ||
        return ("rejected-non-call-expression", String[])
    name = call_expression_name(tested_expression)
    isnothing(name) && return ("rejected-unresolved-call-name", String[])
    ("accepted-direct-public-call", [last(split(name, "."))])
end
