using JSON3

render_julia_project_harness(report::JuliaHarnessReport) =
    render_julia_project_harness_with_options(report; severities=nothing, include_advice=true)

function render_julia_project_harness_advice(report::JuliaHarnessReport)
    render_finding_list(advisory_findings(report))
end

function render_julia_project_harness_with_options(
    report::JuliaHarnessReport;
    severities=nothing,
    include_advice::Bool=true,
)
    blocking = blocking_findings(report; severities)
    advice = include_advice ? deduplicate_advice(advisory_findings(report), blocking) :
             JuliaHarnessFinding[]
    findings = vcat(blocking, advice)
    isempty(findings) && return "[ok] julia\n"
    render_finding_list(findings)
end

function render_finding_list(findings::Vector{JuliaHarnessFinding})
    isempty(findings) && return ""
    join(map(render_finding, findings), "\n")
end

function render_finding(finding::JuliaHarnessFinding)
    path = isnothing(finding.location.path) ? "<memory>" : slash_path(finding.location.path)
    display_column = finding.location.column + 1
    rendered = "[$(finding.rule_id)] $(titlecase(severity_label(finding.severity))): $(finding.title)\n"
    rendered *= "@ $(path):$(finding.location.line):$(display_column)\n"
    rendered *= "fix: $(finding.label)\n"
    if !isnothing(finding.source_line)
        rendered *= "line: $(finding.location.line) | $(finding.source_line)\n"
    end
    rendered *= "Help: $(finding.summary)\n"
    rendered *= "Contract: $(finding.requirement)\n"
    rendered
end

function deduplicate_advice(advice::Vector{JuliaHarnessFinding}, blocking::Vector{JuliaHarnessFinding})
    blocking_keys = Set(finding_key.(blocking))
    [finding for finding in advice if !(finding_key(finding) in blocking_keys)]
end

function finding_key(finding::JuliaHarnessFinding)
    (finding.rule_id, finding.location.path, finding.location.line, finding.location.column)
end

slash_path(path::AbstractString) = replace(String(path), '\\' => '/')

function render_julia_project_harness_json(report::JuliaHarnessReport)
    JSON3.write(report_dict(report))
end

function report_dict(report::JuliaHarnessReport)
    Dict(
        "files" => map(file_report_dict, report.files),
        "findings" => map(finding_dict, report.findings),
        "root_paths" => slash_path.(report.root_paths),
        "blocking_severities" => sort(severity_label.(collect(report.blocking_severities))),
        "project_scope" => isnothing(report.project_scope) ? nothing :
                           project_scope_dict(report.project_scope),
        "workspace_member_scopes" => map(project_scope_dict, report.workspace_member_scopes),
    )
end

function file_report_dict(file::JuliaFileReport)
    Dict(
        "path" => slash_path(file.path),
        "is_valid" => file.is_valid,
        "parse_error" => file.parse_error,
    )
end

function finding_dict(finding::JuliaHarnessFinding)
    Dict(
        "rule_id" => finding.rule_id,
        "pack_id" => finding.pack_id,
        "severity" => severity_label(finding.severity),
        "title" => finding.title,
        "summary" => finding.summary,
        "location" => location_dict(finding.location),
        "requirement" => finding.requirement,
        "source_line" => finding.source_line,
        "label" => finding.label,
        "labels" => finding.labels,
    )
end

function location_dict(location::SourceLocation)
    Dict(
        "path" => isnothing(location.path) ? nothing : slash_path(location.path),
        "line" => location.line,
        "column" => location.column,
    )
end

function project_scope_dict(scope::JuliaProjectHarnessScope)
    Dict(
        "project_root" => slash_path(scope.project_root),
        "source_paths" => slash_path.(scope.source_paths),
        "test_paths" => slash_path.(scope.test_paths),
        "package_paths" => slash_path.(scope.package_paths),
        "fallback_paths" => slash_path.(scope.fallback_paths),
    )
end
