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
        member_names = moshi_match_case_names_for_node(member)
        for name in member_names
            name in seen && continue
            push!(seen, name)
            push!(names, name)
        end
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
        member_patterns = moshi_match_case_patterns_for_node(member)
        for pattern in member_patterns
            pattern in seen && continue
            push!(seen, pattern)
            push!(patterns, pattern)
        end
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
    elseif kind == "struct"
        return first_identifier_text(node)
    elseif kind in ("::", "=")
        children = syntax_children(node)
        isempty(children) && return nothing
        return moshi_data_variant_name(first(children))
    end
    nothing
end

function moshi_match_case_name(node::JuliaSyntax.SyntaxNode)
    names = moshi_match_case_names_for_node(node)
    isempty(names) ? nothing : first(names)
end

function moshi_match_case_names_for_node(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "call" || return String[]
    children = syntax_children(node)
    length(children) >= 3 || return String[]
    moshi_case_arrow_operator(children[2]) || return String[]
    moshi_match_pattern_names(first(children))
end

function moshi_match_case_pattern(node::JuliaSyntax.SyntaxNode)
    patterns = moshi_match_case_patterns_for_node(node)
    isempty(patterns) ? nothing : first(patterns)
end

function moshi_match_case_patterns_for_node(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "call" || return String[]
    children = syntax_children(node)
    length(children) >= 3 || return String[]
    moshi_case_arrow_operator(children[2]) || return String[]
    moshi_match_pattern_texts(first(children))
end

function moshi_case_arrow_operator(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "Identifier" && String(JuliaSyntax.sourcetext(node)) == "=>"
end

function moshi_match_pattern_name(node::JuliaSyntax.SyntaxNode)
    names = moshi_match_pattern_names(node)
    isempty(names) ? nothing : first(names)
end

function moshi_match_pattern_names(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "||"
        names = String[]
        for child in syntax_children(node)
            append!(names, moshi_match_pattern_names(child))
        end
        return names
    elseif kind == "call"
        children = syntax_children(node)
        isempty(children) && return String[]
        return moshi_match_pattern_names(first(children))
    elseif kind == "."
        names = identifier_texts(node)
        length(names) >= 2 && return [last(names)]
    elseif kind == "string"
        value = string_literal_value(node)
        isnothing(value) || return [value]
    elseif kind == "Identifier"
        name = String(JuliaSyntax.sourcetext(node))
        name == "_" && return String[]
        return [name]
    end
    String[]
end

function moshi_match_pattern_text(node::JuliaSyntax.SyntaxNode)
    patterns = moshi_match_pattern_texts(node)
    isempty(patterns) ? nothing : first(patterns)
end

function moshi_match_pattern_texts(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "||"
        patterns = String[]
        for child in syntax_children(node)
            append!(patterns, moshi_match_pattern_texts(child))
        end
        return patterns
    elseif kind == "call"
        children = syntax_children(node)
        isempty(children) && return String[]
        return moshi_match_pattern_texts(first(children))
    elseif kind == "."
        names = identifier_texts(node)
        isempty(names) && return String[]
        return [join(names, ".")]
    elseif kind == "string"
        value = string_literal_value(node)
        isnothing(value) || return [value]
    elseif kind == "Identifier"
        name = String(JuliaSyntax.sourcetext(node))
        name == "_" && return String[]
        return [name]
    end
    String[]
end
