using JuliaSyntax

struct JuliaIncludeSyntax
    line::Int
    column::Int
    expression::String
    target::Union{Nothing,String}
    resolved_target::Union{Nothing,String}
    is_literal::Bool
end

struct JuliaModuleSyntax
    line::Int
    column::Int
    name::String
    is_bare::Bool
end

struct JuliaImportSyntax
    line::Int
    column::Int
    kind::String
    root::String
    names::Vector{String}
    expression::String
end

struct JuliaExportSyntax
    line::Int
    column::Int
    kind::String
    names::Vector{String}
    expression::String
end

struct JuliaFunctionSyntax
    line::Int
    column::Int
    kind::String
    name::String
    terminal_name::String
    positional_args::Vector{String}
    keyword_args::Vector{String}
    expression::String
end

struct JuliaTypeSyntax
    line::Int
    column::Int
    kind::String
    name::String
    parameters::Vector{String}
    supertype::Union{Nothing,String}
    fields::Vector{String}
    is_mutable::Bool
    expression::String
end

struct JuliaMacroInvocationSyntax
    line::Int
    column::Int
    name::String
    terminal_name::String
    expression::String
end

struct JuliaTestSyntax
    line::Int
    column::Int
    kind::String
    name::String
    label::Union{Nothing,String}
    expression::String
end

struct JuliaSourceMetrics
    line_count::Int
    nonblank_line_count::Int
end

struct JuliaNativeSyntaxFacts
    has_syntax_tree::Bool
    modules::Vector{JuliaModuleSyntax}
    includes::Vector{JuliaIncludeSyntax}
    imports::Vector{JuliaImportSyntax}
    exports::Vector{JuliaExportSyntax}
    functions::Vector{JuliaFunctionSyntax}
    types::Vector{JuliaTypeSyntax}
    macro_invocations::Vector{JuliaMacroInvocationSyntax}
    tests::Vector{JuliaTestSyntax}
end

struct ParsedJuliaFile
    report::JuliaFileReport
    source::String
    metrics::JuliaSourceMetrics
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
    tests::Vector{JuliaTestSyntax}
end

function collect_julia_syntax_facts!(
    collector::JuliaSyntaxFactCollector,
    node::JuliaSyntax.SyntaxNode,
    source_path::AbstractString,
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
    end
    for child in syntax_children(node)
        collect_julia_syntax_facts!(collector, child, source_path)
    end
end

function is_module_node(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "module"
end

function module_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    location = JuliaSyntax.source_location(node)
    name = first_identifier_text(node)
    JuliaModuleSyntax(
        location[1],
        location[2] - 1,
        something(name, "<anonymous>"),
        JuliaSyntax.has_flags(node, JuliaSyntax.BARE_MODULE_FLAG),
    )
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

function import_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    location = JuliaSyntax.source_location(node)
    import_paths = import_path_names(node)
    isempty(import_paths) && return JuliaImportSyntax[]
    if length(import_paths) == 1
        return [
            JuliaImportSyntax(
                location[1],
                location[2] - 1,
                kind,
                only(import_paths),
                String[],
                String(JuliaSyntax.sourcetext(node)),
            ),
        ]
    end
    [
        JuliaImportSyntax(
            location[1],
            location[2] - 1,
            kind,
            first(import_paths),
            import_paths[2:end],
            String(JuliaSyntax.sourcetext(node)),
        ),
    ]
end

function export_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    location = JuliaSyntax.source_location(node)
    JuliaExportSyntax(
        location[1],
        location[2] - 1,
        syntax_kind(node),
        identifier_texts(node),
        String(JuliaSyntax.sourcetext(node)),
    )
end

function function_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    signature = first_call_child(node)
    isnothing(signature) && return nothing
    location = JuliaSyntax.source_location(node)
    name_node = first(syntax_children(signature))
    name = function_name_text(name_node)
    isnothing(name) && return nothing
    JuliaFunctionSyntax(
        location[1],
        location[2] - 1,
        syntax_kind(node),
        name,
        last(split(name, ".")),
        function_positional_args(signature),
        function_keyword_args(signature),
        String(JuliaSyntax.sourcetext(node)),
    )
end

function type_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    location = JuliaSyntax.source_location(node)
    head = type_head_node(node)
    isnothing(head) && return nothing
    name = type_name_text(head)
    isnothing(name) && return nothing
    JuliaTypeSyntax(
        location[1],
        location[2] - 1,
        syntax_kind(node),
        name,
        type_parameter_texts(head),
        type_supertype_text(head),
        type_field_names(node),
        JuliaSyntax.has_flags(node, JuliaSyntax.MUTABLE_FLAG),
        String(JuliaSyntax.sourcetext(node)),
    )
end

function macro_invocation_syntax_from_node(node::JuliaSyntax.SyntaxNode)
    children = syntax_children(node)
    isempty(children) && return nothing
    name_node = first(children)
    terminal_name = terminal_macro_name(name_node)
    isnothing(terminal_name) && return nothing
    location = JuliaSyntax.source_location(node)
    JuliaMacroInvocationSyntax(
        location[1],
        location[2] - 1,
        compact_syntax_text(name_node),
        terminal_name,
        String(JuliaSyntax.sourcetext(node)),
    )
end

function test_syntax_from_macro_invocation(
    node::JuliaSyntax.SyntaxNode,
    invocation::JuliaMacroInvocationSyntax,
)
    invocation.terminal_name in TEST_MACRO_NAMES || return nothing
    location = JuliaSyntax.source_location(node)
    JuliaTestSyntax(
        location[1],
        location[2] - 1,
        invocation.terminal_name,
        invocation.name,
        first_string_literal_argument(node),
        invocation.expression,
    )
end

const TEST_MACRO_NAMES = Set([
    "inferred",
    "test",
    "test_broken",
    "test_deprecated",
    "test_logs",
    "test_nowarn",
    "test_skip",
    "test_throws",
    "test_warn",
    "testset",
])

function terminal_macro_name(node::JuliaSyntax.SyntaxNode)
    names = identifier_texts(node)
    isempty(names) ? nothing : last(names)
end

function first_string_literal_argument(node::JuliaSyntax.SyntaxNode)
    for argument in macro_arguments(node)
        label = string_literal_value(argument)
        !isnothing(label) && return label
    end
    nothing
end

function macro_arguments(node::JuliaSyntax.SyntaxNode)
    children = syntax_children(node)
    length(children) <= 1 ? JuliaSyntax.SyntaxNode[] : children[2:end]
end

function compact_syntax_text(node::JuliaSyntax.SyntaxNode)
    replace(String(JuliaSyntax.sourcetext(node)), r"\s+" => "")
end

function type_head_node(node::JuliaSyntax.SyntaxNode)
    for child in syntax_children(node)
        syntax_kind(child) in ("block", "Integer") && continue
        return child
    end
    nothing
end

function type_name_text(node::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(node)
    if kind == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif kind == "curly"
        children = syntax_children(node)
        isempty(children) && return nothing
        return type_name_text(first(children))
    elseif kind == "<:"
        children = syntax_children(node)
        isempty(children) && return nothing
        return type_name_text(first(children))
    end
    nothing
end

function type_parameter_texts(node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "<:"
        children = syntax_children(node)
        isempty(children) && return String[]
        head = first(children)
    else
        head = node
    end
    syntax_kind(head) == "curly" || return String[]
    children = syntax_children(head)
    length(children) <= 1 && return String[]
    [compact_syntax_text(child) for child in children[2:end]]
end

function type_supertype_text(node::JuliaSyntax.SyntaxNode)
    syntax_kind(node) == "<:" || return nothing
    children = syntax_children(node)
    length(children) >= 2 || return nothing
    compact_syntax_text(children[2])
end

function type_field_names(node::JuliaSyntax.SyntaxNode)
    block = first_child_with_kind(node, "block")
    isnothing(block) && return String[]
    fields = String[]
    for child in syntax_children(block)
        name = field_name_text(child)
        !isnothing(name) && push!(fields, name)
    end
    fields
end

function field_name_text(node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif syntax_kind(node) == "::"
        children = syntax_children(node)
        isempty(children) && return nothing
        return field_name_text(first(children))
    end
    nothing
end

function first_child_with_kind(node::JuliaSyntax.SyntaxNode, kind::AbstractString)
    for child in syntax_children(node)
        syntax_kind(child) == kind && return child
    end
    nothing
end

function first_call_child(node::JuliaSyntax.SyntaxNode)
    for child in syntax_children(node)
        syntax_kind(child) == "call" && return child
    end
    nothing
end

function function_name_text(node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    elseif syntax_kind(node) == "."
        names = identifier_texts(node)
        isempty(names) && return nothing
        return join(names, ".")
    end
    nothing
end

function function_positional_args(signature::JuliaSyntax.SyntaxNode)
    args = String[]
    for argument in call_arguments(signature)
        syntax_kind(argument) == "parameters" && continue
        name = argument_name(argument)
        !isnothing(name) && push!(args, name)
    end
    args
end

function function_keyword_args(signature::JuliaSyntax.SyntaxNode)
    arguments = call_arguments(signature)
    keyword_index = findfirst(node -> syntax_kind(node) == "parameters", arguments)
    isnothing(keyword_index) && return String[]
    keyword_node = arguments[keyword_index]
    names = String[]
    for argument in syntax_children(keyword_node)
        name = argument_name(argument)
        !isnothing(name) && push!(names, name)
    end
    names
end

function argument_name(node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "Identifier"
        return String(JuliaSyntax.sourcetext(node))
    end
    identifiers = identifier_texts(node)
    isempty(identifiers) ? nothing : first(identifiers)
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

function import_path_names(node::JuliaSyntax.SyntaxNode)
    paths = String[]
    collect_import_path_names!(paths, node)
    paths
end

function collect_import_path_names!(paths::Vector{String}, node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "importpath"
        push!(paths, join(identifier_texts(node), "."))
        return
    end
    for child in syntax_children(node)
        collect_import_path_names!(paths, child)
    end
end

function first_identifier_text(node::JuliaSyntax.SyntaxNode)
    for child in syntax_children(node)
        syntax_kind(child) == "Identifier" && return String(JuliaSyntax.sourcetext(child))
    end
    nothing
end

function identifier_texts(node::JuliaSyntax.SyntaxNode)
    names = String[]
    collect_identifier_texts!(names, node)
    names
end

function collect_identifier_texts!(names::Vector{String}, node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "Identifier"
        push!(names, String(JuliaSyntax.sourcetext(node)))
        return
    end
    for child in syntax_children(node)
        collect_identifier_texts!(names, child)
    end
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
