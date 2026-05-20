const CONTROL_FLOW_KINDS = Set(["for", "if", "let", "try", "while"])

function function_control_flow_depth(node::JuliaSyntax.SyntaxNode)
    max_depth = 0
    for child in function_body_nodes(node)
        max_depth = max(max_depth, control_flow_depth_from_node(child, 0))
    end
    max_depth
end

function function_control_flow_kinds(node::JuliaSyntax.SyntaxNode)
    kinds = String[]
    seen = Set{String}()
    for child in function_body_nodes(node)
        collect_control_flow_kinds!(kinds, seen, child)
    end
    kinds
end

function function_body_nodes(node::JuliaSyntax.SyntaxNode)
    signature = first_call_child(node)
    [child for child in syntax_children(node) if child !== signature]
end

function control_flow_depth_from_node(node::JuliaSyntax.SyntaxNode, depth::Int)
    kind = syntax_kind(node)
    kind in ("function", "macro") && return depth
    next_depth = kind in CONTROL_FLOW_KINDS ? depth + 1 : depth
    max_depth = next_depth
    for child in syntax_children(node)
        max_depth = max(max_depth, control_flow_depth_from_node(child, next_depth))
    end
    max_depth
end

function collect_control_flow_kinds!(
    kinds::Vector{String},
    seen::Set{String},
    node::JuliaSyntax.SyntaxNode,
)
    kind = syntax_kind(node)
    kind in ("function", "macro") && return
    if kind in CONTROL_FLOW_KINDS && !(kind in seen)
        push!(seen, kind)
        push!(kinds, kind)
    end
    for child in syntax_children(node)
        collect_control_flow_kinds!(kinds, seen, child)
    end
end
