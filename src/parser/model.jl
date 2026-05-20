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
