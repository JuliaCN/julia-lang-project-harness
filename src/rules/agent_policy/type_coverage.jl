const MIN_PUBLIC_GENERIC_TEST_INPUT_TYPES = 2

function public_generic_type_coverage_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    input_types_by_name = test_literal_input_types_by_call_name(scope, parsed_files)
    reported = Set{String}()
    for parsed in parsed_files
        parsed.report.is_valid || continue
        is_test_path(scope, parsed.report.path) && continue
        for function_fact in parsed.syntax_facts.functions
            is_public_generic_method(function_fact, public_names) || continue
            name = function_fact.terminal_name
            name in reported && continue
            input_types = get(input_types_by_name, name, Set{String}())
            length(input_types) >= MIN_PUBLIC_GENERIC_TEST_INPUT_TYPES && continue
            push!(reported, name)
            push!(
                findings,
                finding_from_rule(
                    rules[AGENT_JL_R018];
                    summary=public_generic_type_coverage_summary(function_fact, input_types),
                    location=SourceLocation(
                        parsed.report.path,
                        function_fact.line,
                        function_fact.column,
                    ),
                    source_line=source_line(parsed.source, function_fact.line),
                    label="add tests that call this generic public API with at least two relevant input types",
                ),
            )
        end
    end
    findings
end

function is_public_generic_method(
    function_fact::JuliaFunctionSyntax,
    public_names::Set{String},
)
    function_fact.terminal_name in public_names || return false
    !isempty(function_fact.where_parameters)
end

function test_literal_input_types_by_call_name(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
)
    input_types_by_name = Dict{String,Set{String}}()
    for parsed in parsed_files
        parsed.report.is_valid || continue
        is_test_path(scope, parsed.report.path) || continue
        for call in parsed.syntax_facts.calls
            input_type = literal_input_type_for_call(call)
            isnothing(input_type) && continue
            push!(get!(input_types_by_name, call.terminal_name, Set{String}()), input_type)
        end
    end
    input_types_by_name
end

function literal_input_type_for_call(call::JuliaCallSyntax)
    argument = first_call_argument_node(call.expression)
    isnothing(argument) && return nothing
    literal_input_type_category(argument)
end

function first_call_argument_node(expression::AbstractString)
    try
        syntax = JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, String(expression))
        call_node = first_syntax_node_kind(syntax, "call")
        isnothing(call_node) && return nothing
        arguments = call_arguments(call_node)
        isempty(arguments) && return nothing
        first(arguments)
    catch
        nothing
    end
end

function first_syntax_node_kind(node::JuliaSyntax.SyntaxNode, kind::AbstractString)
    syntax_kind(node) == kind && return node
    for child in syntax_children(node)
        found = first_syntax_node_kind(child, kind)
        !isnothing(found) && return found
    end
    nothing
end

function literal_input_type_category(argument::JuliaSyntax.SyntaxNode)
    kind = syntax_kind(argument)
    kind == "Integer" && return "Int"
    kind == "Float" && return "Float64"
    kind == "Bool" && return "Bool"
    kind == "string" && return "String"
    kind == "char" && return "Char"
    kind == "quote" && return "Symbol"
    kind == "vect" && return "Vector"
    kind == "tuple" && return "Tuple"
    if kind == "call"
        name = call_expression_name(argument)
        isnothing(name) && return nothing
        terminal = terminal_public_name(name)
        terminal in TYPE_COVERAGE_LITERAL_CONSTRUCTORS && return terminal
    end
    nothing
end

const TYPE_COVERAGE_LITERAL_CONSTRUCTORS = Set([
    "BigFloat",
    "BigInt",
    "Dict",
    "Float16",
    "Float32",
    "Float64",
    "Int128",
    "Int16",
    "Int32",
    "Int64",
    "Int8",
    "Set",
    "UInt128",
    "UInt16",
    "UInt32",
    "UInt64",
    "UInt8",
])

function public_generic_type_coverage_summary(
    function_fact::JuliaFunctionSyntax,
    input_types::Set{String},
)
    where_clause = join(function_fact.where_parameters, ", ")
    observed = isempty(input_types) ? "no parser-visible literal input types" :
               "only parser-visible input types: $(join(sort!(collect(input_types)), ", "))"
    "Exported/public generic method `$(function_fact.terminal_name)` declares `where {$(where_clause)}` but tests exercise $(observed)."
end
