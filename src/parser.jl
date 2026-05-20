using JuliaSyntax

struct JuliaIncludeSyntax
    line::Int
    column::Int
    expression::String
    target::Union{Nothing,String}
    resolved_target::Union{Nothing,String}
    is_literal::Bool
end

struct JuliaNativeSyntaxFacts
    has_syntax_tree::Bool
    includes::Vector{JuliaIncludeSyntax}
end

struct ParsedJuliaFile
    report::JuliaFileReport
    source::String
    syntax_facts::JuliaNativeSyntaxFacts
end

function parse_julia_file(path::AbstractString)
    path_string = String(path)
    source = try
        read(path_string, String)
    catch err
        return ParsedJuliaFile(
            JuliaFileReport(path_string, false, "failed to read Julia source: $(err)"),
            "",
            JuliaNativeSyntaxFacts(false, JuliaIncludeSyntax[]),
        )
    end

    try
        syntax = JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, source; filename=path_string)
        ParsedJuliaFile(
            JuliaFileReport(path_string, true, nothing),
            source,
            JuliaNativeSyntaxFacts(true, include_syntax_facts(syntax, path_string)),
        )
    catch err
        ParsedJuliaFile(
            JuliaFileReport(path_string, false, sprint(showerror, err)),
            source,
            JuliaNativeSyntaxFacts(false, JuliaIncludeSyntax[]),
        )
    end
end

function source_line(source::AbstractString, line::Int)
    lines = split(source, '\n'; keepempty=true)
    1 <= line <= length(lines) ? lines[line] : nothing
end

function include_syntax_facts(syntax::JuliaSyntax.SyntaxNode, source_path::AbstractString)
    includes = JuliaIncludeSyntax[]
    collect_include_syntax!(includes, syntax, source_path)
    includes
end

function collect_include_syntax!(
    includes::Vector{JuliaIncludeSyntax},
    node::JuliaSyntax.SyntaxNode,
    source_path::AbstractString,
)
    if is_call_named(node, "include")
        push!(includes, include_syntax_from_call(node, source_path))
    end
    for child in syntax_children(node)
        collect_include_syntax!(includes, child, source_path)
    end
end

function include_syntax_from_call(node::JuliaSyntax.SyntaxNode, source_path::AbstractString)
    location = JuliaSyntax.source_location(node)
    argument = call_arguments(node)
    target = length(argument) == 1 ? literal_path_argument(only(argument)) : nothing
    resolved_target = isnothing(target) ? nothing : normpath(joinpath(dirname(source_path), target))
    JuliaIncludeSyntax(
        location[1],
        location[2] - 1,
        String(JuliaSyntax.sourcetext(node)),
        target,
        resolved_target,
        !isnothing(target),
    )
end

function literal_path_argument(node::JuliaSyntax.SyntaxNode)
    literal = string_literal_value(node)
    !isnothing(literal) && return literal
    is_call_named(node, "joinpath") || return nothing
    segments = String[]
    for argument in call_arguments(node)
        segment = string_literal_value(argument)
        isnothing(segment) && return nothing
        push!(segments, segment)
    end
    isempty(segments) ? nothing : joinpath(segments...)
end

function string_literal_value(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "string" || return nothing
    string_children = [
        child for child in syntax_children(node) if syntax_kind(child) == "String"
    ]
    length(string_children) == 1 || return nothing
    String(JuliaSyntax.sourcetext(only(string_children)))
end

function is_call_named(node::JuliaSyntax.SyntaxNode, name::AbstractString)
    syntax_kind(node) == "call" || return false
    children = syntax_children(node)
    isempty(children) && return false
    first = children[1]
    syntax_kind(first) == "Identifier" && String(JuliaSyntax.sourcetext(first)) == name
end

function call_arguments(node::JuliaSyntax.SyntaxNode)
    children = syntax_children(node)
    length(children) <= 1 ? JuliaSyntax.SyntaxNode[] : children[2:end]
end

function syntax_children(node::JuliaSyntax.SyntaxNode)
    children = JuliaSyntax.children(node)
    isnothing(children) ? JuliaSyntax.SyntaxNode[] : collect(children)
end

syntax_kind(node::JuliaSyntax.SyntaxNode) = String(Symbol(JuliaSyntax.kind(node)))
