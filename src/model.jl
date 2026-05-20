@enum JuliaDiagnosticSeverity::UInt8 Info Warning Error

severity_label(::Val{Info}) = "info"
severity_label(::Val{Warning}) = "warning"
severity_label(::Val{Error}) = "error"
severity_label(severity::JuliaDiagnosticSeverity) = severity_label(Val(severity))

struct SourceLocation
    path::Union{Nothing,String}
    line::Int
    column::Int
end

struct RulePackDescriptor
    id::String
    version::String
    domains::Vector{String}
    default_mode::String
end

struct JuliaHarnessRule
    rule_id::String
    pack_id::String
    severity::JuliaDiagnosticSeverity
    title::String
    requirement::String
    labels::Dict{String,String}
end

struct JuliaHarnessFinding
    rule_id::String
    pack_id::String
    severity::JuliaDiagnosticSeverity
    title::String
    summary::String
    location::SourceLocation
    requirement::String
    source_line::Union{Nothing,String}
    label::String
    labels::Dict{String,String}
end

struct JuliaFileReport
    path::String
    is_valid::Bool
    parse_error::Union{Nothing,String}
end

struct JuliaProjectHarnessScope
    project_root::String
    project_toml_path::Union{Nothing,String}
    package_name::Union{Nothing,String}
    package_uuid::Union{Nothing,String}
    package_entry_path::Union{Nothing,String}
    direct_dependencies::Dict{String,String}
    weak_dependencies::Dict{String,String}
    extra_dependencies::Dict{String,String}
    targets::Dict{String,Vector{String}}
    compat::Dict{String,String}
    sources::Dict{String,Dict{String,String}}
    source_paths::Vector{String}
    test_paths::Vector{String}
    package_paths::Vector{String}
    fallback_paths::Vector{String}
end

struct JuliaHarnessConfig
    ignored_dir_names::Set{String}
    blocking_severities::Set{JuliaDiagnosticSeverity}
    disabled_rules::Set{String}
    rule_severity_overrides::Dict{String,JuliaDiagnosticSeverity}
    include_tests::Bool
    source_dir_names::Vector{String}
    test_dir_names::Vector{String}
    source_path_explanations::Dict{String,String}
    test_path_explanations::Dict{String,String}
    source_path_exclusion_explanations::Dict{String,String}
    test_path_exclusion_explanations::Dict{String,String}
    agent_advice_allow_explanation::Union{Nothing,String}
end

struct JuliaHarnessReport
    files::Vector{JuliaFileReport}
    findings::Vector{JuliaHarnessFinding}
    root_paths::Vector{String}
    blocking_severities::Set{JuliaDiagnosticSeverity}
    project_scope::Union{Nothing,JuliaProjectHarnessScope}
    workspace_member_scopes::Vector{JuliaProjectHarnessScope}
end

const DEFAULT_IGNORED_DIR_NAMES = Set([
    ".cache",
    ".direnv",
    ".git",
    ".idea",
    ".jj",
    ".run",
    ".vscode",
    "artifacts",
    "deps",
    "node_modules",
    "scratchspaces",
])

function default_julia_harness_config()
    JuliaHarnessConfig(
        copy(DEFAULT_IGNORED_DIR_NAMES),
        Set([Warning, Error]),
        Set{String}(),
        Dict{String,JuliaDiagnosticSeverity}(),
        true,
        ["src"],
        ["test"],
        Dict{String,String}(),
        Dict{String,String}(),
        Dict{String,String}(),
        Dict{String,String}(),
        nothing,
    )
end

file_count(report::JuliaHarnessReport) = length(report.files)
parsed_count(report::JuliaHarnessReport) = count(file -> file.is_valid, report.files)

function blocking_findings(report::JuliaHarnessReport; severities=nothing)
    selected = isnothing(severities) ? report.blocking_severities : severities
    [finding for finding in report.findings if finding.severity in selected]
end

advisory_findings(report::JuliaHarnessReport) =
    [finding for finding in report.findings if finding.severity == Info]

is_clean(report::JuliaHarnessReport) = isempty(blocking_findings(report))

function assert_clean(report::JuliaHarnessReport)
    if !is_clean(report)
        error(render_julia_project_harness(report))
    end
    report
end

function assert_no_advisory_findings(report::JuliaHarnessReport)
    if !isempty(advisory_findings(report))
        error(render_julia_project_harness(report))
    end
    report
end
