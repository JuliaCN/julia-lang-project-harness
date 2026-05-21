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
    argument = first_call_argument_source(call.expression)
    isnothing(argument) && return nothing
    literal_input_type_category(argument)
end

function first_call_argument_source(expression::AbstractString)
    source = String(expression)
    open_index = findfirst(==('('), source)
    isnothing(open_index) && return nothing
    depth = 0
    in_string = false
    escaped = false
    argument = IOBuffer()
    index = nextind(source, open_index)
    while index <= lastindex(source)
        char = source[index]
        if in_string
            print(argument, char)
            if escaped
                escaped = false
            elseif char == '\\'
                escaped = true
            elseif char == '"'
                in_string = false
            end
            index = nextind(source, index)
            continue
        end
        if char == '"'
            in_string = true
            print(argument, char)
        elseif char in ('(', '[', '{')
            depth += 1
            print(argument, char)
        elseif char in (')', ']', '}')
            if depth == 0
                return strip(String(take!(argument)))
            end
            depth -= 1
            print(argument, char)
        elseif char == ',' && depth == 0
            return strip(String(take!(argument)))
        else
            print(argument, char)
        end
        index = nextind(source, index)
    end
    argument_source = strip(String(take!(argument)))
    isempty(argument_source) ? nothing : argument_source
end

function literal_input_type_category(argument::AbstractString)
    value = strip(String(argument))
    isempty(value) && return nothing
    startswith(value, "raw\"") && return "String"
    startswith(value, "\"") && return "String"
    startswith(value, "'") && return "Char"
    startswith(value, ":") && return "Symbol"
    startswith(value, "[") && return "Vector"
    startswith(value, "(") && return "Tuple"
    startswith(value, "Dict(") && return "Dict"
    startswith(value, "Set(") && return "Set"
    value in ("true", "false") && return "Bool"
    typed_constructor = literal_type_constructor_category(value)
    !isnothing(typed_constructor) && return typed_constructor
    occursin(r"^[+-]?\d+\.\d*([eEfF][+-]?\d+)?$", value) && return "Float64"
    occursin(r"^[+-]?\d+[eEfF][+-]?\d+$", value) && return "Float64"
    occursin(r"^[+-]?\d+$", value) && return "Int"
    nothing
end

function literal_type_constructor_category(value::AbstractString)
    for name in ("BigFloat", "BigInt", "Float16", "Float32", "Float64", "Int128",
                 "Int16", "Int32", "Int64", "Int8", "UInt128", "UInt16", "UInt32",
                 "UInt64", "UInt8")
        startswith(value, "$(name)(") && return name
    end
    nothing
end

function public_generic_type_coverage_summary(
    function_fact::JuliaFunctionSyntax,
    input_types::Set{String},
)
    where_clause = join(function_fact.where_parameters, ", ")
    observed = isempty(input_types) ? "no parser-visible literal input types" :
               "only parser-visible input types: $(join(sort!(collect(input_types)), ", "))"
    "Exported/public generic method `$(function_fact.terminal_name)` declares `where {$(where_clause)}` but tests exercise $(observed)."
end
