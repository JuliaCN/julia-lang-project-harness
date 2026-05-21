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

struct JuliaFunctionArgumentSyntax
    line::Int
    column::Int
    owner_name::String
    name::String
    type_annotation::Union{Nothing,String}
    is_keyword::Bool
    has_default::Bool
    is_bool::Bool
    is_stringly_domain::Bool
    expression::String
end

struct JuliaFunctionSyntax
    line::Int
    column::Int
    kind::String
    name::String
    terminal_name::String
    positional_args::Vector{String}
    typed_positional_args::Vector{String}
    bool_positional_args::Vector{String}
    stringly_domain_args::Vector{String}
    stringly_branch_literals::Vector{String}
    keyword_args::Vector{String}
    argument_facts::Vector{JuliaFunctionArgumentSyntax}
    return_type::Union{Nothing,String}
    where_parameters::Vector{String}
    control_flow_depth::Int
    branch_count::Int
    loop_count::Int
    loop_nesting_depth::Int
    control_flow_kinds::Vector{String}
    body_statement_count::Int
    body_named_calls::Vector{String}
    macro_invocation_count::Int
    macro_invocation_names::Vector{String}
    expression::String
end

struct JuliaTypeFieldSyntax
    line::Int
    column::Int
    owner_name::String
    name::String
    type_annotation::Union{Nothing,String}
    has_default::Bool
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
    typed_fields::Vector{String}
    defaulted_fields::Vector{String}
    field_facts::Vector{JuliaTypeFieldSyntax}
    is_mutable::Bool
    expression::String
end

struct JuliaBindingSyntax
    line::Int
    column::Int
    kind::String
    name::String
    terminal_name::String
    type_annotation::Union{Nothing,String}
    is_constant::Bool
    expression::String
end

struct JuliaMacroInvocationSyntax
    line::Int
    column::Int
    name::String
    terminal_name::String
    expression::String
end

struct JuliaMoshiSyntax
    line::Int
    column::Int
    kind::String
    macro_name::String
    target_name::Union{Nothing,String}
    variant_names::Vector{String}
    case_names::Vector{String}
    case_patterns::Vector{String}
    expression::String
end

struct JuliaCallSyntax
    line::Int
    column::Int
    name::String
    terminal_name::String
    argument_count::Int
    keyword_args::Vector{String}
    expression::String
end

struct JuliaDocstringSyntax
    line::Int
    column::Int
    target_kind::String
    target_name::String
    text::String
    expression::String
end

struct JuliaIdentifierSyntax
    line::Int
    column::Int
    name::String
    parent_kind::String
    parent_expression::String
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
    bindings::Vector{JuliaBindingSyntax}
    macro_invocations::Vector{JuliaMacroInvocationSyntax}
    moshi::Vector{JuliaMoshiSyntax}
    calls::Vector{JuliaCallSyntax}
    docstrings::Vector{JuliaDocstringSyntax}
    identifiers::Vector{JuliaIdentifierSyntax}
    tests::Vector{JuliaTestSyntax}
end

struct ParsedJuliaFile
    report::JuliaFileReport
    source::String
    metrics::JuliaSourceMetrics
    syntax_facts::JuliaNativeSyntaxFacts
end
