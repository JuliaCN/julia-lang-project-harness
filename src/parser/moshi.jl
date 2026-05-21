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

function moshi_macro_case_names(node::JuliaSyntax.SyntaxNode, kind::AbstractString)
    kind == "match" || return String[]
    body = moshi_macro_block_node(node)
    isnothing(body) && return String[]
    names = String[]
    seen = Set{String}()
    for member in syntax_children(body)
        name = moshi_match_case_name(member)
        isnothing(name) && continue
        name in seen && continue
        push!(seen, name)
        push!(names, name)
    end
    names
end

function moshi_macro_case_patterns(node::JuliaSyntax.SyntaxNode, kind::AbstractString)
    kind == "match" || return String[]
    body = moshi_macro_block_node(node)
    isnothing(body) && return String[]
    patterns = String[]
    seen = Set{String}()
    for member in syntax_children(body)
        pattern = moshi_match_case_pattern(member)
        isnothing(pattern) && continue
        pattern in seen && continue
        push!(seen, pattern)
        push!(patterns, pattern)
    end
    patterns
end

function moshi_data_body_node(node::JuliaSyntax.SyntaxNode)
    moshi_macro_block_node(node)
end

function moshi_macro_block_node(node::JuliaSyntax.SyntaxNode)
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

function moshi_match_case_name(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "call" || return nothing
    children = syntax_children(node)
    length(children) >= 3 || return nothing
    moshi_case_arrow_operator(children[2]) || return nothing
    moshi_match_pattern_name(first(children))
end

function moshi_match_case_pattern(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "call" || return nothing
    children = syntax_children(node)
    length(children) >= 3 || return nothing
    moshi_case_arrow_operator(children[2]) || return nothing
    moshi_match_pattern_text(first(children))
end

function moshi_case_arrow_operator(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "Identifier" && String(JuliaSyntax.sourcetext(node)) == "=>"
end

function moshi_match_pattern_name(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "call"
        children = syntax_children(node)
        isempty(children) && return nothing
        return moshi_match_pattern_name(first(children))
    elseif kind == "."
        names = identifier_texts(node)
        length(names) >= 2 && return last(names)
    elseif kind == "Identifier"
        name = String(JuliaSyntax.sourcetext(node))
        name == "_" && return nothing
        return name
    end
    nothing
end

function moshi_match_pattern_text(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "call"
        children = syntax_children(node)
        isempty(children) && return nothing
        return moshi_match_pattern_text(first(children))
    elseif kind == "."
        names = identifier_texts(node)
        isempty(names) && return nothing
        return join(names, ".")
    elseif kind == "Identifier"
        name = String(JuliaSyntax.sourcetext(node))
        name == "_" && return nothing
        return name
    end
    nothing
end
