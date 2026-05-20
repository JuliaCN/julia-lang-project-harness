using JuliaSyntax

struct JuliaNativeSyntaxFacts
    has_syntax_tree::Bool
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
            JuliaNativeSyntaxFacts(false),
        )
    end

    try
        JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, source; filename=path_string)
        ParsedJuliaFile(
            JuliaFileReport(path_string, true, nothing),
            source,
            JuliaNativeSyntaxFacts(true),
        )
    catch err
        ParsedJuliaFile(
            JuliaFileReport(path_string, false, sprint(showerror, err)),
            source,
            JuliaNativeSyntaxFacts(false),
        )
    end
end

function source_line(source::AbstractString, line::Int)
    lines = split(source, '\n'; keepempty=true)
    1 <= line <= length(lines) ? lines[line] : nothing
end
