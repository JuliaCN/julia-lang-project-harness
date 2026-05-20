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
    signature = function_signature_node(node)
    [child for child in syntax_children(node) if child !== signature]
end

function function_body_statement_count(node::JuliaSyntax.SyntaxNode)
    length(function_body_statement_nodes(node))
end

function function_body_named_calls(node::JuliaSyntax.SyntaxNode)
    names = String[]
    seen = Set{String}()
    for statement in function_body_statement_nodes(node)
        collect_body_named_calls!(names, seen, statement)
    end
    names
end

function function_macro_invocation_facts(node::JuliaSyntax.SyntaxNode)
    names = String[]
    seen = Set{String}()
    count = Ref(0)
    for child in function_body_nodes(node)
        collect_function_macro_invocation_facts!(count, names, seen, child)
    end
    (count=count[], names=names)
end

function function_body_statement_nodes(node::JuliaSyntax.SyntaxNode)
    statements = JuliaSyntax.SyntaxNode[]
    for child in function_body_nodes(node)
        if syntax_kind(child) == "block"
            append!(statements, syntax_children(child))
        else
            push!(statements, child)
        end
    end
    statements
end

function collect_body_named_calls!(
    names::Vector{String},
    seen::Set{String},
    node::JuliaSyntax.SyntaxNode,
)
    kind = syntax_kind(node)
    kind in ("function", "macro") && return
    if kind == "call"
        call_name = call_expression_name(node)
        if !isnothing(call_name)
            terminal_name = last(split(call_name, "."))
            if is_searchable_call_name(terminal_name) && !(terminal_name in seen)
                push!(seen, terminal_name)
                push!(names, terminal_name)
            end
        end
    end
    for child in syntax_children(node)
        collect_body_named_calls!(names, seen, child)
    end
end

function collect_function_macro_invocation_facts!(
    count::Base.RefValue{Int},
    names::Vector{String},
    seen::Set{String},
    node::JuliaSyntax.SyntaxNode,
)
    kind = syntax_kind(node)
    kind in ("function", "macro") && return
    if kind == "macrocall"
        invocation = macro_invocation_syntax_from_node(node)
        if !isnothing(invocation)
            count[] += 1
            name = invocation.terminal_name
            if !(name in seen)
                push!(seen, name)
                push!(names, name)
            end
        end
    end
    for child in syntax_children(node)
        collect_function_macro_invocation_facts!(count, names, seen, child)
    end
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
