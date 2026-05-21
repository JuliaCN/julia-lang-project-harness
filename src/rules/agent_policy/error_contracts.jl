const PUBLIC_FAILURE_CALL_NAMES = Set([
    "error",
    "throw",
])

const PUBLIC_FAILURE_MACRO_NAMES = Set([
    "assert",
])

const PUBLIC_FAILURE_CONTRACT_DOC_TOKENS = (
    "argumenterror",
    "assert",
    "error",
    "exception",
    "fail",
    "failure",
    "invalid",
    "must",
    "precondition",
    "require",
    "requires",
    "throw",
    "throws",
)

function public_failure_contract_findings(
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    function_docs_by_name::Dict{String,Vector{String}},
    rules::Dict{String,JuliaHarnessRule},
)
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        parsed.report.is_valid || continue
        for function_fact in parsed.syntax_facts.functions
            function_fact.kind == "function" || continue
            function_fact.terminal_name in public_names || continue
            haskey(function_docs_by_name, function_fact.terminal_name) || continue
            failure_constructs = public_failure_constructs(parsed, function_fact)
            isempty(failure_constructs) && continue
            has_public_failure_contract_doc(
                function_docs_by_name,
                function_fact.terminal_name,
            ) && continue
            push!(
                findings,
                finding_from_rule(
                    rules[AGENT_JL_R026];
                    summary="Exported/public method `$(function_fact.terminal_name)` has parser-visible failure paths without a failure contract: $(join(failure_constructs, ", ")).",
                    location=SourceLocation(
                        parsed.report.path,
                        function_fact.line,
                        function_fact.column,
                    ),
                    source_line=source_line(parsed.source, function_fact.line),
                    label="document thrown errors, assertions, or invalid-input preconditions for this public method",
                ),
            )
        end
    end
    findings
end

function public_failure_test_findings(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
    public_names::Set{String},
    function_docs_by_name::Dict{String,Vector{String}},
    rules::Dict{String,JuliaHarnessRule},
)
    test_throws_calls = test_throws_call_names_by_public_name(scope, parsed_files)
    findings = JuliaHarnessFinding[]
    for parsed in parsed_files
        parsed.report.is_valid || continue
        is_test_path(scope, parsed.report.path) && continue
        for function_fact in parsed.syntax_facts.functions
            function_fact.kind == "function" || continue
            name = function_fact.terminal_name
            name in public_names || continue
            has_public_failure_contract_doc(function_docs_by_name, name) || continue
            isempty(public_failure_constructs(parsed, function_fact)) && continue
            name in test_throws_calls && continue
            push!(
                findings,
                finding_from_rule(
                    rules[AGENT_JL_R027];
                    summary="Exported/public method `$(name)` documents a failure contract but lacks a parser-visible `@test_throws` call in tests.",
                    location=SourceLocation(
                        parsed.report.path,
                        function_fact.line,
                        function_fact.column,
                    ),
                    source_line=source_line(parsed.source, function_fact.line),
                    label="add an @test_throws regression for this public failure contract",
                ),
            )
        end
    end
    findings
end

function public_failure_constructs(
    parsed::ParsedJuliaFile,
    function_fact::JuliaFunctionSyntax,
)
    constructs = String[]
    for call in parsed.syntax_facts.calls
        call.line in function_line_range(function_fact) || continue
        call.terminal_name in PUBLIC_FAILURE_CALL_NAMES || continue
        push!(constructs, call.terminal_name)
    end
    for invocation in parsed.syntax_facts.macro_invocations
        invocation.line in function_line_range(function_fact) || continue
        invocation.terminal_name in PUBLIC_FAILURE_MACRO_NAMES || continue
        push!(constructs, "@$(invocation.terminal_name)")
    end
    sort!(unique(constructs))
end

function function_line_range(function_fact::JuliaFunctionSyntax)
    function_fact.line:function_end_line(function_fact)
end

function has_public_failure_contract_doc(
    docs_by_name::Dict{String,Vector{String}},
    name::AbstractString,
)
    any(get(docs_by_name, String(name), String[])) do text
        lower_text = lowercase(text)
        any(token -> occursin(token, lower_text), PUBLIC_FAILURE_CONTRACT_DOC_TOKENS)
    end
end

function test_throws_call_names_by_public_name(
    scope::JuliaProjectHarnessScope,
    parsed_files::Vector{ParsedJuliaFile},
)
    names = Set{String}()
    for parsed in parsed_files
        parsed.report.is_valid || continue
        is_test_path(scope, parsed.report.path) || continue
        for test_fact in parsed.syntax_facts.tests
            test_fact.kind == "test_throws" || continue
            union!(names, test_throws_call_names(test_fact))
        end
    end
    names
end

function test_throws_call_names(test_fact::JuliaTestSyntax)
    try
        syntax = JuliaSyntax.parseall(JuliaSyntax.SyntaxNode, test_fact.expression)
        names = Set{String}()
        collect_test_throws_call_names!(names, syntax)
        names
    catch
        Set{String}()
    end
end

function collect_test_throws_call_names!(names::Set{String}, node::JuliaSyntax.SyntaxNode)
    if syntax_kind(node) == "call"
        name = call_expression_name(node)
        !isnothing(name) && push!(names, terminal_public_name(name))
    end
    for child in syntax_children(node)
        collect_test_throws_call_names!(names, child)
    end
    names
end
