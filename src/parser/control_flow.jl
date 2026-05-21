const CONTROL_FLOW_KINDS = Set(["for", "if", "let", "try", "while"])
const LOOP_FLOW_KINDS = Set(["for", "while"])
const BRANCH_FLOW_KINDS = Set(["if", "elseif", "try"])
const STRINGLY_BRANCH_COMPARISON_OPERATORS = Set(["==", "!=", "===", "!=="])
const STRINGLY_BRANCH_MEMBERSHIP_OPERATORS = Set(["in", "∈"])

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

function function_branch_count(node::JuliaSyntax.SyntaxNode)
    count = 0
    for child in function_body_nodes(node)
        count += control_flow_kind_count(child, BRANCH_FLOW_KINDS)
    end
    count
end

function function_stringly_branch_literals(
    node::JuliaSyntax.SyntaxNode,
    stringly_domain_args::Vector{String},
)
    isempty(stringly_domain_args) && return String[]
    literals = String[]
    seen = Set{String}()
    domain_args = Set(stringly_domain_args)
    for child in function_body_nodes(node)
        collect_stringly_branch_literals!(literals, seen, child, domain_args)
    end
    literals
end

function function_loop_count(node::JuliaSyntax.SyntaxNode)
    count = 0
    for child in function_body_nodes(node)
        count += control_flow_kind_count(child, LOOP_FLOW_KINDS)
    end
    count
end

function function_loop_nesting_depth(node::JuliaSyntax.SyntaxNode)
    max_depth = 0
    for child in function_body_nodes(node)
        max_depth = max(max_depth, loop_nesting_depth_from_node(child, 0))
    end
    max_depth
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

function loop_nesting_depth_from_node(node::JuliaSyntax.SyntaxNode, depth::Int)
    kind = syntax_kind(node)
    kind in ("function", "macro") && return depth
    next_depth = kind in LOOP_FLOW_KINDS ? depth + 1 : depth
    max_depth = next_depth
    for child in syntax_children(node)
        max_depth = max(max_depth, loop_nesting_depth_from_node(child, next_depth))
    end
    max_depth
end

function control_flow_kind_count(
    node::JuliaSyntax.SyntaxNode,
    counted_kinds::Set{String},
)
    kind = syntax_kind(node)
    kind in ("function", "macro") && return 0
    count = kind in counted_kinds ? 1 : 0
    for child in syntax_children(node)
        count += control_flow_kind_count(child, counted_kinds)
    end
    count
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

function collect_stringly_branch_literals!(
    literals::Vector{String},
    seen::Set{String},
    node::JuliaSyntax.SyntaxNode,
    domain_args::Set{String},
)
    kind = syntax_kind(node)
    kind in ("function", "macro") && return
    if kind in ("if", "elseif")
        children = syntax_children(node)
        if !isempty(children)
            collect_stringly_branch_condition_literals!(
                literals,
                seen,
                first(children),
                domain_args,
            )
        end
    end
    for child in syntax_children(node)
        collect_stringly_branch_literals!(literals, seen, child, domain_args)
    end
end

function collect_stringly_branch_condition_literals!(
    literals::Vector{String},
    seen::Set{String},
    node::JuliaSyntax.SyntaxNode,
    domain_args::Set{String},
)
    if syntax_kind(node) == "call"
        for literal in stringly_branch_comparison_literals(node, domain_args)
            literal in seen && continue
            push!(seen, literal)
            push!(literals, literal)
        end
    end
    for child in syntax_children(node)
        collect_stringly_branch_condition_literals!(literals, seen, child, domain_args)
    end
end

function stringly_branch_comparison_literals(
    node::JuliaSyntax.SyntaxNode,
    domain_args::Set{String},
)
    children = syntax_children(node)
    length(children) >= 3 || return String[]
    operator = stringly_branch_operator(children[2])
    isnothing(operator) && return String[]
    left = children[1]
    right = children[3]
    if operator in STRINGLY_BRANCH_COMPARISON_OPERATORS
        return stringly_equality_branch_literals(left, right, domain_args)
    elseif operator in STRINGLY_BRANCH_MEMBERSHIP_OPERATORS
        return stringly_membership_branch_literals(left, right, domain_args)
    end
    String[]
end

function stringly_branch_operator(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "Identifier" || return nothing
    String(JuliaSyntax.sourcetext(node))
end

function stringly_equality_branch_literals(
    left::JuliaSyntax.SyntaxNode,
    right::JuliaSyntax.SyntaxNode,
    domain_args::Set{String},
)
    literals = String[]
    if is_stringly_domain_identifier(left, domain_args)
        literal = string_literal_value(right)
        !isnothing(literal) && push!(literals, literal)
    end
    if is_stringly_domain_identifier(right, domain_args)
        literal = string_literal_value(left)
        !isnothing(literal) && push!(literals, literal)
    end
    literals
end

function stringly_membership_branch_literals(
    left::JuliaSyntax.SyntaxNode,
    right::JuliaSyntax.SyntaxNode,
    domain_args::Set{String},
)
    is_stringly_domain_identifier(left, domain_args) || return String[]
    string_literal_values(right)
end

function is_stringly_domain_identifier(
    node::JuliaSyntax.SyntaxNode,
    domain_args::Set{String},
)
    syntax_kind(node) == "Identifier" || return false
    String(JuliaSyntax.sourcetext(node)) in domain_args
end

function string_literal_values(node::JuliaSyntax.SyntaxNode)
    literal = string_literal_value(node)
    !isnothing(literal) && return [literal]
    literals = String[]
    for child in syntax_children(node)
        append!(literals, string_literal_values(child))
    end
    literals
end
