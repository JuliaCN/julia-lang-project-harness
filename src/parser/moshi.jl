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

function moshi_macro_variant_names(node::JuliaSyntax.SyntaxNode, kind::AbstractString)
    kind == "data" || return String[]
    body = moshi_data_body_node(node)
    isnothing(body) && return String[]
    names = String[]
    seen = Set{String}()
    for member in syntax_children(body)
        name = moshi_data_variant_name(member)
        isnothing(name) && continue
        name in seen && continue
        push!(seen, name)
        push!(names, name)
    end
    names
end

function moshi_data_body_node(node::JuliaSyntax.SyntaxNode)
    for argument in macro_arguments(node)
        syntax_kind(argument) == "block" && return argument
    end
    nothing
end

function moshi_data_variant_name(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif kind == "call"
        children = syntax_children(node)
        isempty(children) && return nothing
        return call_name_text(first(children))
    elseif kind in ("::", "=")
        children = syntax_children(node)
        isempty(children) && return nothing
        return moshi_data_variant_name(first(children))
    end
    nothing
end
