function parse_julia_file(path::AbstractString)
    path_string = String(path)
    source = try
        read(path_string, String)
    catch err
        return ParsedJuliaFile(
            JuliaFileReport(path_string, false, "failed to read Julia source: $(err)"),
            "",
            JuliaSourceMetrics(0, 0),
            empty_julia_native_syntax_facts(),
        )
    end

    metrics = source_metrics(source)
    try
        syntax = JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, source; filename=path_string)
        ParsedJuliaFile(
            JuliaFileReport(path_string, true, nothing),
            source,
            metrics,
            julia_native_syntax_facts(syntax, path_string),
        )
    catch err
        ParsedJuliaFile(
            JuliaFileReport(path_string, false, sprint(showerror, err)),
            source,
            metrics,
            empty_julia_native_syntax_facts(),
        )
    end
end

function source_line(source::AbstractString, line::Int)
    lines = split(source, '\n'; keepempty=true)
    1 <= line <= length(lines) ? lines[line] : nothing
end

function source_metrics(source::AbstractString)
    lines = split(source, '\n'; keepempty=true)
    JuliaSourceMetrics(length(lines), count(line -> !isempty(strip(line)), lines))
end

function empty_julia_native_syntax_facts()
    JuliaNativeSyntaxFacts(
        false,
        JuliaModuleSyntax[],
        JuliaIncludeSyntax[],
        JuliaImportSyntax[],
        JuliaExportSyntax[],
        JuliaFunctionSyntax[],
        JuliaTypeSyntax[],
        JuliaMacroInvocationSyntax[],
        JuliaCallSyntax[],
        JuliaTestSyntax[],
    )
end

function julia_native_syntax_facts(syntax::JuliaSyntax.SyntaxNode, source_path::AbstractString)
    collector = JuliaSyntaxFactCollector(
        JuliaModuleSyntax[],
        JuliaIncludeSyntax[],
        JuliaImportSyntax[],
        JuliaExportSyntax[],
        JuliaFunctionSyntax[],
        JuliaTypeSyntax[],
        JuliaMacroInvocationSyntax[],
        JuliaCallSyntax[],
        JuliaTestSyntax[],
    )
    collect_julia_syntax_facts!(collector, syntax, source_path)
    JuliaNativeSyntaxFacts(
        true,
        collector.modules,
        collector.includes,
        collector.imports,
        collector.exports,
        collector.functions,
        collector.types,
        collector.macro_invocations,
        collector.calls,
        collector.tests,
    )
end

mutable struct JuliaSyntaxFactCollector
    modules::Vector{JuliaModuleSyntax}
    includes::Vector{JuliaIncludeSyntax}
    imports::Vector{JuliaImportSyntax}
    exports::Vector{JuliaExportSyntax}
    functions::Vector{JuliaFunctionSyntax}
    types::Vector{JuliaTypeSyntax}
    macro_invocations::Vector{JuliaMacroInvocationSyntax}
    calls::Vector{JuliaCallSyntax}
    tests::Vector{JuliaTestSyntax}
end

function collect_julia_syntax_facts!(
    collector::JuliaSyntaxFactCollector,
    node::JuliaSyntax.SyntaxNode,
    source_path::AbstractString,
    parent::Union{Nothing,JuliaSyntax.SyntaxNode}=nothing,
)
    if is_module_node(node)
        push!(collector.modules, module_syntax_from_node(node))
    elseif is_call_named(node, "include")
        push!(collector.includes, include_syntax_from_call(node, source_path))
    elseif syntax_kind(node) in ("using", "import")
        append!(collector.imports, import_syntax_from_node(node))
    elseif syntax_kind(node) in ("export", "public")
        push!(collector.exports, export_syntax_from_node(node))
    elseif syntax_kind(node) in ("function", "macro")
        function_fact = function_syntax_from_node(node)
        !isnothing(function_fact) && push!(collector.functions, function_fact)
    elseif syntax_kind(node) in ("struct", "abstract", "primitive")
        type_fact = type_syntax_from_node(node)
        !isnothing(type_fact) && push!(collector.types, type_fact)
    elseif syntax_kind(node) == "macrocall"
        macro_invocation = macro_invocation_syntax_from_node(node)
        if !isnothing(macro_invocation)
            push!(collector.macro_invocations, macro_invocation)
            test_fact = test_syntax_from_macro_invocation(node, macro_invocation)
            !isnothing(test_fact) && push!(collector.tests, test_fact)
        end
    elseif syntax_kind(node) == "call"
        call_fact = call_syntax_from_node(node, parent)
        !isnothing(call_fact) && push!(collector.calls, call_fact)
    end
    for child in syntax_children(node)
        collect_julia_syntax_facts!(collector, child, source_path, node)
    end
end
